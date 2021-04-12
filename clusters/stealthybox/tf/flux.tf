# managed identities for Flux
resource "azurerm_user_assigned_identity" "identity" {
  for_each            = toset(["acr-sync", "sops-akv-decryptor"])
  name                = each.value
  resource_group_name = azurerm_resource_group.stealthybox.name
  location            = azurerm_resource_group.stealthybox.location
}
resource "azurerm_role_assignment" "acr-sync" {
  principal_id         = azurerm_user_assigned_identity.identity["acr-sync"].principal_id
  role_definition_name = "acrPull"

  scope = azurerm_resource_group.stealthybox.id
}
resource "azurerm_key_vault_access_policy" "sops-akv-decryptor" {
  key_vault_id    = azurerm_key_vault.stealthybox.id
  tenant_id       = data.azurerm_client_config.current.tenant_id
  object_id       = azurerm_user_assigned_identity.identity["sops-akv-decryptor"].principal_id
  key_permissions = ["Decrypt"]
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
output "sops-yaml" {
  value = yamlencode({
    creation_rules = [
      {
        path_regex      = "\\.yaml$"
        encrypted_regex = "^(data|stringData)$"
        azure_keyvault  = azurerm_key_vault_key.sops-cluster-stealthybox.id
      }
    ]
  })
}

# AzureIdentity Custom Resources to be added to the repo
output "azure-identities" {
  value = join("---\n", flatten([
    for azid in azurerm_user_assigned_identity.identity : [
      yamlencode({
        apiVersion = "aadpodidentity.k8s.io/v1"
        kind       = "AzureIdentity"
        metadata = {
          name      = azid.name
          namespace = "flux-system"
        }
        spec = {
          clientID   = azid.client_id
          resourceID = azid.id
          type       = 0
        }
      }),
      yamlencode({
        apiVersion = "aadpodidentity.k8s.io/v1"
        kind       = "AzureIdentityBinding"
        metadata = {
          name      = azid.name
          namespace = "flux-system"
        }
        spec = {
          azureIdentity = azid.name
          selector      = azid.name
        }
      })
    ]
  ]))
}
