defmodule Router.Routing do
  @doc """
  Dispatch the given `mod`, `fun`, `args` request
  to the appropriate node based on the `id`.
  """
  def route(id, mod, fun, args) do
    node_name = Router.Manager.get_route(Router.Manager, id)

    direct(node_name, mod, fun, args, true, id)
  end

  @doc """
  Execute command on local machine if conditions are good.
  """
  def exec(id, mod, fun, args) do
    if Router.Manager.check_state(Router.Manager) == :up do
      apply(mod, fun, args)
    else
      route(id, mod, fun, args)
    end
    # if load isn't high do
    #   apply(mod, fun, args)
    # else
    #   {Router.Tasks, elem(entry, 1)}
    #   |> Task.Superrvisor.async(Router, :exec, [id, mod, fun, args])
    #   |> Task.await()
    # end
  end

  @doc """
  Specify a node to execute a command on.
  """
  def direct(node_name, mod, fun, args, retry \\ false,id \\ 0) do
    require Logger
    if node_name == node do
      apply(mod, fun, args)
    else
      try do
        {Router.Tasks, node_name}
        |> Task.Supervisor.async(Router.Routing, :exec, [id, mod, fun, args])
        |> Task.await()
      catch
        :exit, {{:nodedown, _}, _} ->
          if retry do
            route(id + 1, mod, fun, args)
          else
            :down
          end
      end
    end
  end
end
