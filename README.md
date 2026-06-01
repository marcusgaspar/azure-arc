# azure-arc

Scripts to create/enable Azure Policies for Azure Arc scenarios.

## Included scenario support

- Enable Azure Monitor for Hybrid VMs with AMA
- Configure Arc-enabled Servers with SQL Server extension to enable/disable SQL best practices assessment
- Configure periodic checking for missing system updates on Azure Arc-enabled servers
- Activate Azure benefits (Software Assurance)

## Scripts

- `./scripts/assign-azure-arc-ama-policy.sh`
- `./scripts/assign-azure-arc-sql-bpa-policy.sh`
- `./scripts/assign-azure-arc-missing-updates-policy.sh`
- `./scripts/assign-azure-arc-sa-benefits-policy.sh`

## Usage examples

AMA policy assignment:

```bash
./scripts/assign-azure-arc-ama-policy.sh \
  --scope /subscriptions/<subscription-id> \
  --policy-definition-id /providers/Microsoft.Authorization/policyDefinitions/<definition-id>
```

SQL BPA policy assignment at resource group scope:

```bash
./scripts/assign-azure-arc-sql-bpa-policy.sh \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group> \
  --policy-definition-id /providers/Microsoft.Authorization/policyDefinitions/<definition-id>
```

All scripts support optional:

- `--assignment-name <name>`
- `--location <location>`

Show help for any script:

```bash
./scripts/assign-azure-arc-ama-policy.sh --help
```
