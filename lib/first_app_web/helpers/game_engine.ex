defmodule FirstAppWeb.GameEngine do
  use GenServer
  alias Phoenix.PubSub
  alias FirstAppWeb.RPS
  alias FirstAppWeb.LinkedList
  alias FirstAppWeb.LobbyServer
  require Logger

  def start_link(opts) do
    lobby_id = Keyword.fetch!(opts, :lobby_id)
    GenServer.start_link(__MODULE__, %{lobby_id: lobby_id}, name: via_tuple(lobby_id))
  end

  defp via_tuple(lobby_id),
    do: {:via, Registry, {FirstAppWeb.GameEngineRegistry, lobby_id}}

  # Usual dispatch
  def dispatch(lobby_id, type, data),
    do: GenServer.cast(via_tuple(lobby_id), {:dispatch, type, data})

  # Callbacks
  def init(%{lobby_id: id}) do
    topic = "game:#{id}"

    {:ok,
     %{
       lobby_id: id,
       topic: topic,
       events: nil,
       game: %{
        leftPlayer: nil,
        rightPlayer: nil,
        winner: nil
      }
     }}
  end

  def handle_cast({:dispatch, type, data}, state) do
    new_events = LinkedList.prepend(state.events, type, data)
    new_state  = %{state | events: new_events}
    updated    = process_event(type, data, new_state)

    PubSub.broadcast(FirstApp.PubSub, updated.topic, {:game_updated, updated.game})

    {:noreply, updated}
  end

  # player leave
  defp process_event(:player_leave, %{login: login}, state) do
    new_game =
      state.game
      |> Map.update(:leftPlayer, nil, fn
        %{login: ^login} -> nil
        player -> player
      end)
      |> Map.update(:rightPlayer, nil, fn
        %{login: ^login} -> nil
        player -> player
      end)

    %{state | game: new_game}
  end

  # suggest start game
  defp process_event(:suggest_start_game, _params, state) do
    players_online = FirstAppWeb.LobbyServer.get_players_online(state.lobby_id)

    if length(players_online) < 2 do
      Logger.debug("Not enough players to start game (#{length(players_online)}) — ignoring")
      state
    end
    Logger.info("Enough players to start game (#{length(players_online)})")
    dispatch(state.lobby_id, :arrange_pair, %{players_online: players_online})
    state
  end

  defp process_event(:arrange_pair, %{players_online: players_online}, state) do
    cond do
      # Case 1: exactly two players, already paired
      length(players_online) == 2 and not is_nil(state.game.leftPlayer) and not is_nil(state.game.rightPlayer) ->
        Logger.debug("case 1: both slots filled")

        state

      # Case 2: both slots empty, can fill initial pair
      is_nil(state.game.leftPlayer) and is_nil(state.game.rightPlayer) and length(players_online) >= 2 ->
        [first, second | _rest] = players_online

        new_game = %{
          state.game
          | leftPlayer: %{login: first, selected: "Rock", ready: false},
            rightPlayer: %{login: second, selected: "Rock", ready: false}
        }

        Logger.info("initial pair arranged")
        Logger.debug(inspect(new_game, pretty: true))

        new_state = %{state | game: new_game}
        Logger.debug(inspect(new_state, pretty: true))

        new_state

      # Case 3: normal flow — one slot must be replaced after winner
      true ->
        Logger.debug("case 3: replace after winner")

        # Update only the nested :game structure
        new_game =
          state.game
          |> maybe_replace_left(players_online, :left)
          |> maybe_replace_right(players_online, :right)

        new_state = %{state | game: new_game}

        Logger.info("pair rearranged after winner")
        Logger.debug(inspect(new_state, pretty: true))

        new_state
    end
  end

  defp maybe_replace_left(game, players_online, :left) do
    left_login  = get_in(game, [:leftPlayer, :login])
    right_login = get_in(game, [:rightPlayer, :login])

    if is_nil(left_login) or left_login != game.winner do
      new_login = next_player(players_online, [left_login, right_login])

      if new_login do
        %{game | leftPlayer: %{login: new_login, selected: "Rock", ready: false}}
      else
        game
      end
    else
      game
    end
  end

  defp maybe_replace_right(game, players_online, :right) do
    left_login  = get_in(game, [:leftPlayer, :login])
    right_login = get_in(game, [:rightPlayer, :login])

    if is_nil(right_login) or right_login != game.winner do
      new_login = next_player(players_online, [left_login, right_login])

      if new_login do
        %{game | rightPlayer: %{login: new_login, selected: "Rock", ready: false}}
      else
        game
      end
    else
      game
    end
  end

  defp next_player(players_online, current_players) do
    Enum.find(players_online, fn p -> p not in current_players and not is_nil(p) end)
  end
end
