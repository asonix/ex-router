# This file is part of EX Router.

# EX Router is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# EX Router is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with EX Router.  If not, see <http://www.gnu.org/licenses/>.

defmodule Router.Manager do
  use GenServer

  ## Misc

  def cores() do
    :erlang.system_info(:logical_processors_available)
  end

  ## API

  @doc """
  Starts the Routes Manager.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @doc """
  Pings the GenServer, reponds `:up` or `:down`
  """
  def ping(manager) do
    require Logger
    try do
      {:pong} = GenServer.call(manager, {:ping})
      :up
    catch
      _ ->
        :down
    end
  end

  @doc """
  Checks the state of the current node.

  result is either `:up` or `:down`.
  """
  def check_state(manager) do
    GenServer.call(manager, {:state})
  end

  @doc """
  Imports nodes from list.
  """
  def import_nodes(manager, map) do
    GenServer.cast(manager, {:import, map})
    {:ok, cores()}
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
  def get_nodes(manager) do
    GenServer.call(manager, {:nodes})
  end

  @doc """
  States whether a node is offline or online.
  """
  def update_node(manager, node_name, state) do
    GenServer.cast(manager, {:node_state, state, node_name})
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
  Initialize the Genserver with a map of routes pid
  and the current state
  """
  def init(:ok) do
    {:ok, pid} = Routes.Supervisor.start_routes()
    monitor = Process.monitor(good)

    {:ok, %{pid: pid, state: :up, monitor: monitor}}
  end

  def handle_call({:ping}, _from, manager) do
    {:reply, {:pong}, manager}
  end

  @doc """
  If calling node is not in routes process, put it there.

  returns `:up` or `:down`.
  """
  def handle_call({:state}, _from, manager) do
    {:reply, Map.get(manager, :state), manager}
  end

  @doc """
  Returns name of route that is up.
  """
  def handle_call({:route, id}, _from, manager) do
    {:reply, Routes.select(Map.get(manager, :pid), id), manager}
  end

  @doc """
  Returns all nodes.
  """
  def handle_call({:nodes}, _from, manager) do
    {:reply, nodes(manager), manager}
  end

  @doc """
  Sets the state of the current node.
  """
  def handle_cast({:state, state}, manager) do
    Map.get(manager, :pid)
    |> Routes.broadcast(Router.Manager,
                        :update_node,
                        [Router.Manager, node(), state])
    {:noreply, Map.put(manager, :state, state)}
  end

  @doc """
  Imports nodes from map.
  """
  def handle_cast({:import, map}, manager) do
    Map.get(manager, :pid) |> Routes.import(map)
    {:noreply, manager}
  end

  @doc """
  Sets the perceived state of another node.
  """
  def handle_cast({:node_state, state, node_name, cores}, manager) do
    case state do
      :up -> node_is_up(manager, node_name)
      :down -> node_is_down(manager, node_name)
    end

    {:noreply, manager}
  end

  @doc """
  Restarts the routes if they go down.
  """
  def handle_info({:DOWN, ref, :process, _pid, _reason}, manager) do
    if ref == Map.get(manager, :monitor) do
      {:ok, pid} = Routes.Supervisor.start_routes()
      monitor = Process.monitor(pid)
      umanager = manager |> Map.put(:pid, pid) |> Map.put(:monitor, monitor)
      {:noreply, umanager}
    else
      {:noreply, manager}
    end
  end

  @doc """
  Does nothing on unimportant handle_info calls.
  """
  def handle_info(_msg, routes) do
    {:noreply, routes}
  end

  ## Helpers

  defp nodes(manager) do
    Map.get(manager, :pid)
    |> Routes.export()
  end

  defp node_is_up(manager, node_name) do
    Map.get(manager, :pid)
    |> Routes.send_if_new(node_name)
    |> Routes.add_node({node_name})
  end

  defp node_is_down(manager, node_name) do
    Map.get(manager, :pid)
    |> Routes.remove_node(node_name)
  end
end
