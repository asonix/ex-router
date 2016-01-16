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

