defmodule FirstAppWeb.LobbyLive.Show do
  use FirstAppWeb, :live_view
  alias FirstAppWeb.{LobbiesManager, LobbyServer, Presence}
  alias Phoenix.PubSub
  import FirstAppWeb.UI


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
      rightPlayer: nil,
      timer_running: false,
      tick: 0,
      winner: "",
      gameOverModalShow?: false
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

  def handle_event("start_timer", _params, socket) do
    LobbyServer.start_round_timer(socket.assigns.lobby_id)
    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    LobbyServer.clear_winner(socket.assigns.lobby_id)
    {:noreply, assign(socket, gameOverModalShow?: false, winner: "")}
  end

  # -----------------------------
  # INFO HANDLERS
  # -----------------------------

  def handle_info({:game_state_updated, state}, socket) do
    # IO.puts("♻️ Game state updated for lobby #{socket.assigns.lobby_id}")
    # IO.inspect(state, label: "Full Lobby State")

    show_modal? =
      case Map.get(state, :winner) do
        nil -> false
        "" -> false
        "draw" -> true
        _winner -> true
      end
      IO.puts("SHOW moDAL #{show_modal?}")
    {:noreply,
     assign(socket,
        scores: state.scores,
        leftPlayer: state.leftPlayer,
        rightPlayer: state.rightPlayer,
        host: state.host,
        winner: Map.get(state, :winner, ""),
        gameOverModalShow?: show_modal?
    )}
  end

  def handle_info({:timer_flag, true}, socket) do
    {:noreply, assign(socket, timer_running: true, tick: 0)}
  end

  def handle_info({:tick, n}, socket) do
    {:noreply, assign(socket, tick: n)}
  end

  def handle_info({:timer_flag, false}, socket) do
    lobby_id = socket.assigns.lobby_id
    LobbyServer.determine_winner(lobby_id)
    {:noreply, assign(socket, timer_running: false)}
  end

  def render(assigns) do
    ~H"""
    <div id="lobby" class="p-4">
      <h2 class="mb-2">Good luck: <strong><%= @login %></strong></h2>
      <h2 class="mb-4">Host: <strong><%= @host %></strong></h2>

      <!-- Timer display -->
      <div class="flex flex-col mt-20 h-fit items-center">
        <div class="mb-4 text-center">
          <%= if @timer_running do %>
            <p class="text-lg font-semibold text-green-600">⏱️ Round in progress: <%= 5 - @tick %>s</p>
          <% else %>
            <p class="text-lg font-semibold text-gray-500">🕒 Waiting for next round</p>
          <% end %>
        </div>

        <div class="rounded p-3 mb-4 bg-gray-50 h-full">
          <div class="grid grid-cols-2 gap-4 text-center h-full">
            <.player_card
              player={@leftPlayer}
              login={@login}
              timer_running={@timer_running}
              side="left"
            />

            <.player_card
              player={@rightPlayer}
              login={@login}
              timer_running={@timer_running}
              side="right"
            />
          </div>
        </div>

        <%= if @login == @host do %>
          <div class="mt-4 flex gap-2">
            <button phx-click="start_timer" class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600">Start</button>
            <button class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600">Stop</button>
            <button
              phx-click="arrange_pair"
              class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              🔁 Next Round
            </button>
          </div>
        <% end %>

        <ul>
          <%= for {login, %{score: score}} <- @scores do %>
            <li><%= login %> — <%= score %> points</li>
          <% end %>
        </ul>



        <%= if @gameOverModalShow? do %>
          <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div class="bg-white rounded-lg shadow-lg p-6 w-80 text-center">
              <h2 class="text-xl font-bold mb-4">🎉 Game Over!</h2>

              <%= if @winner == "draw" do %>
                <p class="text-lg text-gray-700 mb-4">It's a draw!</p>
              <% else %>
                <p class="text-lg text-green-600 font-semibold mb-4">Winner: <%= @winner %></p>
              <% end %>

              <button
                phx-click="close_modal"
                class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
              >
                OK
              </button>
            </div>
          </div>
        <% end %>
      </div>
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
