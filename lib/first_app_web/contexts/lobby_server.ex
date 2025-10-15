defmodule FirstAppWeb.LobbyServer do
  use GenServer
  alias Phoenix.PubSub
  alias FirstAppWeb.RPS
  require Logger
  # -----------------------------
  #  PUBLIC API
  # -----------------------------

  def start_link(%{id: id} = lobby) do
    GenServer.start_link(__MODULE__, lobby, name: via_tuple(id))
  end

  def via_tuple(id), do: {:via, Registry, {FirstAppWeb.LobbyRegistry, id}}

  def add_player(id, login), do: GenServer.cast(via_tuple(id), {:add_player, login})
  def remove_player(id, login), do: GenServer.cast(via_tuple(id), {:remove_player, login})
  def get_host(id), do: GenServer.call(via_tuple(id), :get_host)
  def add_score(id, login), do: GenServer.cast(via_tuple(id), {:add_score, login})
  def state(id), do: GenServer.call(via_tuple(id), :state)
  def arrange_pair(id, winner_login), do: GenServer.cast(via_tuple(id), {:arrange_pair, winner_login})
  def broadcast_state(id), do: GenServer.cast(via_tuple(id), :broadcast_state)
  def player_selected(id, login, choice),
    do: GenServer.cast(via_tuple(id), {:player_selected, login, choice})

  # -----------------------------
  #  CALLBACKS
  # -----------------------------

  def init(lobby) do
    Logger.info("✅ Started LobbyServer for #{lobby.name} (#{lobby.id})")

    lobby =
      lobby
      |> Map.put_new(:scores, %{})
      |> Map.put_new(:order, if(lobby.host, do: [lobby.host], else: []))
      |> Map.put_new(:leftPlayer, nil)
      |> Map.put_new(:rightPlayer, nil)

    {:ok, lobby}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}
  def handle_call(:get_host, _from, state), do: {:reply, state.host, state}

  # -----------------------------
  #  HANDLE_CASTS
  # -----------------------------

  # ✅ Add player
  def handle_cast({:add_player, login}, state) do
    new_state =
      state
      |> Map.update!(:scores, &Map.put(&1, login, %{score: 0}))
      |> Map.update(:order, [login], fn order ->
        if login in order, do: order, else: order ++ [login]
      end)

    Logger.info("added player #{login}")
    Logger.debug(inspect(new_state, pretty: true))

    broadcast_state_full(new_state)
    {:noreply, new_state}
  end

  # ✅ Remove player
  def handle_cast({:remove_player, login}, state) do
    new_state =
      state
      |> Map.update!(:scores, &Map.delete(&1, login))
      |> Map.update(:order, [], fn order ->
        Enum.reject(order, &(&1 == login))
      end)
      |> clear_left_right_player(login)

    Logger.info("removed player #{login}")
    Logger.debug(inspect(new_state, pretty: true))

    broadcast_state_full(new_state)
    {:noreply, new_state}
  end

  # ✅ Increment score
  def handle_cast({:increment_score, login}, state) do
    new_state =
      update_in(state.scores[login].score, fn
        nil -> 1
        score -> score + 1
      end)

    broadcast_state_full(new_state)
    {:noreply, new_state}
  end

  def handle_cast({:player_selected, login, choice}, state) do
    updated_state =
      cond do
        state.leftPlayer && state.leftPlayer.login == login ->
          put_in(state, [:leftPlayer, :selected], choice)

        state.rightPlayer && state.rightPlayer.login == login ->
          put_in(state, [:rightPlayer, :selected], choice)

        true ->
          state
      end

    broadcast_state_full(updated_state)
    {:noreply, updated_state}
  end

  # ✅ Arrange pair
  def handle_cast({:arrange_pair, winner_login}, state) do
    cond do
      # Case 1: exactly two players, already paired
      length(state.order) == 2 and not is_nil(state.leftPlayer) and not is_nil(state.rightPlayer) ->
        Logger.debug("case 1: both slots filled")
        {:noreply, state}

      # Case 2: both slots empty, can fill initial pair
      is_nil(state.leftPlayer) and is_nil(state.rightPlayer) and length(state.order) >= 2 ->
        [first, second | _rest] = state.order

        new_state = %{
          state
          | leftPlayer: %{login: first, selected: ""},
            rightPlayer: %{login: second, selected: ""}
        }

        Logger.info("initial pair arranged")
        Logger.debug(inspect(new_state, pretty: true))

        broadcast_state_full(new_state)
        {:noreply, new_state}

      # Case 3: normal flow — one slot must be replaced after winner
      true ->
        Logger.debug("case 3: replace after winner")

        new_state =
          state
          |> maybe_replace_left(winner_login)
          |> maybe_replace_right(winner_login)

        Logger.info("pair rearranged after winner")
        Logger.debug(inspect(new_state, pretty: true))

        broadcast_state_full(new_state)
        {:noreply, new_state}
    end
  end

  # ✅ Manual full-state broadcast
  def handle_cast(:broadcast_state, state) do
    broadcast_state_full(state)
    {:noreply, state}
  end

  # -----------------------------
  #  HELPERS
  # -----------------------------

  def terminate(reason, state) do
    Logger.warning("💀 Lobby #{state.name} (#{state.id}) terminated: #{inspect(reason)}")
    :ok
  end

  defp broadcast_state_full(state) do
    PubSub.broadcast(FirstApp.PubSub, "lobby:#{state.id}", {:game_state_updated, state})
  end

  defp clear_left_right_player(state, login) do
    left_login = get_in(state.leftPlayer, [:login])
    right_login = get_in(state.rightPlayer, [:login])

    cond do
      left_login == login and right_login == login ->
        %{state | leftPlayer: nil, rightPlayer: nil}

      left_login == login ->
        %{state | leftPlayer: nil}

      right_login == login ->
        %{state | rightPlayer: nil}

      true ->
        state
    end
  end

  defp maybe_replace_left(%{leftPlayer: left, order: order} = state, winner) do
    left_login = get_in(left, [:login])
    right_login = get_in(state.rightPlayer, [:login])

    if is_nil(left_login) or left_login != winner do
      new_login = next_player(order, [left_login, right_login])
      if new_login do
        %{state | leftPlayer: %{login: new_login, selected: ""}}
      else
        state
      end
    else
      state
    end
  end

  defp maybe_replace_right(%{rightPlayer: right, order: order} = state, winner) do
    left_login = get_in(state.leftPlayer, [:login])
    right_login = get_in(right, [:login])

    if is_nil(right_login) or right_login != winner do
      new_login = next_player(order, [left_login, right_login])
      if new_login do
        %{state | rightPlayer: %{login: new_login, selected: ""}}
      else
        state
      end
    else
      state
    end
  end

  defp next_player(order, current_players) do
    Enum.find(order, fn p -> p not in current_players and not is_nil(p) end)
  end
end
