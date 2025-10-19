defmodule FirstAppWeb.LobbyServer do
  use GenServer
  alias Phoenix.PubSub
  alias FirstAppWeb.LinkedList
  alias FirstAppWeb.GameEngine
  require Logger

  # -----------------------------
  #  PUBLIC API
  # -----------------------------

  def start_link(%{id: id} = lobby) do
    GenServer.start_link(__MODULE__, lobby, name: via_tuple(id))
  end

  def via_tuple(id), do: {:via, Registry, {FirstAppWeb.LobbyRegistry, id}}

  def state(id), do: GenServer.call(via_tuple(id), :state)

  def get_players_online(id) do
    GenServer.call(via_tuple(id), :get_players_online)
  end

  def player_enter(id, login), do: GenServer.cast(via_tuple(id), {:player_enter, login})
  def player_leave(id, login), do: GenServer.cast(via_tuple(id), {:player_leave, login})

  defp broadcast_state_full(state) do
    Logger.debug(inspect(state, pretty: true))
    PubSub.broadcast(FirstApp.PubSub, "lobby:#{state.id}", {:lobby_state_updated, state})
  end

  def add_score(lobby_id, login) do
    GenServer.cast(via_tuple(lobby_id), {:add_score, login})
  end

  # -----------------------------
  #  CALLBACKS
  # -----------------------------

  def init(lobby) do
    Logger.info("✅ Started LobbyServer for #{lobby.name} (#{lobby.id})")
    PubSub.subscribe(FirstApp.PubSub, "game_over:#{lobby.id}")

    state = %{
      host: lobby.host,
      name: lobby.name,
      id: lobby.id,
      scores: [],
      playersOnline: []
    }

    {:ok, state}
  end

  # get state
  def handle_call(:state, _from, state), do: {:reply, state, state}

  # get host login
  def handle_call(:get_host, _from, state), do: {:reply, state.host, state}

  # get players online
  def handle_call(:get_players_online, _from, state) do
    {:reply, state.playersOnline, state}
  end

  # player enters lobby
  def handle_cast({:player_enter, login}, state) do
    # Update scores list (add only if player not already there)
    updated_scores =
      if Enum.any?(state.scores, fn %{login: l} -> l == login end) do
        state.scores
      else
        [%{login: login, score: 0} | state.scores]
      end

    # Update playersOnline list (add only if not already present)
    updated_players_online =
      if login in state.playersOnline do
        state.playersOnline
      else
        [login | state.playersOnline]
      end

    new_state =
      state
      |> Map.put(:scores, updated_scores)
      |> Map.put(:playersOnline, updated_players_online)

    Logger.info("👤 Player entered: #{login}")
    Logger.debug(inspect(new_state, pretty: true))

    broadcast_state_full(new_state)
    {:noreply, new_state}
  end

  # player leaves lobby
  def handle_cast({:player_leave, login}, state) do
    new_state =
      state
      |> Map.update(:playersOnline, [], fn players ->
        Enum.reject(players, &(&1 == login))
      end)

    GameEngine.dispatch(state.id, :player_leave, %{login: login})

    Logger.info("Player #{login} left lobby")

    broadcast_state_full(new_state)
    {:noreply, new_state}
  end

  def handle_cast({:add_score, login}, state) do
    new_scores =
      state.scores
      |> update_or_insert_score(login)
      |> Enum.sort_by(& &1.score, :desc)

    new_state = %{state | scores: new_scores}

    broadcast_state_full(new_state)

    Logger.info("🏆 Updated scores in lobby #{state.id}: #{inspect(new_scores)}")
    {:noreply, new_state}
  end


  def handle_info({:game_updated, _game}, state) do
    Logger.debug("Ignoring :game_updated event for now")
    {:noreply, state}
  end

  defp update_or_insert_score(scores, login) do
    case Enum.find(scores, &(&1.login == login)) do
      # Existing player → increment score
      %{score: score} = existing ->
        Enum.map(scores, fn
          ^existing -> %{login: login, score: score + 1}
          other -> other
        end)

      # New player → insert with score 1
      nil ->
        [%{login: login, score: 1} | scores]
    end
  end
end
