defmodule FirstAppWeb.SessionController do
  use FirstAppWeb, :controller
  alias FirstAppWeb.Players

  def sync(conn, %{"login" => login}) do
    if String.trim(login) == "" do
      send_resp(conn, 400, "invalid login")
    else
      conn = put_session(conn, :login, login)

      Players.add_player(login)
      IO.inspect(Players.all_players(), label: "Current players")

      send_resp(conn, 204, "")
    end
  end
end
