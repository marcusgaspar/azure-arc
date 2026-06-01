#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  assign-azure-arc-sa-benefits-policy.sh --scope <scope> --policy-definition-id <id> [--assignment-name <name>] [--location <location>]
USAGE
}

scope=""
policy_definition_id=""
assignment_name="arc-sa-benefits"
location=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      scope="$2"
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

if [[ -z "$scope" || -z "$policy_definition_id" ]]; then
  echo "Error: --scope and --policy-definition-id are required." >&2
  usage
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is required." >&2
  exit 1
fi

echo "Creating policy assignment '$assignment_name' for Azure Arc SA benefits..."
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
