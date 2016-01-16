defmodule Router.Manager.Routes do

  ## Routes API

  @doc """
  Starts a Routes agent.

  Routes agents contain a list of routes of a given state.
  """
  def start_link do
    cores = :erlang.system_info(:logical_processors_available)
    current_node = {node, cores}
    nodes = Application.fetch_env!(:router, :routing_table)

    Agent.start_link(fn -> (nodes -- [current_node]) ++ [current_node] end)
  end

  @doc """
  Selects a route based on `id` and cores.
  """
  def select(routes, id) do
    Agent.get(routes, fn list ->
      list
      |> expand_routes
      |> select_route(id)
    end)
  end

  @doc """
  Returns the list of nodes from `routes`..
  """
  def export(routes) do
    Agent.get(routes, &(&1))
  end

  @doc """
  Imports a list of nodes.
  """
  def import(routes, imports) do
    Agent.update(routes, fn list ->
      ins = unzip(list)
      Enum.filter(imports, fn {node_name, _cores} ->
        (not node_name in ins) and (not (node_name == node))
      end) ++ list
    end)
  end

  @doc """
  Adds a `node_pair` of the format {name, cores} to the `routes`.
  """
  def add_node(routes, node_pair, parent) do
    Agent.update(routes, fn list ->
      {status, nlist} = insert_node(list, node_pair)
      if status == :new do
        send(parent, {:new, node_pair, self()})
      end
      nlist
    end)
  end

  @doc """
  Removes a `node_pair` with name `name` from the `routes`.
  """
  def remove_node(routes, name) do
    Agent.update(routes, &(filter_node_from_list(&1, name)))
  end

  @doc """
  Returns `true` if `node_name` is present in `routes`.
  """
  def find(routes, name) do
    Agent.get(routes, &(node_exists(&1, name)))
  end

  ## Helpers

  # expand_routes converts the routes list to an expanded form based on
  # the number of cores listed for each node
  defp expand_routes(list) do
    List.foldr(list, [], fn (node_pair, acc) ->
      acc ++ expand_node(node_pair)
    end)
  end

  # expand_node converts a tuple of {`node_name`, `cores`} to a list
  # containing a count of `cores` `node_name`s.
  defp expand_node({_, 0}), do: []
  defp expand_node({node_name, cores}) do
    [node_name] ++ expand_node({node_name, cores - 1})
  end

  # select_route returns the name of a node using a modulus on the `id`.
  defp select_route(list, id) do
    list |> Enum.fetch(rem(id, length(list))) |> elem(1)
  end

  # Returns a list of node names from the `routes`.
  defp unzip(list) do
    Enum.map(list, fn {node_name, _cores} -> node_name end)
  end

  # Replaces or inserts a node.
  defp insert_node([], new_node), do: {:new, [new_node]}
  defp insert_node([current_node|rest], {name, _cores} = new_node) do
    case current_node do
      {^name, _} ->
        {:ok, [new_node|rest]}
      _ ->
        {status, list} = insert_node(rest, new_node)
        {status, [current_node|list]}
    end
  end

  # node_exists returns whether or not a node exists in this routes list.
  defp node_exists(list, name) do
    nil != Enum.find(list, fn {node_name, _cores} ->
      name == node_name
    end)
  end

  # removes node from list if node exists
  defp filter_node_from_list(list, name) do
    Enum.filter(list, fn {node_name, _cores} ->
      name != node_name
    end)
  end
end
