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

defmodule Router.Manager.Routes.Supervisor do
  use Supervisor

  # A simple module attribute that stores the supervisor name
  @name Router.Manager.Routes.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def start_routes do
    Supervisor.start_child(@name, [])
  end

  def init(:ok) do
    children = [
      worker(Router.Manager.Routes, [])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
