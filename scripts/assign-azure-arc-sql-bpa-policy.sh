#!/usr/bin/env bash
set -euo pipefail

# Built-in policy: "Configure Arc-enabled Servers with SQL Server extension
# installed to enable or disable SQL best practices assessment."
POLICY_DEFINITION_ID="/providers/microsoft.authorization/policydefinitions/f36de009-cacb-47b3-b936-9c4c9120d064"

# Roles required by the policy's DeployIfNotExists deployment
ROLE_LOG_ANALYTICS_CONTRIBUTOR="92aaf0da-9dab-42b6-94a3-d43ce8d16293"
ROLE_MONITORING_CONTRIBUTOR="749f88d5-cbae-40b8-bcfc-e573ddc772fa"

usage() {
  cat <<'USAGE'
Usage:
  assign-azure-arc-sql-bpa-policy.sh \
    --scope <scope> \
    --location <location> \
    --la-workspace-id <id> \
    --la-workspace-location <location> \
    [--is-enabled <true|false>] \
    [--assignment-name <name>] \
    [--effect <effect>]

Options:
  --scope                  Required. Scope for the policy assignment (subscription or resource group resource ID).
  --location               Required. Azure region for the policy assignment managed identity.
  --la-workspace-id        Required. Resource ID of the Log Analytics workspace for assessment results.
  --la-workspace-location  Required. Location of the Log Analytics workspace (e.g. eastus).
  --is-enabled             Enable or disable the assessment. Allowed: true, false. Default: true
  --assignment-name        Name for the policy assignment. Default: arc-sql-best-practices
  --effect                 Policy effect. Allowed: DeployIfNotExists, Disabled. Default: DeployIfNotExists
USAGE
}

scope=""
location=""
la_workspace_id=""
la_workspace_location=""
is_enabled="true"
assignment_name="arc-sql-best-practices"
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
    --la-workspace-id)
      la_workspace_id="$2"
      shift 2
      ;;
    --la-workspace-location)
      la_workspace_location="$2"
      shift 2
      ;;
    --is-enabled)
      is_enabled="$2"
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
if [[ -z "$scope" || -z "$location" || -z "$la_workspace_id" || -z "$la_workspace_location" ]]; then
  echo "Error: --scope, --location, --la-workspace-id and --la-workspace-location are required." >&2
  usage
  exit 1
fi

if [[ "$is_enabled" != "true" && "$is_enabled" != "false" ]]; then
  echo "Error: --is-enabled must be 'true' or 'false'." >&2
  exit 1
fi

if [[ "$effect" != "DeployIfNotExists" && "$effect" != "Disabled" ]]; then
  echo "Error: --effect must be 'DeployIfNotExists' or 'Disabled'." >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is required." >&2
  exit 1
fi

# --- Step 1: Create policy assignment with system-assigned managed identity ---
echo "Creating policy assignment '$assignment_name' for Azure Arc SQL BPA..."
echo "  Scope:                  $scope"
echo "  LA Workspace ID:        $la_workspace_id"
echo "  LA Workspace location:  $la_workspace_location"
echo "  Assessment enabled:     $is_enabled"
echo "  Effect:                 $effect"

az policy assignment create \
  --name "$assignment_name" \
  --scope "$scope" \
  --policy "$POLICY_DEFINITION_ID" \
  --location "$location" \
  --mi-system-assigned \
  --params "{\"effect\":{\"value\":\"$effect\"},\"isEnabled\":{\"value\":$is_enabled},\"laWorkspaceId\":{\"value\":\"$la_workspace_id\"},\"laWorkspaceLocation\":{\"value\":\"$la_workspace_location\"}}" \
  --output table

# --- Step 2: Retrieve the managed identity principal ID ---
principal_id=$(az policy assignment show \
  --name "$assignment_name" \
  --scope "$scope" \
  --query identity.principalId \
  --output tsv)

echo "Managed identity principal ID: $principal_id"

# --- Step 3: Assign required roles to the managed identity ---
echo "Assigning 'Log Analytics Contributor' role..."
az role assignment create \
  --role "$ROLE_LOG_ANALYTICS_CONTRIBUTOR" \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --scope "$scope" \
  --output table

echo "Assigning 'Monitoring Contributor' role..."
az role assignment create \
  --role "$ROLE_MONITORING_CONTRIBUTOR" \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --scope "$scope" \
  --output table

echo "Done."
