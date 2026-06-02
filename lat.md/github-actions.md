# GitHub Actions

Reusable composite action and a weekly auto-update workflow.

## Setup action

`.github/actions/setup-devenv` — installs Nix, configures the Cachix devenv cache, and installs devenv. Other repos use it:

```yaml
- uses: megalithic/devenv-base/.github/actions/setup-devenv@main
```

Full example:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: megalithic/devenv-base/.github/actions/setup-devenv@main
      - run: devenv ci
```

## Update workflow

`.github/workflows/update-devenv.yaml` — runs every Monday at 08:00 UTC. Runs `devenv update`, verifies the shell builds with `devenv ci`, and creates a pull request with the updated lock file.

Uses `add-paths: devenv.lock` so only the lock file is committed. This avoids GitHub rejecting pushes that include workflow files (which require a separate `workflows` permission the default `GITHUB_TOKEN` lacks).
