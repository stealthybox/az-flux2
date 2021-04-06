# managed identities for Flux
locals {
  managed_identities = {
    acr-sync           = "acrPull"
    sops-akv-decryptor = "Key Vault Crypto User"
  }
}
resource "azurerm_user_assigned_identity" "identity" {
  for_each = local.managed_identities
  name     = each.key

  resource_group_name = azurerm_resource_group.stealthybox.name
  location            = azurerm_resource_group.stealthybox.location
}
resource "azurerm_role_assignment" "role-assignment" {
  for_each             = local.managed_identities
  principal_id         = azurerm_user_assigned_identity.identity[each.key].principal_id
  role_definition_name = each.value

  scope = azurerm_resource_group.stealthybox.id
}

# Flux SOPS crypto
resource "azurerm_key_vault_key" "sops-cluster-stealthybox" {
  name         = "sops-cluster-stealthybox"
  key_vault_id = azurerm_key_vault.stealthybox.id
  key_type     = "RSA"
  key_opts     = ["encrypt", "decrypt"]
  key_size     = 4096
}

# Useful for sops.yaml
output "cluster-stealthybox-sops-yaml" {
  value = yamlencode({
    creation_rules : [
      {
        path_regex      = ".yaml$"
        encrypted_regex = "^(data|stringData)$"
        azure_keyvault  = azurerm_key_vault_key.sops-cluster-stealthybox.id
      }
    ]
  })
}

# AzureIdentity Custom Resources to be added to the repo
output "managed-identities" {
  value = [
    for mgd in azurerm_user_assigned_identity.identity : yamlencode({
      apiVersion = "aadpodidentity.k8s.io/v1"
      kind       = "AzureIdentity"
      metadata = {
        name      = mgd.name
        namespace = "flux-system"
      }
      spec = {
        clientId   = mgd.client_id
        resourceId = mgd.id
        type       = 0
      }
    })
  ]
}
