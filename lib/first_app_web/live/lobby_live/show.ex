defmodule FirstAppWeb.LobbyLive.Show do
  use FirstAppWeb, :live_view
  alias FirstAppWeb.{LobbiesManager, LobbyServer}

  # def mount(%{"id" => id}, _session, socket) do
  #   case Registry.lookup(FirstAppWeb.LobbyRegistry, id) do
  #     [{pid, _}] ->
  #       {:ok, assign(socket, id: id, lobby: LobbyServer.state(id))}
  #     [] ->
  #       {:ok,
  #        socket
  #        |> put_flash(:error, "Lobby not found or expired")
  #        |> push_navigate(to: ~p"/lobby")}
  #   end
  # end

  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign(socket, id: id, lobby: LobbyServer.state(id))}
  end

  def handle_event("join", %{"player" => player}, socket) do
    LobbyServer.add_player(socket.assigns.id, player)
    {:noreply, assign(socket, lobby: LobbyServer.state(socket.assigns.id))}
  end

  def render(assigns) do
    ~H"""
    <h1>Lobby: <%= @lobby.name %></h1>

    <form phx-submit="join">
      <input name="player" placeholder="Your name" />
      <button>Join</button>
    </form>

    <ul>
      <%= for player <- @lobby.players do %>
        <li><%= player %></li>
      <% end %>
    </ul>
    """
  end
end
