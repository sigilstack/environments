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
  @echo "  make test-image       - Build and run tests inside the docker image"

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
clean deployment="" limit="":
  echo "Cleaning up temporary files..."
  rm -f .pr_summary.tmp
  if [ -n "{{deployment}}" ]; then \
    if [ -n "{{limit}}" ]; then \
      rm -f .state/plans/{{deployment}}/{{limit}}.*; \
    else \
      rm -f .state/plans/{{deployment}}/*; \
    fi; \
    rm -rf .state/generated/{{deployment}}; \
  else \
    rm -rf .state/generated/*; \
    rm -f .state/plans/*; \
  fi
  echo "Temporary files cleaned."

# Deploy is a recipe not intended to be called directly; but rather through plan-<definition> or apply-<definition>.
deploy deployment action="" limit="" local="false":
  echo "Deploying with deployment: {{deployment}}, action: {{action}}, limit: {{limit}}, local: {{local}}"
  just clean {{deployment}} {{limit}}

  # ensure the worker base directories exist
  mkdir -p {{worker_dir}}/{{deployment}}
  mkdir -p {{worker_plan_path}}/{{deployment}}
  mkdir -p {{worker_provider_cache}}

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
  worker_args="--config-file {{deployment}}.yaml.j2 --working-dir {{worker_dir}}/{{deployment}}"; \
  worker_tf_args="--provider-cache {{worker_provider_cache}} --plan-file-path {{worker_plan_path}}/{{deployment}}"; \
  worker ${worker_args} --config-var "local={{local}}" terraform {{deployment}} ${ARGS} ${worker_tf_args}

# Plan the current definitions; optionally pass local to use local files instead of remote.
plan deployment local="":
  if [ "{{local}}" = "local" ]; then \
    just deploy {{deployment}} plan "" true; \
  elif [ "{{local}}" = "" ]; then \
    just deploy {{deployment}} plan "" false; \
  else \
    echo "Invalid local argument: {{local}}"; exit 1; \
  fi

# Apply the current plan for all definitions that have a saved plan.
apply deployment limit="":
  just deploy apply {{deployment}} {{limit}} false

# Plan the core DNS configuration; optionally pass local to use local files instead of remote.
plan-coredns local="":
  if [ "{{local}}" = "local" ]; then \
    just deploy sigilstack plan coredns true; \
  elif [ "{{local}}" = "" ]; then \
    just deploy sigilstack plan coredns false; \
  else \
    echo "Invalid local argument: {{local}}"; exit 1; \
  fi

# Apply coredns configuration; must have a valid plan saved.
apply-coredns:
    just deploy sigilstack apply coredns

# Build and test the image with development dependencies
test-image:
  echo "Building docker image for testing..."
  docker build -t terraform-worker-test -f oci/Dockerfile oci/
  echo "Running tests inside the image..."
  docker run --rm --entrypoint bash terraform-worker-test -c "\
    cd /opt/terraform-worker && \
    . /opt/venv/bin/activate && \
    poetry install --with dev && \
    make test"
