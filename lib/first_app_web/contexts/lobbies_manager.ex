defmodule FirstAppWeb.LobbiesManager do
  use GenServer
  alias FirstAppWeb.{LobbyServer, LobbySupervisor}
  alias Phoenix.PubSub
  @topic "lobbies"

  ## Public API
  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def create(attrs), do: GenServer.call(__MODULE__, {:create, attrs})
  def all, do: GenServer.call(__MODULE__, :all)
  def get(id), do: GenServer.call(__MODULE__, {:get, id})
  def remove(id), do: GenServer.call(__MODULE__, {:remove, id})

  def subscribe_to_updates do
    PubSub.subscribe(FirstApp.PubSub, @topic)
  end

  def check_password_and_approve(lobby_id, input_password, user_login) do
    GenServer.call(__MODULE__, {:check_password, lobby_id, input_password, user_login})
  end

  ## Callbacks
  def init(state), do: {:ok, state}

  def handle_call(:all, _from, state), do: {:reply, Map.values(state), state}

  def handle_call({:create, attrs}, _from, state) do
    id = Integer.to_string(System.unique_integer([:positive]))

    base = %{
      id: id,
      name: "Unnamed",
      password: nil,
      players: [],
      spectators: [],
      maxPlayers: nil,
      maxSpectators: nil,
      approvedList: []
    }

    lobby = Map.merge(base, attrs)

    {:ok, _pid} = DynamicSupervisor.start_child(FirstAppWeb.LobbySupervisor, {FirstAppWeb.LobbyServer, lobby})
    PubSub.broadcast(FirstApp.PubSub, @topic, {:lobby_created, lobby})

    {:reply, {:ok, lobby}, Map.put(state, id, lobby)}
  end

  def handle_call({:get, id}, _from, state) do
    {:reply, Map.get(state, id), state}
  end

  def handle_call({:remove, id}, _from, state) do
    DynamicSupervisor.terminate_child(LobbySupervisor, pid_from_registry(id))
    PubSub.broadcast(FirstApp.PubSub, @topic, {:lobby_removed, id})
    {:reply, :ok, Map.delete(state, id)}
  end

  def handle_call({:check_password, lobby_id, input_password, user_login}, _from, state) do
    case Map.get(state, lobby_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      lobby ->
        if lobby.password == input_password do
          updated_lobby =
            Map.update(lobby, :approvedList, [user_login], fn list ->
              [user_login | list] |> Enum.uniq()
            end)

          new_state = Map.put(state, lobby_id, updated_lobby)
          {:reply, {:ok, updated_lobby}, new_state}
        else
          {:reply, {:error, :wrong_password}, state}
        end
    end
  end

  ## Helper
  defp pid_from_registry(id) do
    [{pid, _value}] = Registry.lookup(FirstAppWeb.LobbyRegistry, id)
    pid
  end

end
