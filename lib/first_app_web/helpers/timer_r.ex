defmodule FirstAppWeb.TimerWorker do
  use GenServer
  alias Phoenix.PubSub
  alias RPS.GameEngine

  # -----------------------------
  #  PUBLIC API
  # -----------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:lobby_id]))
  end

  def via_tuple(lobby_id), do: {:via, Registry, {FirstAppWeb.TimerRegistry, lobby_id}}

  # Start timer (seconds + optional callback pid)
  def start_timer(lobby_id, seconds \\ 5, timer_end_action) do
    GenServer.cast(via_tuple(lobby_id), {:start_timer, seconds, timer_end_action})
  end

  def stop_timer(lobby_id) do
    GenServer.cast(via_tuple(lobby_id), :stop_timer)
  end

  # -----------------------------
  #  CALLBACKS
  # -----------------------------

  def init(opts) do
    lobby_id = Keyword.fetch!(opts, :lobby_id)
    topic = "timer:#{lobby_id}"

    {:ok, %{seconds: 0, topic: topic, lobby_id: lobby_id, ref: nil, timer_end_action: nil}}
  end

  # Start the timer
  def handle_cast({:start_timer, seconds, timer_end_action}, state) do
    if state.ref, do: Process.cancel_timer(state.ref)

    PubSub.broadcast(FirstApp.PubSub, state.topic, {:timer_start_flag, true, timer_end_action})
    ref = Process.send_after(self(), :tick, 1000)

    {:noreply, %{state | seconds: seconds, ref: ref, timer_end_action: timer_end_action}}
  end

  # Stop manually
  def handle_cast(:stop_timer, state) do
    if state.ref, do: Process.cancel_timer(state.ref)
    PubSub.broadcast(FirstApp.PubSub, state.topic, {:timer_start_flag, false, state.timer_end_action})
    {:noreply, %{state | ref: nil}}
  end

  # Regular tick
  def handle_info(:tick, %{seconds: seconds} = state) when seconds > 0 do
    PubSub.broadcast(FirstApp.PubSub, state.topic, {:tick, seconds})
    ref = Process.send_after(self(), :tick, 1000)
    {:noreply, %{state | seconds: seconds - 1, ref: ref}}
  end

  # Timer finished
  def handle_info(:tick, %{seconds: 0, timer_end_action: timer_end_action} = state) do
    PubSub.broadcast(FirstApp.PubSub, state.topic, {:tick, 0})
    PubSub.broadcast(FirstApp.PubSub, state.topic, {:timer_finished, state.lobby_id})
    PubSub.broadcast(FirstApp.PubSub, state.topic, {:timer_start_flag, false, timer_end_action})

    # Notify GameEngine
    GameEngine.dispatch(state.lobby_id, timer_end_action, %{lobby_id: state.lobby_id})

    {:noreply, %{state | ref: nil}}
  end
end
