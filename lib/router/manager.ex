defmodule Router.Manager do
  use GenServer

  ## API

  @doc """
  Starts the Routes Manager.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @doc """
  Checks the state of the current node.

  result is either `:up` or `:down`.
  """
  def check_state(manager) do
    cores = :erlang.system_info(:logical_processors_available)
    GenServer.call(manager, {:state, node, cores})
  end
  def check_state(manager, node_name, cores) do
    GenServer.call(manager, {:state, node_name, cores})
  end

  @doc """
  Returns the name of a node that is routable.
  """
  def get_route(manager, id) do
    GenServer.call(manager, {:route, id})
  end

  @doc """
  Returns list of all nodes.
  """
  def get_all_nodes(manager) do
    GenServer.call(manager, {:all_nodes})
  end

  @doc """
  States whether a node is offline or online.
  """
  def update_node(manager, node_name, cores, state) do
    GenServer.cast(manager, {:node_state, state, node_name, cores})
  end

  @doc """
  Set state as `:down`.
  """
  def state_down(manager) do
    GenServer.cast(manager, {:state, :down})
  end

  @doc """
  Set state as `:up`.
  """
  def state_up(manager) do
    GenServer.cast(manager, {:state, :up})
  end

  ## Server Callbacks

  # Alias Routes so we don't have a mess in our code
  alias Router.Manager.Routes

  @doc """
  Initialize the Genserver with a map of good, bad,
  and the current state
  """
  def init(:ok) do
    {:ok, good} = Routes.Supervisor.start_routes()
    {:ok, bad}  = Routes.Supervisor.start_routes()
    gr = Process.monitor(good)
    br = Process.monitor(bad)

    {:ok, %{good: good, bad: bad, state: :up, gref: gr, bref: br}}
  end

  @doc """
  If calling node is not in `:good`, put it there.

  returns `:up` or `:down`.
  """
  def handle_call({:state, node_name, cores}, _from, routes) do
    node_is_up(routes, node_name, cores)

    {:reply, Map.get(routes, :state), routes}
  end

  @doc """
  Returns name of route that is up.
  """
  def handle_call({:route, id}, _from, routes) do
    {:reply, Routes.select(Map.get(routes, :good), id), routes}
  end

  @doc """
  Returns all nodes.
  """
  def handle_call({:all_nodes}, _from, routes) do
    {:reply, Routes.export(Map.get(routes, :good))
             ++ Routes.export(Map.get(routes, :bad)), routes}
  end

  @doc """
  Sets the state of the current node.
  """
  def handle_cast({:state, state}, routes) do
    {:noreply, Map.put(routes, :state, state)}
  end

  @doc """
  Sets the perceived state of another node.
  """
  def handle_cast({:node_state, state, node_name, cores}, routes) do
    case state do
      :up -> node_is_up(routes, node_name, cores)
      :down -> node_is_down(routes, node_name, cores)
    end

    {:noreply, routes}
  end

  @doc """
  Restarts the routes if they go down.
  """
  def handle_info({:DOWN, ref, :process, _pid, _reason}, routes) do
    cond do
      ref == Map.get(routes, :gref) ->
        good = Routes.Supervisor.start_routes
        gr = Process.monitor(good)
        uroutes = Map.put(routes, :good, good)
        {:noreply, Map.put(uroutes, :gref, gr)}
      ref == Map.get(routes, :bref) ->
        bad = Routes.Supervisor.start_routes
        br = Process.monitor(bad)
        uroutes = Map.put(routes, :bad, bad)
        {:noreply, Map.put(uroutes, :bref, br)}
      true ->
        {:noreply, routes}
    end
  end

  @doc """
  Does nothing on unimportant handle_info calls.
  """
  def handle_info(_msg, routes) do
    {:noreply, routes}
  end

  ## Helpers

  defp node_is_up(routes, node_name, cores) do
    Routes.remove_node(Map.get(routes, :bad), node_name)
    Routes.add_node(Map.get(routes, :good), {node_name, cores})
  end

  defp node_is_down(routes, node_name, cores) do
    Routes.remove_node(Map.get(routes, :good), node_name)
    Routes.add_node(Map.get(routes, :bad), {node_name, cores})
  end
end
