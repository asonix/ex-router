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

defmodule Router.Manager.Routes do

  ## Routes API

  @doc """
  Starts a Routes agent.

  Routes agents contain a list of routes of a given state.
  """
  def start_link do
    cores = :erlang.system_info(:logical_processors_available)

    # Expect nodes in format [:name@location, :name2@location2, ...]
    nodes = Application.fetch_env!(:router, :routing_table)

    Agent.start_link(fn -> build_map(%{node => cores}, nodes) end)
  end

  @doc """
  Selects a route based on `id` and cores.
  """
  def select(routes, id) do
    Agent.get(routes, fn map ->
      map
      |> expand_routes
      |> select_route(id)
    end)
  end

  @doc """
  Send message to all nodes.
  """
  def broadcast(routes, mod, fun, args) do
    export(routes)
    |> Enum.each(fn {node_name, cores} ->
      Router.Routing.direct(node_name, mod, fun, args)
    end)
  end

  @doc """
  Returns the list of nodes from `routes`.
  """
  def export(routes) do
    Agent.get(routes, &(&1))
  end

  @doc """
  Imports a map of nodes and merges with local node map.
  """
  def import(routes, imports) do
    Agent.update(routes, fn map ->
      ins = Map.keys(map)

      imports
      |> Enum.filter(fn {node_name, _cores} ->
        not ((node_name in ins) or (node_name == node))
      end)
      |> Map.new
      |> Map.merge(map)
    end)
  end

  @doc """
  Adds a node_pair of the format `{node_name, cores}` to the `routes`.
  """
  def add_node(routes, {node_name, cores}) do
    Agent.update(routes, fn map ->
      Map.put(map, node_name, cores)
    end)
    routes
  end

  @doc """
  Removes a `node_pair` with name `name` from the `routes`.
  """
  def remove_node(routes, name) do
    Agent.update(routes, &Map.pop(&1, name))
    routes
  end

  @doc """
  Returns `true` if `node_name` is present in `routes`.
  """
  def send_if_new(routes, node_name) do
    Agent.update(routes, fn map ->
      if not Map.has_key?(map, node_name) do
        {:ok, cores} = Router.Routing.direct(node_name,
                                             Router.Manager,
                                             :import_nodes,
                                             [Router.Manager, export(routes)])
        Map.put(map, node_name, cores)
      else
        map
      end
    end)
    routes
  end

  ## Helpers

  # create the initial map that will be stored in the process
  defp build_map(map, []), do: map
  defp build_map(map, [current_node|rest]) do
    Map.add(map, current_node, get_cores(current_node)) |> build_map(rest)
  end

  # connect to and get number of cores from remote node
  defp get_cores(node_name) do
    Node.connect(node_name)
    Router.Routing.direct(node_name,
                          Router.Manager,
                          :cores,
                          [])
  end

  # expand_routes converts the routes list to an expanded form based on
  # the number of cores listed for each node
  defp expand_routes(map) do
    list = Map.keys(map)
    List.foldr(list, [], fn (node_name, acc) ->
      acc ++ expand_node(node_name, Map.get(map, node_name))
    end)
  end

  # expand_node converts `node_name`, `cores` to a list
  # containing a count of `cores` `node_name`s.
  defp expand_node(_, 0), do: []
  defp expand_node(node_name, cores) do
    [node_name] ++ expand_node({node_name, cores - 1})
  end

  # select_route returns the name of a node using a modulus on the `id`.
  defp select_route(list, id) do
    list |> Enum.fetch(rem(id, length(list))) |> elem(1)
  end
end
