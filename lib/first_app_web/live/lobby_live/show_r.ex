defmodule FirstAppWeb.LobbyLive.Show do
  use FirstAppWeb, :live_view
  require Logger
  alias Phoenix.PubSub
  alias FirstAppWeb.LobbyServer
  alias FirstAppWeb.LobbiesManager
  alias RPS.GameEngine

  @impl true
  def mount(%{"id" => lobby_id, "role" => role}, session, socket) do
    player_login = session["login"]
    host = nil

    if connected?(socket) do
      # 1️⃣ Subscribe to all related topics
      PubSub.subscribe(FirstApp.PubSub, "lobby:#{lobby_id}")
      PubSub.subscribe(FirstApp.PubSub, "game:#{lobby_id}")
      PubSub.subscribe(FirstApp.PubSub, "timer:#{lobby_id}")

      LobbiesManager.add_user(lobby_id, player_login, role)
      if role != "spectator" do
        LobbyServer.player_enter(lobby_id, player_login)
      else
        LobbyServer.broadcast_state(lobby_id)
      end

    end

    {:ok,
    assign(socket,
      lobby_id: lobby_id,
      host: host,
      player_login: player_login,
      scores: [],
      playersOnline: []
    )}
  end

  # lobby state updated
  def handle_info({:lobby_state_updated, state}, socket) do

    {:noreply,
     assign(socket,
        #  TODO leftPlayer RightPlayer from Game Engine
        scores: state.scores,
        host: state.host,
        playersOnline: state.playersOnline
    )}
  end

  def render(assigns) do
    ~H"""
    <div>{assigns.lobby_id}</div>
    <div>{assigns.host}</div>

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
              player == @player_login && "text-green-600 font-bold"
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
                  <%= if player == @player_login do %>
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

end
