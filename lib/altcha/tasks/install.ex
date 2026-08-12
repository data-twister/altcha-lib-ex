defmodule Mix.Tasks.Altcha.Install do
  @moduledoc """
  Installs Altcha packages.

  Usage:
      mix Altcha.install [OPTIONS]

  Options:
      --version <version>   Specify the version to install. If not provided, installs the latest version.
      --help                Show this help message.
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, switches: [version: :string, help: :boolean])

    if opts[:help] do
      IO.puts(@moduledoc)
    else
      Altcha.Installer.install(opts)
    end
  end
end
