defmodule OMG.DB.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg_db,
      version: version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :telemetry],
      start_phases: [{:attach_telemetry, []}],
      mod: {OMG.DB.Application, []}
    ]
  end

  defp version() do
    "git"
    |> System.cmd(["describe", "--tags", "--abbrev=0"])
    |> elem(0)
    |> String.replace("v", "")
    |> String.replace("\n", "")
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      {:rocksdb, "~> 1.6", system_env: [{"ERLANG_ROCKSDB_OPTS", "-DWITH_SYSTEM_ROCKSDB=ON -DPORTABLE=1 PORTABLE=1"}]},
      {:omg_status, in_umbrella: true},
      # NOTE: we only need in :dev and :test here, but we need in :prod too in performance
      #       then there's some unexpected behavior of mix that won't allow to mix these, see
      #       [here](https://elixirforum.com/t/mix-dependency-is-not-locked-error-when-building-with-edeliver/7069/3)
      #       OMG-373 (Elixir 1.8) should fix this
      # TEST ONLY
      {:briefly, "~> 0.3.0", only: [:dev, :test]},
      {:telemetry, "~> 0.4.1"},
      {:omg_utils, in_umbrella: true}
    ]
  end
end
