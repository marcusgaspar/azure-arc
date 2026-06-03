#!/usr/bin/env bash
set -euo pipefail

# Built-in policy: "Configure Windows Arc Machines to be associated with a
# Data Collection Rule or a Data Collection Endpoint" (v2.4.0)
POLICY_DEFINITION_ID="/providers/Microsoft.Authorization/policyDefinitions/c24c537f-2516-4c2f-aac5-2cd26baa3d26"

# Roles required by the policy's DeployIfNotExists deployment
ROLE_MONITORING_CONTRIBUTOR="749f88d5-cbae-40b8-bcfc-e573ddc772fa"
ROLE_LOG_ANALYTICS_CONTRIBUTOR="92aaf0da-9dab-42b6-94a3-d43ce8d16293"

usage() {
  cat <<'USAGE'
Usage:
  assign-azure-arc-dcr-dce-association-policy.sh \
    --scope <scope> \
    --location <location> \
    --dcr-resource-id <id> \
    [--resource-type <type>] \
    [--assignment-name <name>] \
    [--effect <effect>]

Options:
  --scope            Required. Scope for the policy assignment (subscription or resource group resource ID).
  --location         Required. Azure region for the policy assignment managed identity.
  --dcr-resource-id  Required. Resource ID of the Data Collection Rule (DCR) or Data Collection Endpoint (DCE).
  --resource-type    Resource type of the target. Default: Microsoft.Insights/dataCollectionRules
                     Use Microsoft.Insights/dataCollectionEndpoints for a DCE.
  --assignment-name  Name for the policy assignment. Default: arc-win-dcr-association
  --effect           Policy effect. Allowed: DeployIfNotExists, Disabled. Default: DeployIfNotExists

Note: The 'listOfApplicableLocations' parameter uses the policy built-in default
      covering all supported Azure regions.
USAGE
}

scope=""
location=""
dcr_resource_id=""
resource_type="Microsoft.Insights/dataCollectionRules"
assignment_name="arc-win-dcr-association"
effect="DeployIfNotExists"

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
    --dcr-resource-id)
      dcr_resource_id="$2"
      shift 2
      ;;
    --resource-type)
      resource_type="$2"
      shift 2
      ;;
    --assignment-name)
      assignment_name="$2"
      shift 2
      ;;
    --effect)
      effect="$2"
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

# --- Validate required parameters ---
if [[ -z "$scope" || -z "$location" || -z "$dcr_resource_id" ]]; then
  echo "Error: --scope, --location and --dcr-resource-id are required." >&2
  usage
  exit 1
fi

if [[ "$effect" != "DeployIfNotExists" && "$effect" != "Disabled" ]]; then
  echo "Error: --effect must be 'DeployIfNotExists' or 'Disabled'." >&2
  exit 1
fi

if [[ "$resource_type" != "Microsoft.Insights/dataCollectionRules" && \
      "$resource_type" != "Microsoft.Insights/dataCollectionEndpoints" ]]; then
  echo "Error: --resource-type must be 'Microsoft.Insights/dataCollectionRules' or 'Microsoft.Insights/dataCollectionEndpoints'." >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is required." >&2
  exit 1
fi

# --- Step 1: Create policy assignment with system-assigned managed identity ---
echo "Creating policy assignment '$assignment_name'..."
echo "  Scope:         $scope"
echo "  DCR/DCE ID:    $dcr_resource_id"
echo "  Resource type: $resource_type"
echo "  Effect:        $effect"

az policy assignment create \
  --name "$assignment_name" \
  --scope "$scope" \
  --policy "$POLICY_DEFINITION_ID" \
  --location "$location" \
  --mi-system-assigned \
  --params "{\"effect\":{\"value\":\"$effect\"},\"dcrResourceId\":{\"value\":\"$dcr_resource_id\"},\"resourceType\":{\"value\":\"$resource_type\"}}" \
  --output table

# --- Step 2: Retrieve the managed identity principal ID ---
principal_id=$(az policy assignment show \
  --name "$assignment_name" \
  --scope "$scope" \
  --query identity.principalId \
  --output tsv)

echo "Managed identity principal ID: $principal_id"

# --- Step 3: Assign required roles to the managed identity ---
echo "Assigning 'Monitoring Contributor' role..."
az role assignment create \
  --role "$ROLE_MONITORING_CONTRIBUTOR" \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --scope "$scope" \
  --output table

echo "Assigning 'Log Analytics Contributor' role..."
az role assignment create \
  --role "$ROLE_LOG_ANALYTICS_CONTRIBUTOR" \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --scope "$scope" \
  --output table

echo "Done."
