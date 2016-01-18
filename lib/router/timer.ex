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

defmodule Router.Timer do
  use GenServer

  ## API

  @doc """
  Starts timer process.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  ## Server Callbacks

  @doc """
  Creates timer process.
  """
  def init(:ok) do
    state = %{}
    start_timer(state)
    {:ok, state}
  end

  @doc """
  Handles `:tick` events. Updates Routes. Starts another timer.
  """
  def handle_info({:tick, _state}, state) do
    start_timer(state)

    # This is something I'd want to move to a more global position
    cores = :erlang.system_info(:logical_processors_available)

    Router.Manager.get_all_nodes(Router.Manager)
    |> Enum.each(fn {node_name, cores} ->
      state = Router.Routing.direct(node_name,
                                    Router.Manager,
                                    :check_state,
                                    [Router.Manager, node, cores])
      Router.Manager.update_node(Router.Manager, node_name, cores, state)
    end)

    {:noreply, state}
  end

  @doc """
  Ignores unimportant messages.
  """
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Helpers

  # Sends `:tick` to the `Router.Timer` after a second.
  defp start_timer(state) do
    Process.send_after(self(), {:tick, state}, 1000)
  end

end
