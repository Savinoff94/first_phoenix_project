defmodule FirstAppWeb.Router do
  use FirstAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FirstAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :protected do
    plug FirstAppWeb.RequireLogin
  end

  pipeline :require_lobby_access do
    plug FirstAppWeb.RequireLobbyAccess
  end

  scope "/", FirstAppWeb do
    pipe_through :browser

    live "/", LoginLive
    post "/sync", SessionController, :sync

  end
  scope "/", FirstAppWeb do
    pipe_through [:browser, :protected]
    live "/lobby", LobbyLive.Index
  end

  scope "/", FirstAppWeb do
    pipe_through [:browser, :protected, :require_lobby_access]
    live "/lobby/:id", LobbyLive.Show
  end

  # Other scopes may use custom stacks.
  # scope "/api", FirstAppWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:first_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FirstAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
