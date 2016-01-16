defmodule Router.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      supervisor(Router.Manager.Routes.Supervisor, []),
      worker(Router.Manager, [Router.Manager]),
      worker(Router.Timer, [Router.Timer]),
      supervisor(Task.Supervisor, [[name: Router.Tasks]])
    ]

    supervise(children, strategy: :rest_for_one)
  end
end
