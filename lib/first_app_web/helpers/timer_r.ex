defmodule FirstAppWeb.TimerWorker do
  use GenServer
  alias Phoenix.PubSub
  alias RPS.GameEngine

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    lobby_id = Keyword.fetch!(opts, :lobby_id)
    seconds = Keyword.get(opts, :seconds, 5)
    topic = "timer:#{lobby_id}"

    {:ok, %{seconds: seconds, topic: topic, lobby_id: lobby_id}}
  end

  def handle_info({:tick, n}, state) do
    PubSub.broadcast(FirstApp.PubSub, state.topic, {:tick, n})
    {:noreply, state}
  end

  def handle_info(:stop_timer, state) do
    PubSub.broadcast(FirstApp.PubSub, state.topic, {:timer_start_flag, false})
    # 👇 Notify correct GameEngine via dispatch
    GameEngine.dispatch(state.lobby_id, :round_timeout, %{lobby_id: state.lobby_id})
    {:stop, :normal, state}
  end
end
