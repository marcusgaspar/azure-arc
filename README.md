# azure-arc

Scripts to create/assign Azure Policies for Azure Arc scenarios.

## Included scenario support

- Enable Azure Monitor for Hybrid VMs with AMA
- Configure Arc-enabled Servers with SQL Server extension to enable/disable SQL best practices assessment
- Configure periodic checking for missing system updates on Azure Arc-enabled servers
- Activate Azure benefits (Software Assurance) — creates a custom policy definition from local files and assigns it
- Associate Windows Arc Machines with a Data Collection Rule (DCR) or Data Collection Endpoint (DCE)

## Scripts

| Script                                           | Description                                                 | Policy source                                                          |
| ------------------------------------------------ | ----------------------------------------------------------- | ---------------------------------------------------------------------- |
| `assign-azure-arc-ama-policy.sh`                 | Enable Azure Monitor Agent on Arc-enabled servers           | Built-in initiative `2b00397d-c309-49c4-aa5a-f0b2c5bc6321` (hardcoded) |
| `assign-azure-arc-sql-bpa-policy.sh`             | Enable SQL Server Best Practices Assessment                 | Built-in policy `f36de009-cacb-47b3-b936-9c4c9120d064` (hardcoded)     |
| `assign-azure-arc-missing-updates-policy.sh`     | Periodic check for missing system updates                   | Built-in policy `bfea026e-043f-4ff4-9d1b-bf301ca7ff46` (hardcoded)     |
| `assign-azure-arc-sa-benefits-policy.sh`         | Activate Software Assurance benefits on Windows Arc servers | **Custom** — created from `policy/arc-windows-server-license-sa/`      |
| `assign-azure-arc-dcr-dce-association-policy.sh` | Associate Windows Arc Machines with a DCR or DCE            | Built-in policy `c24c537f-2516-4c2f-aac5-2cd26baa3d26` (v2.4.0)        |

## Custom policy definitions

The `policy/` directory contains custom Azure Policy definitions deployed by the scripts above.

### `policy/arc-windows-server-license-sa/`

Deploys a `licenseProfile` resource (`Microsoft.HybridCompute/machines/licenseProfiles`) on Windows Arc machines to activate Software Assurance benefits.

| File                          | Description                                                                   |
| ----------------------------- | ----------------------------------------------------------------------------- |
| `azurepolicy.json`            | Policy rule and deployment template                                           |
| `azurepolicy.parameters.json` | Policy parameters (`effect`: DeployIfNotExists / AuditIfNotExists / Disabled) |

## Usage examples

### AMA initiative assignment

Assigns the built-in initiative "Enable Azure Monitor for Hybrid VMs with AMA" and automatically grants the managed identity the `Azure Connected Machine Resource Administrator`, `Monitoring Contributor`, and `Log Analytics Contributor` roles.

```bash
./scripts/assign-azure-arc-ama-policy.sh \
  --scope /subscriptions/<subscription-id> \
  --location eastus \
  --dcr-resource-id /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Insights/dataCollectionRules/<dcr-name>
```

Optional parameters: `--assignment-name <name>` (default: `arc-enable-ama`), `--effect <DeployIfNotExists|Disabled>` (default: `DeployIfNotExists`).

### SQL BPA policy assignment

Assigns the built-in policy to enable SQL Server Best Practices Assessment on Arc-enabled servers. Automatically grants the managed identity the `Log Analytics Contributor` and `Monitoring Contributor` roles.

```bash
./scripts/assign-azure-arc-sql-bpa-policy.sh \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group> \
  --location eastus \
  --la-workspace-id /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name> \
  --la-workspace-location eastus
```

Optional parameters: `--is-enabled <true|false>` (default: `true`), `--assignment-name <name>` (default: `arc-sql-best-practices`), `--effect <DeployIfNotExists|Disabled>` (default: `DeployIfNotExists`).

### Missing updates policy assignment

Assigns the built-in policy to configure periodic checking for missing system updates on Arc-enabled servers. Automatically grants the managed identity the `Azure Connected Machine Resource Administrator` role.

```bash
./scripts/assign-azure-arc-missing-updates-policy.sh \
  --scope /subscriptions/<subscription-id> \
  --location eastus
```

Optional parameters: `--assignment-name <name>` (default: `arc-missing-updates`), `--os-type <Windows|Linux>` (default: `Windows`), `--assessment-mode <AutomaticByPlatform|ImageDefault>` (default: `AutomaticByPlatform`).

### Software Assurance benefits (custom policy)

Creates the custom policy definition from local files and assigns it. Requires `jq`.

```bash
./scripts/assign-azure-arc-sa-benefits-policy.sh \
  --scope /subscriptions/<subscription-id> \
  --location eastus
```

Optional parameters: `--policy-name <name>` (default: `arc-windows-server-license-sa`), `--assignment-name <name>` (default: `arc-sa-benefits`).

### DCR / DCE association policy assignment

Associates Windows Arc Machines with a Data Collection Rule or Data Collection Endpoint.
Automatically assigns the required roles (`Monitoring Contributor`, `Log Analytics Contributor`) to the managed identity.

```bash
./scripts/assign-azure-arc-dcr-dce-association-policy.sh \
  --scope /subscriptions/<subscription-id> \
  --location eastus \
  --dcr-resource-id /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Insights/dataCollectionRules/<dcr-name>
```

To target a Data Collection Endpoint instead:

```bash
./scripts/assign-azure-arc-dcr-dce-association-policy.sh \
  --scope /subscriptions/<subscription-id> \
  --location eastus \
  --dcr-resource-id /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Insights/dataCollectionEndpoints/<dce-name> \
  --resource-type Microsoft.Insights/dataCollectionEndpoints
```

Optional parameters: `--assignment-name <name>` (default: `arc-win-dcr-association`), `--effect <DeployIfNotExists|Disabled>` (default: `DeployIfNotExists`).

---

Show help for any script:

```bash
./scripts/<script-name>.sh --help
```
