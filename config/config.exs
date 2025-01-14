use Mix.Config

config :git_ops,
  mix_project: JSONAPI.Mixfile,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/NarrativeApp/jsonapi",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
  version_tag_prefix: "v"
