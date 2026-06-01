# azure-arc

Scripts to create/enable Azure Policies for Azure Arc scenarios.

## Included scenario support

- Enable Azure Monitor for Hybrid VMs with AMA (`ama`)
- Configure Arc-enabled Servers with SQL Server extension to enable/disable SQL best practices assessment (`sql-bpa`)
- Configure periodic checking for missing system updates on Azure Arc-enabled servers (`missing-updates`)
- Activate Azure benefits (Software Assurance) (`sa-benefits`)

## Usage

```bash
./scripts/assign-azure-arc-policy.sh \
  --scope /subscriptions/<subscription-id> \
  --feature ama \
  --policy-definition-id /providers/Microsoft.Authorization/policyDefinitions/<definition-id>
```

You can also pass an explicit policy definition ID when needed:

```bash
./scripts/assign-azure-arc-policy.sh \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group> \
  --feature sql-bpa \
  --policy-definition-id /providers/Microsoft.Authorization/policyDefinitions/<definition-id>
```

Show help:

```bash
./scripts/assign-azure-arc-policy.sh --help
```

> Note: `--policy-definition-id` is required; the script does not perform display-name lookup.
