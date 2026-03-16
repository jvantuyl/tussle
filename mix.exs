defmodule Tussle.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()
  @source_url "https://github.com/jvantuyl/tussle"

  def project do
    [
      app: :tussle,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "An Elixir server for the resumable upload protocol \"tus\" - maintained fork of the tus package",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  defp docs do
    [
      main: "Tussle",
      source_url: @source_url,
      extras: []
    ]
  end

  def package() do
    [
      files: ~w(lib mix.exs README.md LICENSE VERSION),
      licenses: ["BSD-3-Clause"],
      maintainers: ["Jayson Vantuyl"],
      links: %{"GitHub" => @source_url, "original package" => "https://hex.pm/packages/tus"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Tussle.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.3"},
      {:uuid, "~> 1.1"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
