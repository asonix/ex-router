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

  ## API

  @doc """
  Starts the Routes Manager.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def ping(manager) do
    require Logger
    try do
      {:pong} = GenServer.call(manager, {:ping})
      :up
    catch
      reason ->
        Logger.info "Reason: #{reason}"
        :down
    end
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
  Imports nodes from list.
  """
  def import_nodes(manager, list) do
    GenServer.cast(manager, {:import, list})
    {:ok, true}
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

  def handle_call({:ping}, _from, routes) do
    {:reply, {:pong}, routes}
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
    {:reply, all_nodes(routes), routes}
  end

  @doc """
  Sets the state of the current node.
  """
  def handle_cast({:state, state}, routes) do
    {:noreply, Map.put(routes, :state, state)}
  end

  @doc """
  Imports nodes from list.
  """
  def handle_cast({:import, list}, routes) do
    Map.get(routes, :bad) |> Routes.import(list)
    {:noreply, routes}
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
  Sends new node current node info.
  """
  def handle_info({:new, {node_name, _cores}, pid}, routes) do
    if pid == Map.get(routes, :good) do
      if (length good_nodes(routes)) > 2 do
        Router.Routing.direct(node_name, Router.Manager, :import_nodes,
                              [Router.Manager, all_nodes(routes)])
      end
    end
    {:noreply, routes}
  end

  @doc """
  Does nothing on unimportant handle_info calls.
  """
  def handle_info(_msg, routes) do
    {:noreply, routes}
  end

  ## Helpers

  defp all_nodes(routes) do
    good_nodes(routes) ++ bad_nodes(routes)
  end

  defp good_nodes(routes) do
    Routes.export(Map.get(routes, :good))
  end

  defp bad_nodes(routes) do
    Routes.export(Map.get(routes, :bad))
  end

  defp node_is_up(routes, node_name, cores) do
    Routes.remove_node(Map.get(routes, :bad), node_name)
    Routes.add_node(Map.get(routes, :good), {node_name, cores}, self())
  end

  defp node_is_down(routes, node_name, cores) do
    Routes.remove_node(Map.get(routes, :good), node_name)
    Routes.add_node(Map.get(routes, :bad), {node_name, cores}, self())
  end
end
