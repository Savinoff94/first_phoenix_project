defmodule FirstAppWeb.RequireLobbyAccess do
  import Plug.Conn
  import Phoenix.Controller
  alias FirstAppWeb.LobbiesManager

  def init(opts), do: opts

  def call(conn, _opts) do
    user_login = get_session(conn, :login)
    lobby_id = conn.params["id"]
    case LobbiesManager.get(lobby_id) do
      nil ->
        conn
        |> redirect(to: "/")
        |> halt()

      %{approvedList: list} = _lobby ->
        if user_login in list do
          conn
        else
          conn
          |> redirect(to: "/")
          |> halt()
        end
    end
  end
end
