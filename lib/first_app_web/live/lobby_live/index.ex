defmodule FirstAppWeb.LobbyLive.Index do
  use FirstAppWeb, :live_view
  alias FirstAppWeb.LobbiesManager
  alias Phoenix.PubSub
  import FirstAppWeb.CoreComponents
  import FirstAppWeb.UI

  def mount(_params, session, socket) do
    if connected?(socket), do: LobbiesManager.subscribe_to_updates()

    login = session["login"]

    filters = %{
      name: "",
      only_without_password: false,
      only_with_player_slots: false,
      only_with_spectator_slots: false,
      order: :asc
    }

    lobbies = LobbiesManager.all()
    filtered = apply_filters(lobbies, filters)

    socket =
      socket
      |> assign(:login, login)
      |> assign(:filters, filters)
      |> assign(:lobbies, filtered)
      |> assign(:show_create_lobby_modal, false)
      |> assign(:create_lobby_form_data, empty_create_lobby_form())
      |> assign(:show_check_password_modal, false)
      |> assign(:check_password_form_data, empty_check_password_form())

    {:ok, socket}

  end

  # -----------------------------
  # HANDLE EVENTS
  # -----------------------------

  # LOBBIES

  # Create lobby submit form
  def handle_event("create_lobby", %{"lobby" => lobby_params}, socket) do
    attrs = %{
      name: lobby_params["name"],
      password: if(lobby_params["password"] == "", do: nil, else: lobby_params["password"]),
      maxPlayers: parse_int(lobby_params["maxPlayers"]),
      maxSpectators: parse_int(lobby_params["maxSpectators"]),
      host: socket.assigns.login
    }

    {:ok, _lobby} = LobbiesManager.create(attrs)

    {:noreply,
     socket
     |> assign(:lobbies, get_filtered_lobbies(socket))
     |> assign(:show_create_lobby_modal, false)
     |> assign(:create_lobby_form_data, empty_create_lobby_form())}
  end

  # On Lobby created subscription
  def handle_info({:lobby_created, _lobby}, socket) do
    {:noreply, assign(socket, :lobbies, LobbiesManager.all())}
  end

  # Toggle create lobby modal
  def handle_event("toggle_create_lobby_modal", _params, socket) do
    {:noreply, update(socket, :show_create_lobby_modal, &(!&1))}
  end


  # Check Lobby password


  # Check lobby password
  def handle_event("check_lobby_password", %{"password" => password}, socket) do
    lobby_id = socket.assigns.check_password_form_data.lobbyId
    user_login = socket.assigns.login

    case FirstAppWeb.LobbiesManager.check_password_and_approve(lobby_id, password, user_login) do
      {:ok, _lobby} ->
        {:noreply,
         socket
         |> assign(:lobbies, get_filtered_lobbies(socket))
         |> assign(:show_check_password_modal, false)
         |> assign(:check_password_form_data, %{lobbyId: nil, password: ""})
         |> put_flash(:info, "Access granted!")}

      {:error, :wrong_password} ->
        {:noreply, put_flash(socket, :error, "Wrong password, try again.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Lobby not found.")}
    end
  end

  # Toggle check lobby password modal
  def handle_event("toggle_check_lobby_password_modal", %{"id" => lobby_id}, socket) do
    current = socket.assigns.show_check_password_modal

    {show_modal, updated_form_data} =
      if current do
        {false, Map.put(socket.assigns.check_password_form_data, :lobbyId, nil)}
      else
        {true, Map.put(socket.assigns.check_password_form_data, :lobbyId, lobby_id)}
      end

      {:noreply,
      socket
      |> assign(:show_check_password_modal, show_modal)
      |> assign(:check_password_form_data, updated_form_data)}
  end

  # Close check lobby password modal
  def handle_event("close_check_lobby_password_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_check_password_modal, false)
     |> assign(:check_password_form_data,
        Map.put(socket.assigns.check_password_form_data, :lobbyId, nil)
      )}
  end


  # Filters


  # Filter by name
  def handle_event("update_filter", %{"name" => name}, socket) do
    IO.inspect(name, label: "Name filter updated")

    filters = Map.put(socket.assigns.filters, :name, name)
    lobbies = LobbiesManager.all()
    filtered = apply_filters(lobbies, filters)

    {:noreply, assign(socket, filters: filters, lobbies: filtered)}
  end

  # Order by name
  def handle_event("update_filter", %{"order" => value}, socket) do
    order =
      case value do
        "asc" -> :asc
        "desc" -> :desc
        _ -> :asc
      end

    filters = Map.put(socket.assigns.filters, :order, order)
    lobbies = LobbiesManager.all()
    filtered = apply_filters(lobbies, filters)

    {:noreply, assign(socket, filters: filters, lobbies: filtered)}
  end

  # Filter by checkbox(password, amount of players and spectators places) CHECKBOX ON
  def handle_event("update_filter", %{"filter" => filter, "value" => value}, socket) do
    flag = value in ["true", "on"]
    atom_key = String.to_existing_atom(filter)
    filters = Map.put(socket.assigns.filters, atom_key, flag)

    lobbies = LobbiesManager.all()
    filtered = apply_filters(lobbies, filters)

    {:noreply, assign(socket, filters: filters, lobbies: filtered)}
  end
  # Filter by checkbox(password, amount of players and spectators places) CHECKBOX OFF
  def handle_event("update_filter", %{"filter" => filter}, socket) do
    atom_key = String.to_existing_atom(filter)
    filters = Map.put(socket.assigns.filters, atom_key, false)

    lobbies = LobbiesManager.all()
    filtered = apply_filters(lobbies, filters)

    {:noreply, assign(socket, filters: filters, lobbies: filtered)}
  end


  # User enter/left lobby

  def handle_info({:user_entered_lobby, lobby_id, login, role}, socket) do
    updated_lobby = LobbiesManager.get(lobby_id)

    new_lobbies =
      Enum.map(socket.assigns.lobbies, fn
        %{id: ^lobby_id} -> updated_lobby
        lobby -> lobby
      end)

    {:noreply,
     socket
     |> assign(:lobbies, new_lobbies)
     |> put_flash(:info, "#{login} joined lobby #{lobby_id} as #{role}!")}
  end

  def handle_info({:user_left_lobby, lobby_id, login, role}, socket) do
    updated_lobby = LobbiesManager.get(lobby_id)

    new_lobbies =
      Enum.map(socket.assigns.lobbies, fn
        %{id: ^lobby_id} -> updated_lobby
        lobby -> lobby
      end)

    {:noreply,
     socket
     |> assign(:lobbies, new_lobbies)
     |> put_flash(:info, "#{login} left lobby #{lobby_id} as #{role}!")}
  end

  # -----------------------------
  # RENDER
  # -----------------------------

  def render(assigns) do
    ~H"""
    <div class="p-6 h-screen flex flex-col items-center mt-[100px]">
      <h1 class="text-2xl font-bold mb-4">🎮 Lobbies</h1>

      <!-- Lobbies Table -->
      <.table_styled>
        <.thead_styled>
          <.form for={%{}} phx-change="update_filter">
            <tr>
              <.table_header_col>
                <.button
                  title="Create lobby"
                  variant="primary"
                  phx-click="toggle_create_lobby_modal"
                  class="bg-green-600 hover:bg-green-700 p-2 rounded text-white font-semibold shadow-md flex items-center gap-2"
                >
                ➕
                </.button>
                <.input
                  type="text"
                  name="name"
                  placeholder="Search by name..."
                  value={@filters.name}
                  phx-debounce="300"
                  phx-value-filter="name"
                  phx-value-value={@filters.name}
                  class="w-[100px] "
                />
                <.input
                  type="select"
                  name="order"
                  phx-change="update_filter"
                  phx-value-filter="order"
                  options={[
                    {"A → Z", "asc"},
                    {"Z → A", "desc"}
                  ]}
                  value={Atom.to_string(@filters.order)}
                  class="w-fit"
                />
              </.table_header_col>
              <.table_header_col>
                <span>Players</span>
                <label class="flex items-center gap-1">
                  <input
                    type="checkbox"
                    phx-click="update_filter"
                    phx-value-filter="only_with_player_slots"
                    phx-value-value={!@filters.only_with_player_slots}
                    checked={@filters.only_with_player_slots}
                  />
                </label>
              </.table_header_col>
              <.table_header_col>
                <span>Spectators</span>
                <label class="flex items-center gap-1">
                  <input
                    type="checkbox"
                    phx-click="update_filter"
                    phx-value-filter="only_with_spectator_slots"
                    phx-value-value={!@filters.only_with_spectator_slots}
                    checked={@filters.only_with_spectator_slots}
                  />
                </label>
              </.table_header_col>
              <.table_header_col>
                <span>Password</span>
                <label class="flex items-center gap-1">
                  <input
                    type="checkbox"
                    phx-click="update_filter"
                    phx-value-filter="only_without_password"
                    phx-value-value={!@filters.only_without_password}
                    checked={@filters.only_without_password}
                  />
                </label>
              </.table_header_col>
            </tr>
          </.form>
        </.thead_styled>
        <tbody>
          <%= for lobby <- @lobbies do %>
            <.tr_styled>
              <.td_styled><%= lobby.name %></.td_styled>
              <.td_styled>
                <%= map_size(lobby.players) %>/<%= lobby.maxPlayers || "∞" %>
              </.td_styled>
              <.td_styled>
                <%= map_size(lobby.spectators) %>/<%= lobby.maxSpectators || "∞" %>
              </.td_styled>
              <.td_styled>
                <div class="pl-2">
                  <%= if lobby.password && !Map.has_key?(lobby.approvedList, @login) do %>
                    <.button
                      variant="secondary"
                      phx-click="toggle_check_lobby_password_modal"
                      phx-value-id={lobby.id}
                      class="flex justify-center w-[86px] bg-gray-500 hover:bg-gray-600 px-3 py-1.5 rounded shadow-lg transition hover:scale-[1.05]"
                      title="Join with password"
                    >
                      🔒
                    </.button>
                  <% else %>
                    <%= if map_size(lobby.players) < lobby.maxPlayers do %>
                      <.link
                      navigate={~p"/lobby/#{lobby.id}/player"}
                      title="Join this lobby as a player"
                      class="inline-block bg-blue-400 hover:bg-blue-500 text-white px-3 py-1.5 rounded shadow-sm transition"
                      >
                        🎮
                      </.link>
                    <% end %>

                    <%= if map_size(lobby.spectators) < lobby.maxSpectators do %>
                      <.link
                      navigate={~p"/lobby/#{lobby.id}/spectator"}
                      title="Watch this match as a spectator"
                      class="inline-block bg-amber-600 hover:bg-amber-800 text-white px-3 py-1.5 rounded shadow-sm transition"
                      >
                        👀
                      </.link>
                    <% end %>

                    <%= if map_size(lobby.players) >= lobby.maxPlayers and
                          map_size(lobby.spectators) >= lobby.maxSpectators do %>
                      <span class="opacity-60 cursor-not-allowed">Lobby is full</span>
                    <% end %>
                  <% end %>
                </div>
              </.td_styled>
            </.tr_styled>
          <% end %>
        </tbody>
      </.table_styled>
    </div>

<!-- Create Lobby Modal -->
<%= if @show_create_lobby_modal do %>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center">
    <div class="bg-white p-6 rounded-lg w-[400px] shadow-lg">
      <h2 class="text-lg font-bold mb-4">Create New Lobby</h2>

      <.form for={%{}} phx-submit="create_lobby">
        <.input
          type="text"
          name="lobby[name]"
          label="Lobby Name"
          value={@create_lobby_form_data.name}
          placeholder="Lobby Name"
        />
        <.input
          type="text"
          name="lobby[password]"
          label="Password (optional)"
          value={@create_lobby_form_data.password}
          placeholder="Password (optional)"
        />
        <.input
          type="number"
          name="lobby[maxPlayers]"
          label="Max Players"
          value={@create_lobby_form_data.maxPlayers}
        />
        <.input
          type="number"
          name="lobby[maxSpectators]"
          label="Max Spectators"
          value={@create_lobby_form_data.maxSpectators}
        />

        <div class="mt-5 flex justify-end gap-2">
          <.button
            type="button"
            variant="secondary"
            phx-click="toggle_create_lobby_modal"
          >
            Cancel
          </.button>

          <.button variant="primary" type="submit">Create</.button>
        </div>
      </.form>
    </div>
  </div>
<% end %>

<!-- Check Password Modal -->
<%= if @show_check_password_modal do %>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center">
    <div class="bg-white p-6 rounded-lg w-[400px] shadow-lg">
      <h2 class="text-lg font-bold mb-4">Password</h2>

      <.form for={%{}} phx-submit="check_lobby_password">
        <.input
          type="text"
          name="password"
          label="Lobby password"
          value={@check_password_form_data.password}
          placeholder="Lobby password"
        />

        <div class="mt-5 flex justify-end gap-2">
          <.button
            type="button"
            variant="secondary"
            phx-click="close_check_lobby_password_modal"
          >
            Cancel
          </.button>

          <.button variant="primary" type="submit">Submit</.button>
        </div>
      </.form>
    </div>
  </div>
<% end %>
    """
  end


  # -----------------------------
  # HELPERS
  # -----------------------------

  defp empty_create_lobby_form do
    %{name: "", password: "", maxPlayers: "", maxSpectators: ""}
  end

  defp empty_check_password_form do
    %{password: "", lobbyId: ""}
  end


  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(str), do: String.to_integer(str)


  # Filters


  defp get_filtered_lobbies(socket) do
    filters = socket.assigns.filters
    lobbies = FirstAppWeb.LobbiesManager.all()
    apply_filters(lobbies, filters)
  end

  defp filter_by_name(lobbies, ""), do: lobbies
  defp filter_by_name(lobbies, name) do
    Enum.filter(lobbies, fn lobby ->
      String.contains?(String.downcase(lobby.name), String.downcase(name))
    end)
  end

  defp filter_by_password(lobbies, false), do: lobbies
  defp filter_by_password(lobbies, true) do
    Enum.filter(lobbies, fn lobby -> is_nil(lobby.password) or lobby.password == "" end)
  end

  defp filter_by_players(lobbies, false), do: lobbies
  defp filter_by_players(lobbies, true) do
    Enum.filter(lobbies, fn lobby ->
      case lobby.maxPlayers do
        nil -> true
        max when is_integer(max) -> map_size(lobby.players) < max
      end
    end)
  end

  defp filter_by_spectators(lobbies, false), do: lobbies
  defp filter_by_spectators(lobbies, true) do
    Enum.filter(lobbies, fn lobby ->
      case lobby.maxSpectators do
        nil -> true
        max when is_integer(max) -> map_size(lobby.spectators) < max
      end
    end)
  end

  defp sort_by_name(lobbies, :asc), do: Enum.sort_by(lobbies, & &1.name, :asc)
  defp sort_by_name(lobbies, :desc), do: Enum.sort_by(lobbies, & &1.name, :desc)

  defp apply_filters(lobbies, filters) do
    lobbies
    |> filter_by_name(filters.name)
    |> filter_by_password(filters.only_without_password)
    |> filter_by_players(filters.only_with_player_slots)
    |> filter_by_spectators(filters.only_with_spectator_slots)
    |> sort_by_name(filters.order)
  end
end
