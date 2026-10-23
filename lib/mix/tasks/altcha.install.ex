# lib/mix/tasks/altcha.install.ex
defmodule Mix.Tasks.Altcha.Install do
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [version: :string])
    
    # Delegates cleanly to your module
    Altcha.Installer.install(opts) 
  end
end
