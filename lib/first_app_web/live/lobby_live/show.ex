defmodule FirstAppWeb.LobbyLive.Show do
  use FirstAppWeb, :live_view
  alias FirstAppWeb.{LobbiesManager, LobbyServer, Presence}
  alias Phoenix.PubSub

  def mount(%{"id" => lobby_id, "role" => role}, session, socket) do
    topic = "lobby:#{lobby_id}"
    login = session["login"]

    if connected?(socket) do
      PubSub.subscribe(FirstApp.PubSub, topic)
      LobbiesManager.add_user(lobby_id, login, role)
      LobbyServer.add_player(lobby_id, login)
    end

    host = LobbyServer.get_host(lobby_id) || ""

    {:ok,
    assign(socket,
      lobby_id: lobby_id,
      topic: topic,
      login: login,
      role: role,
      scores: %{},
      host: host,
      leftPlayer: nil,
      rightPlayer: nil
    )}
  end

  def handle_event("arrange_pair", _params, socket) do
    LobbyServer.arrange_pair(socket.assigns.lobby_id, socket.assigns.host)
    {:noreply, socket}
  end

  def handle_event("player_select", %{"choice" => choice}, socket) do
    login = socket.assigns.login
    lobby_id = socket.assigns.lobby_id

    LobbyServer.player_selected(lobby_id, login, choice)
    {:noreply, socket}
  end

  # -----------------------------
  # INFO HANDLERS
  # -----------------------------

  def handle_info({:game_state_updated, state}, socket) do
    # IO.puts("♻️ Game state updated for lobby #{socket.assigns.lobby_id}")
    # IO.inspect(state, label: "Full Lobby State")

    {:noreply,
     assign(socket,
       scores: state.scores,
       leftPlayer: state.leftPlayer,
       rightPlayer: state.rightPlayer,
       host: state.host
    )}
  end

  # def render(assigns) do
  #   ~H"""
  #   <%!-- <div id="lobby" phx-hook="LeaveLobby"> --%>
  #   <h1>Lobby: !!!!!!!!!</h1>
  #   <h1>Current user {@login}</h1>
  #   <h1>Host {@host}</h1>

  #   <div class="border rounded p-3 mb-4 bg-gray-50">
  #     <h3 class="font-semibold mb-2">Current Pair:</h3>

  #     <p><strong>Left Player:</strong>
  #       <%= if @leftPlayer != nil, do: @leftPlayer[:login], else: "Waiting..." %>
  #     </p>

  #     <p><strong>Right Player:</strong>
  #       <%= if @rightPlayer != nil, do: @rightPlayer[:login], else: "Waiting..." %>
  #     </p>

  #     <p><strong>Left Selected:</strong>
  #       <%= if @leftPlayer != nil, do: @leftPlayer[:selected], else: "-" %>
  #     </p>

  #     <p><strong>Right Selected:</strong>
  #       <%= if @rightPlayer != nil, do: @rightPlayer[:selected], else: "-" %>
  #     </p>
  #   </div>
  #   <ul>
  #       <%= for {login, %{score: score}} <- @scores do %>
  #         <li><%= login %> — <%= score %> points</li>
  #       <% end %>

  #       <%= if @login === @host do %>
  #       <div>
  #         <button>Start</button>
  #         <button>Stop</button>
  #         <button
  #           phx-click="arrange_pair"
  #           class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
  #         >
  #           🔁 Next Round
  #         </button>
  #       </div>
  #       <% end %>
  #   </ul>
  #   <%!-- </div> --%>
  #   """
  # end

  def render(assigns) do
    ~H"""
    <div id="lobby" class="p-4">
      <h1 class="text-xl font-bold mb-2">Lobby: <%= @lobby_id %></h1>
      <h2 class="mb-2">Current user: <strong><%= @login %></strong></h2>
      <h2 class="mb-4">Host: <strong><%= @host %></strong></h2>

      <div class="border rounded p-3 mb-4 bg-gray-50">
        <h3 class="font-semibold mb-2">Current Pair:</h3>

        <div class="grid grid-cols-2 gap-4 text-center">
          <div class="p-2 border rounded">
            <h4 class="font-bold">Left Player</h4>
            <p><%= if @leftPlayer, do: @leftPlayer.login, else: "Waiting..." %></p>
            <p class="text-gray-600 italic">
              Choice: <%= if @leftPlayer, do: @leftPlayer.selected || "-", else: "-" %>
            </p>

            <%= if @leftPlayer && @login == @leftPlayer.login do %>
              <div class="mt-2 flex justify-center gap-2">
                <button phx-click="player_select" phx-value-choice="Rock"
                  class="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300">🪨 Rock</button>
                <button phx-click="player_select" phx-value-choice="Paper"
                  class="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300">📄 Paper</button>
                <button phx-click="player_select" phx-value-choice="Scissors"
                  class="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300">✂️ Scissors</button>
              </div>
            <% end %>
          </div>

          <div class="p-2 border rounded">
            <h4 class="font-bold">Right Player</h4>
            <p><%= if @rightPlayer, do: @rightPlayer.login, else: "Waiting..." %></p>
            <p class="text-gray-600 italic">
              Choice: <%= if @rightPlayer, do: @rightPlayer.selected || "-", else: "-" %>
            </p>

            <%= if @rightPlayer && @login == @rightPlayer.login do %>
              <div class="mt-2 flex justify-center gap-2">
                <button phx-click="player_select" phx-value-choice="Rock"
                  class="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300">🪨 Rock</button>
                <button phx-click="player_select" phx-value-choice="Paper"
                  class="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300">📄 Paper</button>
                <button phx-click="player_select" phx-value-choice="Scissors"
                  class="px-3 py-2 bg-gray-200 rounded hover:bg-gray-300">✂️ Scissors</button>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <ul>
        <%= for {login, %{score: score}} <- @scores do %>
          <li><%= login %> — <%= score %> points</li>
        <% end %>
      </ul>

      <%= if @login == @host do %>
        <div class="mt-4 flex gap-2">
          <button class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600">Start</button>
          <button class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600">Stop</button>
          <button
            phx-click="arrange_pair"
            class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            🔁 Next Round
          </button>
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
    LobbyServer.remove_player(lobby_id, login)
    IO.inspect(socket, label: "player left terminate", pretty: true)
    # TODO if host leaves stop game
    :ok
  end
end
