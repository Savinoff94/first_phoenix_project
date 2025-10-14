defmodule FirstAppWeb.Players do
  use GenServer
  alias Phoenix.PubSub
  @pubsub_topic "players"
  @initial_state []
  #Client API

  # Start the GenServer
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, @initial_state, name: __MODULE__)
  end

  def all_players do
    GenServer.call(__MODULE__, :all_players)
  end

  def player_exists?(login) do
    GenServer.call(__MODULE__, {:player_exists?, login})
  end

  def sorted_by_score do
    GenServer.call(__MODULE__, :sorted_by_score)
  end

  def add_player(login) do
    GenServer.cast(__MODULE__, {:add_player, login})
    PubSub.broadcast(FirstApp.PubSub, @pubsub_topic, {:player_added, login})
  end

  def update_score(login) do
    GenServer.cast(__MODULE__, {:update_score, login})
    PubSub.broadcast(FirstApp.PubSub, @pubsub_topic, {:score_updated, login})
  end

  def delete_player(login) do
    GenServer.cast(__MODULE__, {:delete_player, login})
    PubSub.broadcast(FirstApp.PubSub, @pubsub_topic, {:player_deleted, login})
  end

  # Subscribe to PubSub notifications
  def subscribe do
    PubSub.subscribe(FirstApp.PubSub, @pubsub_topic)
  end

  # Server callbacks


  def init(_) do
    {:ok, @initial_state}
  end

  @impl true
  def handle_call(:all_players, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:player_exists?, login}, _from, state) do
    exists? =
      Enum.any?(state, fn p -> p.login == login end)

    {:reply, exists?, state}
  end

  @impl true
  def handle_call(:sorted_by_score, _from, state) do
    sorted = Enum.sort_by(state, & &1.score, :desc)
    {:reply, sorted, state}
  end

  @impl true
  def handle_cast({:add_player, login}, state) do
    new_player = %{login: login, score: 0}
    {:noreply, [new_player | state]}
  end

  @impl true
  def handle_cast({:update_score, login}, state) do
    new_state =
      Enum.map(state, fn
        %{login: ^login, score: score} = p -> %{p | score: score + 1}
        p -> p
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:delete_player, login}, state) do
    new_state = Enum.reject(state, fn p -> p.login == login end)
    {:noreply, new_state}
  end

end
