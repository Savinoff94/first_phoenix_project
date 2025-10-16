defmodule FirstAppWeb.TimerWorker do
  use GenServer
  alias Phoenix.PubSub

  # ===============================
  # PUBLIC API
  # ===============================

  @doc """
  Starts a timer process linked to its caller.
  Options:
    - :lobby_id (required)
    - :seconds (default 5)
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # ===============================
  # CALLBACKS
  # ===============================

  def init(opts) do
    lobby_id = Keyword.fetch!(opts, :lobby_id)
    seconds = Keyword.get(opts, :seconds, 5)
    topicShow = "lobby:#{lobby_id}"
    topicLobbyServer = "timer:#{lobby_id}"

    # Notify LiveView: flag:true
    PubSub.broadcast(FirstApp.PubSub, topicShow, {:timer_flag, true})

    # Schedule periodic ticks
    Enum.each(1..seconds, fn i ->
      Process.send_after(self(), {:tick, i}, i * 1000)
    end)

    # Schedule final stop flag
    Process.send_after(self(), :stop_timer, (seconds + 1) * 1000)

    {:ok, %{topicShow: topicShow, seconds: seconds, topicLobbyServer: topicLobbyServer}}
  end

  def handle_info({:tick, n}, state) do
    PubSub.broadcast(FirstApp.PubSub, state.topicShow, {:tick, n})
    {:noreply, state}
  end

  def handle_info(:stop_timer, state) do
    PubSub.broadcast(FirstApp.PubSub, state.topicShow, {:timer_flag, false})
    PubSub.broadcast(FirstApp.PubSub, state.topicLobbyServer, {:timer_flag, false})
    {:stop, :normal, state}
  end
end
