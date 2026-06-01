#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  assign-azure-arc-policy.sh --scope <scope> --feature <feature> [--policy-definition-id <id>] [--assignment-name <name>] [--location <location>]

Features:
  ama             Enable Azure Monitor for Hybrid VMs with AMA
  sql-bpa         Enable/disable SQL best practices assessment via SQL extension policy
  missing-updates Configure periodic checking for missing system updates
  sa-benefits     Activate Software Assurance (SA) / Azure benefits policy

Examples:
  ./scripts/assign-azure-arc-policy.sh \
    --scope /subscriptions/<subId> \
    --feature ama

  ./scripts/assign-azure-arc-policy.sh \
    --scope /subscriptions/<subId>/resourceGroups/<rg> \
    --feature sql-bpa \
    --policy-definition-id /providers/Microsoft.Authorization/policyDefinitions/<definitionId>
USAGE
}

scope=""
feature=""
policy_definition_id=""
assignment_name=""
location=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      scope="$2"
      shift 2
      ;;
    --feature)
      feature="$2"
      shift 2
      ;;
    --policy-definition-id)
      policy_definition_id="$2"
      shift 2
      ;;
    --assignment-name)
      assignment_name="$2"
      shift 2
      ;;
    --location)
      location="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$scope" || -z "$feature" ]]; then
  echo "Error: --scope and --feature are required." >&2
  usage
  exit 1
fi

case "$feature" in
  ama)
    default_assignment_name="arc-enable-ama"
    ;;
  sql-bpa)
    default_assignment_name="arc-sql-best-practices"
    ;;
  missing-updates)
    default_assignment_name="arc-missing-updates"
    ;;
  sa-benefits)
    default_assignment_name="arc-sa-benefits"
    ;;
  *)
    echo "Error: invalid --feature value '$feature'." >&2
    usage
    exit 1
    ;;
esac

if [[ -z "$assignment_name" ]]; then
  assignment_name="$default_assignment_name"
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is required." >&2
  exit 1
fi

if [[ -z "$policy_definition_id" ]]; then
  echo "Error: --policy-definition-id is required for feature '$feature'." >&2
  exit 1
fi

echo "Creating/updating policy assignment '$assignment_name' for feature '$feature'..."
cmd=(
  az policy assignment create
  --name "$assignment_name"
  --scope "$scope"
  --policy "$policy_definition_id"
  --output table
)

if [[ -n "$location" ]]; then
  cmd+=(--location "$location")
fi

"${cmd[@]}"

echo "Done."
