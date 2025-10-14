defmodule FirstAppWeb.LobbyLive.Index do
  use FirstAppWeb, :live_view
  alias FirstAppWeb.LobbiesManager
  alias Phoenix.PubSub

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
      maxSpectators: parse_int(lobby_params["maxSpectators"])
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

  # -----------------------------
  # RENDER
  # -----------------------------

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-bold mb-4">🎮 Lobbies</h1>

      <!-- Filters -->
      <div class="flex flex-wrap items-center gap-4 mb-6">
        <form
          phx-change="update_filter"
        >
          <input
            type="text"
            placeholder="Search by name..."
            value={@filters.name}
            phx-debounce="300"
            name="name"
            phx-value-filter="name"
            phx-value-value={@filters.name}
            class="border rounded px-2 py-1"
          />



          <label>
            <input
              type="checkbox"
              phx-click="update_filter"
              phx-value-filter="only_without_password"
              phx-value-value={!@filters.only_without_password}
              checked={@filters.only_without_password}
            />
            Only without password
          </label>

          <label>
            <input
              type="checkbox"
              phx-click="update_filter"
              name="filter"
              phx-value-filter="only_with_player_slots"
              phx-value-value={!@filters.only_with_player_slots}
              checked={@filters.only_with_player_slots}
            />
            Has player slots
          </label>

          <label>
            <input
              type="checkbox"
              phx-click="update_filter"
              name="filter"
              phx-value-filter="only_with_spectator_slots"
              phx-value-value={!@filters.only_with_spectator_slots}
              checked={@filters.only_with_spectator_slots}
            />
            Has spectator slots
          </label>

          <select
            phx-change="update_filter"
            name="order"
            phx-value-filter="order"
            class="border rounded px-2 py-1"
          >
            <option value="asc" selected={@filters.order == :asc}>A → Z</option>
            <option value="desc" selected={@filters.order == :desc}>Z → A</option>
          </select>
        </form>

        <button
          class="ml-auto bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded"
          phx-click="toggle_create_lobby_modal"
        >
          Create Lobby
        </button>
      </div>

      <!-- Lobbies Table -->
      <table class="min-w-full border-collapse border border-gray-300">
        <thead class="bg-gray-100">
          <tr>
            <th class="border p-2 text-left">Name</th>
            <th class="border p-2">Players</th>
            <th class="border p-2">Spectators</th>
            <th class="border p-2">Password</th>
          </tr>
        </thead>
        <tbody>
          <%= for lobby <- @lobbies do %>
            <tr class="hover:bg-gray-50">
              <td class="border p-2 font-medium"><%= lobby.name %></td>
              <td class="border p-2 text-center">
                <%= length(lobby.players) %>/<%= lobby.maxPlayers || "∞" %>
              </td>
              <td class="border p-2 text-center">
                <%= length(lobby.spectators) %>/<%= lobby.maxSpectators || "∞" %>
              </td>
              <td class="border p-2 text-center">

              <%= if lobby.password && !(@login in lobby.approvedList) do %>
                <button
                  phx-click="toggle_check_lobby_password_modal"
                  phx-value-id={lobby.id}
                  class="text-yellow-600 hover:text-yellow-800"
                  title="Join with password"
                >
                  🔒
                </button>
              <% else %>
                <.link navigate={~p"/lobby/#{lobby.id}"}><%= lobby.name %></.link>
              <% end %>

              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <%= if @show_create_lobby_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center">
        <div class="bg-white p-6 rounded-lg w-[400px] shadow-lg">
          <h2 class="text-lg font-bold mb-4">Create New Lobby</h2>

          <form phx-submit="create_lobby">
            <div class="space-y-3">
              <input
                type="text"
                name="lobby[name]"
                placeholder="Lobby Name"
                value={@create_lobby_form_data.name}
                class="w-full border rounded px-2 py-1"
              />
              <input
                type="text"
                name="lobby[password]"
                placeholder="Password (optional)"
                value={@create_lobby_form_data.password}
                class="w-full border rounded px-2 py-1"
              />
              <input
                type="number"
                name="lobby[maxPlayers]"
                placeholder="Max Players"
                value={@create_lobby_form_data.maxPlayers}
                class="w-full border rounded px-2 py-1"
              />
              <input
                type="number"
                name="lobby[maxSpectators]"
                placeholder="Max Spectators"
                value={@create_lobby_form_data.maxSpectators}
                class="w-full border rounded px-2 py-1"
              />
            </div>

            <div class="mt-5 flex justify-end gap-2">
              <button type="button" phx-click="toggle_create_lobby_modal" class="px-3 py-1 border rounded">
                Cancel
              </button>
              <button type="submit" class="px-3 py-1 bg-blue-600 text-white rounded">
                Create
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <!-- Check password modal -->
    <%= if @show_check_password_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center">
        <div class="bg-white p-6 rounded-lg w-[400px] shadow-lg">
          <h2 class="text-lg font-bold mb-4">Password</h2>

          <form phx-submit="check_lobby_password">
            <div class="space-y-3">
              <input
                type="text"
                name="password"
                placeholder="Lobby password"
                value={@check_password_form_data.password}
                class="w-full border rounded px-2 py-1"
              />
            </div>

            <div class="mt-5 flex justify-end gap-2">
              <button type="button" phx-click="close_check_lobby_password_modal" class="px-3 py-1 border rounded">
                Cancel
              </button>
              <button type="submit" class="px-3 py-1 bg-blue-600 text-white rounded">
                Submit
              </button>
            </div>
          </form>
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
        max when is_integer(max) -> length(lobby.players) < max
      end
    end)
  end

  defp filter_by_spectators(lobbies, false), do: lobbies
  defp filter_by_spectators(lobbies, true) do
    Enum.filter(lobbies, fn lobby ->
      case lobby.maxSpectators do
        nil -> true
        max when is_integer(max) -> length(lobby.spectators) < max
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
