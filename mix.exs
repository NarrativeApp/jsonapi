defmodule JSONAPI.Mixfile do
  use Mix.Project

  @version "1.4.0"

  def project do
    [
      app: :jsonapi,
      version: @version,
      package: package(),
      compilers: compilers(Mix.env()),
      description: description(),
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/jeregrine/jsonapi",
      deps: deps(),
      dialyzer: dialyzer(),
      docs: [
        extras: [
          "README.md"
        ],
        main: "readme"
      ]
    ]
  end

  defp compilers(_), do: Mix.compilers()

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp dialyzer do
    [
      plt_add_deps: :app_tree
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.10"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.20", only: ~w[dev test]a},
      {:earmark, ">= 0.0.0", only: :dev},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.3", only: :test},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.2", only: ~w[dev test]a}
    ]
  end

  defp package do
    [
      maintainers: [
        "Jason Stiebs",
        "Mitchell Henke",
        "Jake Robers",
        "Sean Callan",
        "James Herdman"
      ],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jeregrine/jsonapi", docs: "http://hexdocs.pm/jsonapi/"}
    ]
  end

  defp description do
    """
    Fully functional JSONAPI V1 Serializer as well as a QueryParser for Plug based projects and applications.
    """
  end
end
