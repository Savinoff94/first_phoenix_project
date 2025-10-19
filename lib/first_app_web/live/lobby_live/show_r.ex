defmodule FirstAppWeb.LobbyLive.Show do
  use FirstAppWeb, :live_view
  require Logger
  alias Phoenix.PubSub
  alias FirstAppWeb.LobbyServer
  alias FirstAppWeb.LobbiesManager
  alias FirstAppWeb.GameEngine
  import FirstAppWeb.UI


  @impl true
  def mount(%{"id" => lobby_id, "role" => role}, session, socket) do
    login = session["login"]
    host = nil

    if connected?(socket) do
      # 1️⃣ Subscribe to all related topics
      PubSub.subscribe(FirstApp.PubSub, "lobby:#{lobby_id}")
      PubSub.subscribe(FirstApp.PubSub, "game:#{lobby_id}")
      PubSub.subscribe(FirstApp.PubSub, "timer:#{lobby_id}")

      LobbiesManager.add_user(lobby_id, login, role)
      if role != "spectator" do
        LobbyServer.player_enter(lobby_id, login)
      else
        LobbyServer.broadcast_state(lobby_id)
      end

    end

    {:ok,
    assign(socket,
      lobby_id: lobby_id,
      role: role,
      host: host,
      login: login,
      scores: [],
      playersOnline: [],
      leftPlayer: nil,
      rightPlayer: nil,
      roundTimer: false,
      readyTimer: false,
      winner: nil,
      in_the_loop: false,
      tick: 0
    )}
  end

  def handle_event("suggest_start_game", _params, socket) do
    GameEngine.dispatch(socket.assigns.lobby_id, :suggest_start_game, %{})
    {:noreply, socket}
  end
  def handle_event("player_ready", _params, socket) do
    GameEngine.dispatch(socket.assigns.lobby_id, :player_ready, %{login: socket.assigns.login})
    {:noreply,
    assign(socket,
      readyTimer: false
    )}
  end

  # lobby state updated
  def handle_info({:lobby_state_updated, state}, socket) do
    {:noreply,
     assign(socket,
        scores: state.scores,
        host: state.host,
        playersOnline: state.playersOnline
    )}
  end

  # game state updated
  def handle_info({:game_updated, state}, socket) do

    {:noreply,
     assign(socket,
      leftPlayer: state.leftPlayer,
      rightPlayer: state.rightPlayer,
      winner: state.winner,
      in_the_loop: state.in_the_loop
    )}
  end

  # tick
  def handle_info({:tick, n}, socket) do
    {:noreply, assign(socket, tick: n)}
  end

  def handle_info({:timer_start_flag, flag, :suggest_start_game}, socket) do

    {:noreply, socket}
  end

  # modal where player approves that ready
  def handle_info({:timer_start_flag, flag, :arrange_pair_on_ready}, socket) do
    {:noreply, assign(socket, readyTimer: flag)}
  end
  def handle_info({:timer_finished, _flag}, socket) do
    # Do nothing, just ignore it
    {:noreply, socket}
  end

  # round started
  def handle_info({:timer_start_flag, flag, :evaluate_winner}, socket) do
    {:noreply, assign(socket, roundTimer: flag)}
  end


  def handle_event("player_made_choice", %{"choice" => choice}, socket) do
    login = socket.assigns.login
    lobby_id = socket.assigns.lobby_id

    GameEngine.dispatch(lobby_id, :player_made_choice, %{login: login, choice: choice})
    {:noreply, socket}
  end
  def handle_event("close_winner_modal", _param, socket) do

    {:noreply, assign(
      socket,
      winner: nil,
      showWinnerModal: false
    )}
  end

  def render(assigns) do
    ~H"""
    <div>{assigns.lobby_id}</div>
    <div>{assigns.host}</div>

    <div class="mb-4 text-center">
      <%= if @roundTimer do %>
        <p class="text-lg font-semibold text-green-600">⏱️ Round in progress: <%= @tick %>s</p>
      <% else %>
        <p class="text-lg font-semibold text-gray-500">🕒 Waiting for next round</p>
      <% end %>
    </div>

    <div class="rounded p-3 mb-4 bg-gray-50 h-full">
      <div class="grid grid-cols-2 gap-4 text-center h-full">
        <.player_card
          player={@leftPlayer}
          login={@login}
          timer_running={@roundTimer}
          role={@role}
          side="left"
        />

        <.player_card
          player={@rightPlayer}
          login={@login}
          timer_running={@roundTimer}
          role={@role}
          side="right"
        />
      </div>
    </div>

    <%= if @login == @host do %>
      <div class="mt-4 flex gap-2">
        <button
          phx-click="suggest_start_game"
          class={[
            "px-4 py-2 text-white rounded transition",
            if(length(@playersOnline) > 1,
              do: "bg-green-500 hover:bg-green-600",
              else: "bg-gray-400 cursor-not-allowed opacity-60"
            )
          ]}
          disabled={length(@playersOnline) < 2 or @in_the_loop}
        >
          Start
        </button>
      </div>
    <% end %>

    <!-- Players Online -->
    <div class="p-4 bg-blue-50 rounded-lg">
      <h2 class="text-xl font-semibold mb-2">👥 Players Online</h2>

      <%= if Enum.empty?(@playersOnline) do %>
        <p class="text-gray-500 italic">No players online.</p>
      <% else %>
        <ul class="list-disc list-inside space-y-1">
          <%= for player <- @playersOnline do %>
            <li class={[
              "font-medium",
              player == @login && "text-green-600 font-bold"
            ]}>
              <%= player %>
              <%= if player == @host do %>
                <span class="text-xs text-gray-500">(host)</span>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>

    <!-- Scores -->
    <div class="p-4 bg-yellow-50 rounded-lg">
      <h2 class="text-xl font-semibold mb-2">🏆 Scores</h2>

      <%= if Enum.empty?(@scores) do %>
        <p class="text-gray-500 italic">No scores yet.</p>
      <% else %>
        <table class="min-w-full border border-gray-300 rounded">
          <thead class="bg-gray-200">
            <tr>
              <th class="px-4 py-2 text-left">Player</th>
              <th class="px-4 py-2 text-right">Score</th>
            </tr>
          </thead>
          <tbody>
            <%= for %{login: player, score: score} <- @scores do %>
              <tr class="border-t border-gray-300">
                <td class="px-4 py-2">
                  <%= player %>
                  <%= if player == @login do %>
                    <span class="text-xs text-green-600">(you)</span>
                  <% end %>
                </td>
                <td class="px-4 py-2 text-right font-semibold"><%= score %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>

      <%= if @readyTimer and (
      @login == (@leftPlayer && @leftPlayer.login) or
      @login == (@rightPlayer && @rightPlayer.login)
      ) and @tick != 0 do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg shadow-lg p-6 w-80 text-center">
            <h2 class="text-xl font-bold mb-4">Are you ready? <%= @tick %> </h2>

            <button
              phx-click="player_ready"
              class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              OK
            </button>
          </div>
        </div>
      <% end %>

      <%= if @winner do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg shadow-lg p-6 w-80 text-center">
            <h2 class="text-xl font-bold mb-4">🎉 Game Over!</h2>

            <%= cond do %>
              <% @winner == "draw" -> %>
                <p class="text-lg text-gray-700 mb-4">It's a draw!</p>

              <% @winner == @login -> %>
                <p class="text-lg text-green-700 font-bold mb-4 animate-bounce">You are the winner!</p>

              <% true -> %>
                <p class="text-lg text-green-600 font-semibold mb-4">
                  Winner: <%= @winner %>
                </p>
            <% end %>

            <button
              phx-click="close_winner_modal"
              class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              OK
            </button>
          </div>
        </div>
      <% end %>
    </div>

    """
  end

  def terminate(reason, socket) do
    role = socket.assigns.role
    login = socket.assigns.login
    lobby_id = socket.assigns.lobby_id
    LobbiesManager.remove_user(lobby_id, login, role)
    if role != "spectator" do
      LobbyServer.player_leave(lobby_id, login)
    end

    if socket.assigns.in_the_loop and (
        (socket.assigns.leftPlayer && socket.assigns.leftPlayer.login == login) or
        (socket.assigns.rightPlayer && socket.assigns.rightPlayer.login == login)
      ) do
      Logger.info("🔁 #{login} left mid-round — restarting game automatically")
      GameEngine.dispatch(lobby_id, :suggest_start_game, %{})
    end


    IO.inspect(socket, label: "player left terminate", pretty: true)
    :ok
  end

end
