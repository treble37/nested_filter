defmodule NestedFilter.Mixfile do
  use Mix.Project

  def project do
    [
      app: :nested_filter,
      version: "1.2.2",
      elixir: ">= 1.7.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Bruce Park"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/treble37/nested_filter"}
    ]
  end

  defp description do
    """
    Drill down into a nested map and filter out keys according to user
    specified values
    """
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, ">= 0.25.3", only: :dev},
      {:excoveralls, "~> 0.14.3", only: :test},
      {:inch_ex, "~> 2.0.0", only: :docs},
      {:credo, "~> 1.6.0", only: [:dev, :test]}
    ]
  end
end
