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
