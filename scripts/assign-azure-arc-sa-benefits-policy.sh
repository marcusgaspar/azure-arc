#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="$SCRIPT_DIR/../policy/arc-windows-server-license-sa"
POLICY_FILE="$POLICY_DIR/azurepolicy.json"
POLICY_PARAMS_FILE="$POLICY_DIR/azurepolicy.parameters.json"

usage() {
  cat <<'USAGE'
Usage:
  assign-azure-arc-sa-benefits-policy.sh --scope <scope> --location <location> [--policy-name <name>] [--assignment-name <name>]

Options:
  --scope            Required. The scope for the policy assignment (e.g. subscription or resource group resource ID).
  --location         Required. Azure region for the policy assignment managed identity (needed for DeployIfNotExists).
  --policy-name      Name for the custom policy definition. Default: arc-windows-server-license-sa
  --assignment-name  Name for the policy assignment. Default: arc-sa-benefits
USAGE
}

scope=""
location=""
policy_name="arc-windows-server-license-sa"
assignment_name="arc-sa-benefits"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      scope="$2"
      shift 2
      ;;
    --location)
      location="$2"
      shift 2
      ;;
    --policy-name)
      policy_name="$2"
      shift 2
      ;;
    --assignment-name)
      assignment_name="$2"
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

if [[ -z "$scope" || -z "$location" ]]; then
  echo "Error: --scope and --location are required." >&2
  usage
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is required." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  exit 1
fi

if [[ ! -f "$POLICY_FILE" ]]; then
  echo "Error: Policy definition file not found: $POLICY_FILE" >&2
  exit 1
fi

if [[ ! -f "$POLICY_PARAMS_FILE" ]]; then
  echo "Error: Policy parameters file not found: $POLICY_PARAMS_FILE" >&2
  exit 1
fi

# --- Step 1: Create custom policy definition ---
echo "Creating custom policy definition '$policy_name'..."

policy_mode=$(jq -r '.mode' "$POLICY_FILE")
policy_rule=$(jq -c '.policyRule' "$POLICY_FILE")

az policy definition create \
  --name "$policy_name" \
  --mode "$policy_mode" \
  --rules "$policy_rule" \
  --params "@$POLICY_PARAMS_FILE" \
  --output table

policy_definition_id=$(az policy definition show --name "$policy_name" --query id --output tsv)
echo "Policy definition created: $policy_definition_id"

# --- Step 2: Create policy assignment with system-assigned managed identity ---
echo "Creating policy assignment '$assignment_name'..."

az policy assignment create \
  --name "$assignment_name" \
  --scope "$scope" \
  --policy "$policy_definition_id" \
  --location "$location" \
  --mi-system-assigned \
  --output table

# --- Step 3: Assign required role to the managed identity ---
echo "Assigning 'Azure Connected Machine Resource Administrator' role to the policy assignment managed identity..."

principal_id=$(az policy assignment show \
  --name "$assignment_name" \
  --scope "$scope" \
  --query identity.principalId \
  --output tsv)

az role assignment create \
  --role "cd570a14-e51a-42ad-bac8-bafd67325302" \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --scope "$scope" \
  --output table

echo "Done."
