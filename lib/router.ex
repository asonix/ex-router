defmodule Router do
  use Application

  def start(_type, _args) do
    Router.Supervisor.start_link
  end
end
