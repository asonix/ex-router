# Router

An elixir package to select routes to nodes based on availability and number of cores.

Outline:
 -  UP process: Keeps list of up nodes
 -  DOWN process: Keeps a list of down nodes
 -  MANAGER process: Responds to queries about this node's state, can add new nodes to UP when encountered
 -  TIMER process: Frequently asks UP and DOWN to reevaluate their lists

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add router to your list of dependencies in `mix.exs`:

        def deps do
          [{:router, "~> 0.0.1"}]
        end

  2. Ensure router is started before your application:

        def application do
          [applications: [:router]]
        end

## License
EX Router is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EX Router is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
This file is part of EX Router.

You should have received a copy of the GNU General Public License
along with EX Router.  If not, see <http://www.gnu.org/licenses/>.
