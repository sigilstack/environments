
# SigilStack Environments

This repository contains the environment assemblies for the SigilStack infrastructure.
An *environment* is a unified collection of related Terraform deployments—composed, controlled, and connected with precision and a sprinkle of absurdity.

## Purpose

Each environment enforces strict composition rules, coupling multiple infrastructure definitions into a single orchestrated unit.
Currently, the only defined environment is **`prodish`**—it’s like production, but don’t let the name fool you.
We’re not producing anything serious here... unless you count deeply unserious infrastructure as serious business.

## Usage

This repo uses [`just`](https://just.systems) as its task runner.
All environment tasks—planning, applying, cleaning—are defined as recipes in the `Justfile`.

### Common Commands

```bash
just plan [local]           # Plan all components for the environment
just apply                  # Apply all components for the environment
just plan-coredns [local]   # Plan only the 'coredns' definition
just apply-coredns          # Apply only the 'coredns' definition
```
When you use the `local` flag on a plan, it will use the local files, passing `local` results in the prodish.yaml.j2 to be rendered using relative paths instead of remote git repositories. The way I have prodish.yaml.j2 setup, it assumes that the sigilstack/worker-definitions repository is cloned into the same parent directory as this repository.

## Related Repositories

- [sigilstack/worker-definitions](https://github.com/sigilstack/worker-definitions) – terraform modules wired into environments
- [ephur/terraform-worker](https://github.com/ephur/terraform-worker) – execution engine and lifecycle tooling for SigilStack environments
