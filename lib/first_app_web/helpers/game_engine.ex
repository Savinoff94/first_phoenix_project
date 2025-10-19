defmodule FirstAppWeb.GameEngine do
  use GenServer
  alias Phoenix.PubSub
  alias FirstAppWeb.RPS
  alias FirstAppWeb.LinkedList
  alias FirstAppWeb.LobbyServer
  alias FirstAppWeb.TimerWorker
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

    PubSub.broadcast(FirstApp.PubSub, state.topic, {:game_updated, updated.game})

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
    else
      Logger.info("Enough players to start game (#{length(players_online)})")

      # 1️⃣ Reset winner in game state
      new_game = Map.put(state.game, :winner, nil)
      new_state = %{state | game: new_game}

      # 2️⃣ Dispatch to arrange new pair
      dispatch(new_state.lobby_id, :arrange_pair, %{players_online: players_online})

      # 3️⃣ Return updated state
      new_state
    end
  end

  defp process_event(:arrange_pair, %{players_online: players_online}, state) do
    cond do
      # Case 1: exactly two players, already paired
      length(players_online) == 2 and not is_nil(state.game.leftPlayer) and not is_nil(state.game.rightPlayer) ->
        Logger.debug("case 1: both slots filled")

        dispatch(state.lobby_id, :player_ready_check, state)
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

        dispatch(state.lobby_id, :player_ready_check, state)
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

        dispatch(state.lobby_id, :player_ready_check, state)
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

  defp process_event(:player_ready_check, _params, state) do
    TimerWorker.start_timer(state.lobby_id, 10, :arrange_pair_on_ready)
    state
  end

  defp process_event(:player_ready, %{login: login}, state) do

    game = state.game

    # 1️⃣ Determine which player is being updated
    updated_game =
      cond do
        game.leftPlayer && game.leftPlayer.login == login ->
          put_in(game, [:leftPlayer, :ready], true)

        game.rightPlayer && game.rightPlayer.login == login ->
          put_in(game, [:rightPlayer, :ready], true)

        true ->
          game
      end

    # 2️⃣ Check if both are now ready
    both_ready? =
      updated_game.leftPlayer.ready and updated_game.rightPlayer.ready

    # 3️⃣ Dispatch event if both ready
    if both_ready? do
      dispatch(state.lobby_id, :both_players_ready, state)
    end

    # 4️⃣ Return updated state
    %{state | game: updated_game}
  end

  defp process_event(:both_players_ready, _params, state) do
    TimerWorker.stop_timer(state.lobby_id)
    dispatch(state.lobby_id, :start_round, state)
    state
  end

  # rearrange pair if some of players not ready to game
  defp process_event(:arrange_pair_on_ready, %{lobby_id: lobby_id}, state) do
    players_online = FirstAppWeb.LobbyServer.get_players_online(state.lobby_id)
    game = state.game

    # 1️⃣ Split current players into ready and not ready
    ready_players =
      [game.leftPlayer, game.rightPlayer]
      |> Enum.filter(& &1.ready)
      |> Enum.map(& &1.login)

    not_ready_players =
      [game.leftPlayer, game.rightPlayer]
      |> Enum.filter(& !&1.ready)
      |> Enum.map(& &1.login)

    Logger.debug("✅ Ready players: #{inspect(ready_players)}")
    Logger.debug("❌ Not ready players: #{inspect(not_ready_players)}")

    # 2️⃣ Determine who is available to replace (those online but not currently playing)
    replacements = players_online -- not_ready_players -- ready_players
    Logger.debug("🧩 Replacement pool: #{inspect(replacements)}")

    cond do
      # 3️⃣ Enough replacements to continue
      length(replacements) >= length(not_ready_players) ->
        # pick exactly as many new players as needed
        {new_left, new_right} =
          case {Enum.member?(ready_players, game.leftPlayer.login),
                Enum.member?(ready_players, game.rightPlayer.login)} do
            {true, true} ->
              {game.leftPlayer.login, game.rightPlayer.login}

            {true, false} ->
              [new_right | _] = replacements
              {game.leftPlayer.login, new_right}

            {false, true} ->
              [new_left | _] = replacements
              {new_left, game.rightPlayer.login}

            {false, false} ->
              [new_left, new_right | _] = replacements
              {new_left, new_right}
          end

        new_game = %{
          game
          | leftPlayer: %{login: new_left, selected: "Rock", ready: false},
            rightPlayer: %{login: new_right, selected: "Rock", ready: false},
            winner: nil
        }

        Logger.info("🔁 Pair arranged: #{new_left} vs #{new_right}")

        # ✅ Use full new state for next dispatch
        new_state = %{state | game: new_game}
        dispatch(state.lobby_id, :player_ready_check, new_state)
        new_state

      # 4️⃣ Not enough players — stop game
      true ->
        Logger.warning("🛑 Not enough replacements — stopping game for lobby #{state.lobby_id}")
        dispatch(state.lobby_id, :stop_engine, state)
        state
    end
  end

  defp process_event(:stop_engine, _params, state) do
    TimerWorker.stop_timer(state.lobby_id)

    new_game = %{
      state.game
      | leftPlayer: nil,
        rightPlayer: nil,
        winner: nil
    }

    Logger.info("Game stopped for lobby #{state.lobby_id}")
    %{state | game: new_game}
  end

  defp process_event(:start_round, _params, state) do
    TimerWorker.start_timer(state.lobby_id, 10, :evaluate_winner)

    Logger.info("round started")
    state
  end

  defp process_event(:player_made_choice, %{login: login, choice: choice}, state) do
    updated_game =
      cond do
        state.game.leftPlayer && state.game.leftPlayer.login == login ->
          put_in(state.game, [:leftPlayer, :selected], choice)

        state.game.rightPlayer && state.game.rightPlayer.login == login ->
          put_in(state.game, [:rightPlayer, :selected], choice)

        true ->
          state.game
      end

    %{state | game: updated_game}
  end

  defp process_event(:evaluate_winner, %{lobby_id: lobby_id}, state) do
    left = state.game.leftPlayer
    right = state.game.rightPlayer

    cond do
      # Not enough players
      is_nil(left) or is_nil(right) ->
        Logger.info("⏸️ Not enough players to determine winner")
        state

      # One or both players didn't choose
      left.selected in [nil, ""] or right.selected in [nil, ""] ->
        Logger.info("⏸️ One or both players did not make a selection")
        state

      # Both players made their choices
      true ->
        winner = RPS.determine_winner(left, right)
        result = if winner, do: winner, else: "draw"
        LobbyServer.add_score(lobby_id, winner)

        Logger.info("🏁 Winner determined: #{inspect(result)}")

        new_game = Map.put(state.game, :winner, result)
        new_state = %{state | game: new_game}

        dispatch(state.lobby_id, :finish_round, new_state)
        new_state
    end
  end

  defp process_event(:finish_round, %{lobby_id: lobby_id}, state) do
    TimerWorker.start_timer(state.lobby_id, 10, :suggest_start_game)

    # Reset players' ready flags
    new_game =
      state.game
      |> Map.update!(:leftPlayer, fn p ->
        if p, do: %{p | ready: false}, else: p
      end)
      |> Map.update!(:rightPlayer, fn p ->
        if p, do: %{p | ready: false}, else: p
      end)

    %{state | game: new_game}
  end
end
