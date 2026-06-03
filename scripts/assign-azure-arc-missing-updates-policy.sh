#!/usr/bin/env bash
set -euo pipefail

# Built-in policy: "Configure periodic checking for missing system updates on
# Azure Arc-enabled servers"
POLICY_DEFINITION_ID="/providers/microsoft.authorization/policydefinitions/bfea026e-043f-4ff4-9d1b-bf301ca7ff46"

# Role required by the policy's Modify effect
ROLE_ARC_MACHINE_ADMIN="cd570a14-e51a-42ad-bac8-bafd67325302"

usage() {
  cat <<'USAGE'
Usage:
  assign-azure-arc-missing-updates-policy.sh \
    --scope <scope> \
    --location <location> \
    [--assignment-name <name>] \
    [--os-type <Windows|Linux>] \
    [--assessment-mode <AutomaticByPlatform|ImageDefault>]

Options:
  --scope            Required. Scope for the policy assignment (subscription or resource group resource ID).
  --location         Required. Azure region for the policy assignment managed identity.
  --assignment-name  Name for the policy assignment. Default: arc-missing-updates
  --os-type          OS type to target. Allowed: Windows, Linux. Default: Windows
  --assessment-mode  Assessment mode. Allowed: AutomaticByPlatform, ImageDefault. Default: AutomaticByPlatform
USAGE
}

scope=""
location=""
assignment_name="arc-missing-updates"
os_type="Windows"
assessment_mode="AutomaticByPlatform"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      [[ $# -gt 1 ]] || { echo "Error: --scope requires a value." >&2; usage; exit 1; }
      scope="$2"
      shift 2
      ;;
    --location)
      [[ $# -gt 1 ]] || { echo "Error: --location requires a value." >&2; usage; exit 1; }
      location="$2"
      shift 2
      ;;
    --assignment-name)
      [[ $# -gt 1 ]] || { echo "Error: --assignment-name requires a value." >&2; usage; exit 1; }
      assignment_name="$2"
      shift 2
      ;;
    --os-type)
      [[ $# -gt 1 ]] || { echo "Error: --os-type requires a value." >&2; usage; exit 1; }
      os_type="$2"
      shift 2
      ;;
    --assessment-mode)
      [[ $# -gt 1 ]] || { echo "Error: --assessment-mode requires a value." >&2; usage; exit 1; }
      assessment_mode="$2"
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
if [[ -z "$scope" || -z "$location" ]]; then
  echo "Error: --scope and --location are required." >&2
  usage
  exit 1
fi

if [[ "$os_type" != "Windows" && "$os_type" != "Linux" ]]; then
  echo "Error: --os-type must be 'Windows' or 'Linux'." >&2
  exit 1
fi

if [[ "$assessment_mode" != "AutomaticByPlatform" && "$assessment_mode" != "ImageDefault" ]]; then
  echo "Error: --assessment-mode must be 'AutomaticByPlatform' or 'ImageDefault'." >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) is required." >&2
  exit 1
fi

# --- Step 1: Create policy assignment with system-assigned managed identity ---
echo "Creating policy assignment '$assignment_name' for Azure Arc missing updates..."
echo "  Scope:           $scope"
echo "  OS type:         $os_type"
echo "  Assessment mode: $assessment_mode"

az policy assignment create \
  --name "$assignment_name" \
  --scope "$scope" \
  --policy "$POLICY_DEFINITION_ID" \
  --location "$location" \
  --mi-system-assigned \
  --params "{\"osType\":{\"value\":\"$os_type\"},\"assessmentMode\":{\"value\":\"$assessment_mode\"}}" \
  --output table

# --- Step 2: Retrieve the managed identity principal ID ---
principal_id=$(az policy assignment show \
  --name "$assignment_name" \
  --scope "$scope" \
  --query identity.principalId \
  --output tsv)

echo "Managed identity principal ID: $principal_id"

# --- Step 3: Assign required role to the managed identity ---
echo "Assigning 'Azure Connected Machine Resource Administrator' role..."
az role assignment create \
  --role "$ROLE_ARC_MACHINE_ADMIN" \
  --assignee-object-id "$principal_id" \
  --assignee-principal-type ServicePrincipal \
  --scope "$scope" \
  --output table

echo "Done."
