defmodule NestedFilter.Mixfile do
  use Mix.Project

  @version "2.1.0"
  @source_url "https://github.com/treble37/nested_filter"

  def project do
    [
      app: :nested_filter,
      version: @version,
      elixir: "~> 1.15",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      deps: deps(),
      source_url: @source_url,
      docs: [source_ref: "v#{@version}"]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.github": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Bruce Park"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp description do
    """
    Structure-preserving filter/reject for nested maps and lists: drop or
    take keys and values at any depth without flattening or losing data.
    Zero runtime dependencies.
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
      {:ex_doc, ">= 0.40.0", only: :dev},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:credo, "~> 1.7.0", only: [:dev, :test]},
      {:stream_data, "~> 1.1", only: [:test, :dev]}
    ]
  end
end
