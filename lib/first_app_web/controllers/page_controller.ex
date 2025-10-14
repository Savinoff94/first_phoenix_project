defmodule FirstAppWeb.PageController do
  use FirstAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
