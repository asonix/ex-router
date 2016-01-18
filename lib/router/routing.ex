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
  def direct(node_name, mod, fun, args, retry \\ false, id \\ 0) do
    require Logger
    if node_name == node do
      apply(mod, fun, args)
    else
      try do
        {Router.Tasks, node_name}
        |> Task.Supervisor.async(Router.Routing, :exec, [id, mod, fun, args])
        |> Task.await()
      catch
        :exit, {{:nodedown, _}, _} -> Logger.info "Exit: nodedown"
        :exit, {:timeout, _} -> Logger.info "Exit: timeout"
        :exit, {:noproc, _} -> Logger.info "Exit: noproc"
        :exit, {{reason, _}, _} -> Logger.info "Exit: #{reason}"
        :exit, other -> Logger.info "Exit: #{other}"
        status, {{reason, _}, _} -> Logger.info "Other: #{status}: #{reason}"
      end
      retry_send(mod, fun, args, retry, id)
    end
  end

  # Return :down if retry is false
  defp retry_send(mod, fun, args, retry, id) do
    if retry do
      route(id + 1, mod, fun, args)
    else
      :down
    end
  end
end
