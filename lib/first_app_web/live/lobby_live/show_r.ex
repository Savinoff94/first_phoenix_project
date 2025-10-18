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
      gameTimer: false
    )}
  end

  def handle_event("suggest_start_game", _params, socket) do
    GameEngine.dispatch(socket.assigns.lobby_id, :suggest_start_game, %{})
    {:noreply, socket}
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
      rightPlayer: state.rightPlayer
    )}
  end

  def render(assigns) do
    ~H"""
    <div>{assigns.lobby_id}</div>
    <div>{assigns.host}</div>

    <div class="rounded p-3 mb-4 bg-gray-50 h-full">
      <div class="grid grid-cols-2 gap-4 text-center h-full">
        <.player_card
          player={@leftPlayer}
          login={@login}
          timer_running={@gameTimer}
          role={@role}
          side="left"
        />

        <.player_card
          player={@rightPlayer}
          login={@login}
          timer_running={@gameTimer}
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
          disabled={length(@playersOnline) < 2}
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
            <%= for {player, score} <- @scores do %>
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
    IO.inspect(socket, label: "player left terminate", pretty: true)
    :ok
  end

end
