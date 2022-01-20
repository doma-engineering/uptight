defmodule Uptight.MixProject do
  use Mix.Project

  def project do
    [
      app: :uptight,
      version: "0.1.0",
      description:
        "Tools for tighter (more static) programming in Elixir with a particular focus on distinguishing types of binary data and pushing offensive programming capabilities to their limits.",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Uptight",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1.0", [runtime: false]},
      {:doma_witchcraft, "~> 1.0.4-doma"},
      {:doma_algae, "~> 1.3.1-doma"},
      {:doma_quark, "~> 2.3.2-doma2"}
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
