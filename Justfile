default:
    just --summary

pr-summary:
    @echo "Generating PR summary from commits since master..."
    DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
    git fetch origin $DEFAULT_BRANCH
    git log origin/$DEFAULT_BRANCH..HEAD --pretty=format:"- %s" > .pr_summary.tmp
    if [ ! -s .pr_summary.tmp ]; then echo "No new commits to summarize."; rm -f .pr_summary.tmp; exit 0; fi
    echo "\nProposed PR Body:\n"
    cat .pr_summary.tmp
    rm .pr_summary.tmp

rubberstamp:
    ./scripts/rubberstamp.sh

clean:
    echo "Cleaning up temporary files..."
    rm -f .pr_summary.tmp
    rm -rf .state/generated/definitions

plan:
    just clean
    worker --config-file prodish.yaml.j2 --working-dir .state/generated terraform sigilstack --plan --provider-cache ./.state/providers --plan-file-path ./.state/plans

plan-coredns:
    just clean
    rm -rf .state/plans/sigilstack/coredns.*
    worker --config-file prodish.yaml.j2 --working-dir .state/generated terraform sigilstack --plan --provider-cache ./.state/providers --plan-file-path ./.state/plans

apply:
    just clean
    worker --config-file prodish.yaml.j2 --working-dir .state/generated terraform sigilstack --apply --provider-cache ./.state/providers --plan-file-path ./.state/plans

apply-coredns:
    just clean
    worker --config-file prodish.yaml.j2 --working-dir .state/generated terraform sigilstack --apply --provider-cache ./.state/providers --plan-file-path ./.state/plans
