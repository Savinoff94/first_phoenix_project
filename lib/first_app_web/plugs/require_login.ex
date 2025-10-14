defmodule FirstAppWeb.RequireLogin do
  import Plug.Conn
  import Phoenix.Controller
  alias FirstAppWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :login) do
      nil ->
        conn
        |> redirect(to: "/")
        |> halt()
      _login ->
        conn
    end
  end
end
