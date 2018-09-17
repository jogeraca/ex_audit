defmodule ExAudit.Mixfile do
  use Mix.Project

  def project do
    [
      description: "Ecto auditing library that transparently tracks changes and can revert them",
      app: :ex_audit,
      version: "0.4.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      source_url: "https://github.com/zenneriot/ex_audit",
      package: [
        licenses: ["MIT"],
        maintainers: ["Moritz Schmale <ms@zenner-iot.com>"],
        links: %{
          "GitHub" => "https://github.com/zenneriot/ex_audit",
          "Documentation" => "https://hexdocs.pm/ex_audit"
        }
      ],
      docs: [
        main: "ExAudit",
        extras: ["README.md"]
      ]
    ]
  end

  def paths(:test) do
    paths(:default) ++ ["./example"]
  end

  def paths(:default) do
    ["./lib"]
  end

  def paths(_), do: paths(:default)

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExAudit, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 2.1"},
      {:postgrex, "~> 0.13.3", only: :test},
      {:excoveralls, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.16", runtime: false, only: :dev},
      {:poison, "~> 3.0"}
    ]
  end
end
