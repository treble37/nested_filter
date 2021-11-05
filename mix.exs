defmodule NestedFilter.Mixfile do
  use Mix.Project

  @source_url "https://github.com/treble37/nested_filter"
  @version "1.2.2"

  def project do
    [
      app: :nested_filter,
      version: @version,
      elixir: ">= 1.7.0",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  defp package do
    [
      description: "Drill down into a nested map and filter out keys "
       <> "according to user specified values",
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Bruce Park"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/nested_filter/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14.3", only: :test},
      {:inch_ex, "~> 2.0.0", only: :docs},
      {:credo, "~> 1.5.6", only: [:dev, :test]}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end
end
