
all: az_ids sops_yaml

az_ids:
	mkdir -p ../azure-identities
	terraform output --raw azure-identities > ../azure-identities/az-ids.yaml

sops_yaml:
	terraform output --raw sops-yaml > ../.sops.yaml
