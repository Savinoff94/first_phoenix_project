defmodule FirstAppWeb.LoginLive do
  use Phoenix.LiveView
  alias FirstAppWeb.Players
  import FirstAppWeb.CoreComponents
  def mount(_params, _session, socket) do
    {:ok, assign(socket, login: "", error: nil, can_submit?: false)}
  end

  # -----------------------------
  # HANDLE EVENTS
  # -----------------------------

  # Update login
  def handle_event("update_login", %{"login" => login}, socket) do
    %{login: login, error: error, can_submit?: can_submit?} = validate_login(login)
    {:noreply, assign(socket, login: login, error: error, can_submit?: can_submit?)}
  end

  # Submit login form
  def handle_event("submit_login", %{"login" => login}, socket) do
    %{login: login, error: error, can_submit?: can_submit?} = validate_login(login)

    if error do
      {:noreply, assign(socket, error: error, can_submit?: can_submit?)}
    else
      {:noreply,
       socket
       |> assign(login: login, error: nil, can_submit?: can_submit?)
       |> push_event("store_login", %{login: login})}
    end
  end

  # Reset login form
  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, login: "", error: nil)}
  end

  defp validate_login(login) do
    login = String.trim(login)
    exists? = Players.player_exists?(login)
    error = if exists?, do: "This name is already taken"

    can_submit? = login != "" and error == nil

    %{login: login, error: error, can_submit?: can_submit?}
  end

  def render(assigns) do
    ~H"""
    <div
      class="h-screen flex flex-col items-center gap-10 justify-center items-center"
    >
    <h1 class="text-4xl font-extrabold text-center tracking-tight drop-shadow-sm">
      RCP Battle
    </h1>
      <.form
        for={%{}}
        id="login-form-live"
        phx-change="update_login"
        phx-submit="submit_login"
        phx-hook="LoginStorage"
      >
        <.input
          name="login"
          type="text"
          label="Login"
          value={@login}
          errors={if is_nil(@error), do: [], else: [@error]}
          phx-debounce="500"
          placeholder="Enter your login"
        />

        <div class="flex w-full justify-center gap-3 mt-4">
          <.button variant="primary" type="submit" disabled={!@can_submit?}>
            Submit
          </.button>

          <.button
            type="button"
            phx-click="reset"
            variant="secondary"
          >
            Reset
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
