worker_config := "prodish.yaml.j2"
worker_dir := ".state/generated"
worker_plan_path := ".state/plans"
worker_provider_cache := ".state/providers"

default:
  just --summary

# Help target to display available commands.
help:
  @echo "Available commands:"
  @echo "  make pr-summary       - Generate a PR summary of recent commits"
  @echo "  make rubberstamp      - Run the rubberstamp script to create and merge a PR"
  @echo "  make plan             - Plan the current definitions"
  @echo "  make apply            - Apply the current plan for all definitions"
  @echo "  make plan-coredns     - Plan the core DNS configuration"
  @echo "  make apply-coredns    - Apply coredns configuration"

# Generate a PR summary of recent commits.
pr-summary:
  @echo "Generating PR summary from commits since master..."
  DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
  git fetch origin $DEFAULT_BRANCH
  git log origin/$DEFAULT_BRANCH..HEAD --pretty=format:"- %s" > .pr_summary.tmp
  if [ ! -s .pr_summary.tmp ]; then echo "No new commits to summarize."; rm -f .pr_summary.tmp; exit 0; fi
  echo "\nProposed PR Body:\n"
  cat .pr_summary.tmp
  rm .pr_summary.tmp

# Run the rubberstamp script to create and merge a PR using the pr-summary output.
rubberstamp:
  ./scripts/rubberstamp.sh

# Central task for running terraform worker with plan or apply actions.
# Usage: called by plan/apply targets.
# When new definitions are added, add corresponding plan-<definition> and apply-<definition> targets.

# Clean up temporary files, state, and plans.
clean limit="":
  echo "Cleaning up temporary files..."
  rm -f .pr_summary.tmp
  rm -rf .state/generated/definitions
  if [ -n "{{limit}}" ]; then \
    rm -rf .state/plans/sigilstack/{{limit}}.*; \
  else \
    rm -rf .state/plans/sigilstack/*; \
  fi

# Deploy is a recipe not intended to be called directly; but rather through plan-<definition> or apply-<definition>.
deploy action="" limit="" local="false":
  echo "Deploying with action: {{action}}, limit: {{limit}}, local: {{local}}"
  just clean {{limit}}

  ARGS=""; \
  if [ "{{action}}" = "plan" ]; then \
    ARGS+="--no-apply"; \
  elif [ "{{action}}" = "apply" ]; then \
    ARGS+="--apply"; \
  elif [ "{{action}}" != "" ]; then \
    echo "Invalid action: {{action}}"; exit 1; \
  fi; \
  if [ "{{limit}}" != "" ]; then \
    ARGS+=" --limit {{limit}}"; \
  fi; \
  worker_args="--config-file {{worker_config}} --working-dir {{worker_dir}}"; \
  worker_tf_args="--provider-cache {{worker_provider_cache}} --plan-file-path {{worker_plan_path}}"; \
  worker ${worker_args} --config-var "local={{local}}" terraform sigilstack ${ARGS} ${worker_tf_args}

# Plan the current definitions; optionally pass local to use local files instead of remote.
plan local="":
  if [ "{{local}}" = "local" ]; then \
    just deploy plan "" true; \
  elif [ "{{local}}" = "" ]; then \
    just deploy plan "" false; \
  else \
    echo "Invalid local argument: {{local}}"; exit 1; \
  fi

# Apply the current plan for all definitions that have a saved plan.
apply:
  just deploy apply

# Plan the core DNS configuration; optionally pass local to use local files instead of remote.
plan-coredns local="":
  if [ "{{local}}" = "local" ]; then \
    just deploy plan coredns true; \
  elif [ "{{local}}" = "" ]; then \
    just deploy plan coredns false; \
  else \
    echo "Invalid local argument: {{local}}"; exit 1; \
  fi

# Apply coredns configuration; must have a valid plan saved.
apply-coredns:
    just deploy apply coredns
