defmodule FirstAppWeb.LoginLive do
  use Phoenix.LiveView
  alias FirstAppWeb.Players
  def mount(_params, _session, socket) do
    {:ok, assign(socket, login: "", error: nil, can_submit?: false)}
  end

  # -----------------------------
  # HANDLE EVENTS
  # -----------------------------

  # Update login
  def handle_event("update_login", %{"login" => login}, socket) do
    login = String.trim(login)

    exists? = Players.player_exists?(login)

    error =
      cond do
        exists? -> "This name is already taken"
        true -> nil
      end

    can_submit? = login != "" and error == nil

    {:noreply,
     assign(socket,
      login: login,
      error: error,
      can_submit?: can_submit?
    )}
  end

  # Submit login form
  def handle_event("submit_login", %{"login" => login}, socket) do
    {:noreply,
    socket
    |> assign(login: login, error: nil)
    |> push_event("store_login", %{login: login})}
  end

  # Reset login form
  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, login: "", error: nil)}
  end

  def render(assigns) do
    ~H"""
    <form
      id="login-form-live"
      phx-change="update_login"
      phx-submit="submit_login"
      phx-hook="LoginStorage"
    >
      <input
        type="text"
        name="login"
        phx-debounce="500"
        value={@login}
        placeholder="Enter your login"
        class="border rounded px-3 py-2 w-full text-center"
      />

      <p class="mt-4 text-lg text-green-700 font-medium"><%= @error %></p>

      <button
        type="submit"
        disabled={!@can_submit?}
        class={[
          "mt-3 px-4 py-2 rounded text-white",
          @can_submit? && "bg-blue-500 hover:bg-blue-600",
          !@can_submit? && "bg-gray-400 cursor-not-allowed opacity-60"
        ]}
      >
        Submit
      </button>
      <button
        phx-click="reset"
        type="button"
        class="mt-3 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
      >
        Reset
      </button>

    </form>
    """
  end
end
