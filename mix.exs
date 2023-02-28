defmodule Uptight.MixProject do
  use Mix.Project

  def project do
    [
      app: :uptight,
      version: "0.2.11-rc",
      description:
        "Tools for tighter (more static) programming in Elixir with a particular focus on distinguishing types of binary data and pushing offensive programming capabilities to their limits.",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Uptight",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :jason]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:jason, "~> 1.3"},
      {:quark_goo, github: "doma-engineering/quark-goo", branch: "main"},
      {:algae_goo, github: "doma-engineering/algae-goo", branch: "main"},
      {:witchcraft_goo, github: "doma-engineering/witchcraft-goo", branch: "main"}
    ]
  end

  defp package do
    [
      licenses: ["WTFPL"],
      links: %{
        "GitHub" => "https://github.com/doma-engineering/uptight",
        "Support" => "https://social.doma.dev/@jonn",
        "Matrix" => "https://matrix.to/#/#uptight:matrix.org"
      },
      maintainers: ["doma.dev"]
    ]
  end
end
