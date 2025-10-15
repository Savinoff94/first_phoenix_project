defmodule FirstAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :first_app,
    pubsub_server: FirstApp.PubSub
end
