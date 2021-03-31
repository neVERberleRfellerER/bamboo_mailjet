defmodule BambooMailjet.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bamboo_mailjet,
      version: "0.3.0",
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: "A Mailjet adapter for Bamboo",
      package: package(),
      deps: deps()
    ]
  end

  defp package do
    [
      maintainers: ["neVERberleRfellerER"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/neVERberleRfellerER/bamboo_mailjet"}
    ]
  end

  def application do
    [
      applications: [:logger, :bamboo]
    ]
  end

  defp deps do
    [
      {:bamboo, "~> 2.0"},
      {:cowboy, "~> 2.8", only: [:test, :dev]},
      {:plug_cowboy, "~> 2.4", only: [:test, :dev]},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.24", only: :dev},
      {:inch_ex, "~> 2.0.0", only: :dev}
    ]
  end
end
