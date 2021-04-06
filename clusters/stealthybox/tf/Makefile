
all: az_ids sops_yaml

az_ids:
	mkdir -p ../azure-identities
	terraform output --json managed-identities | jq -r 'join("\n---\n")' > ../azure-identities/az-ids.yaml

sops_yaml:
	terraform output --json cluster-stealthybox-sops-yaml | jq -r > ../.sops.yaml
