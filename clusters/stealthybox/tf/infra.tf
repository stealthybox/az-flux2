data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "stealthybox" {
  name     = "stealthybox"
  location = "westcentralus"
}

resource "azurerm_kubernetes_cluster" "stealthybox" {
  name                = "stealthybox"
  resource_group_name = azurerm_resource_group.stealthybox.name
  location            = azurerm_resource_group.stealthybox.location

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }
  identity {
    type = "SystemAssigned" # needed for AAD Pod Identity
  }

  dns_prefix = "stealthybo-stealthybox-8c6918"
  default_node_pool {
    name       = "nodepool1"
    vm_size    = "Standard_DS2_v2"
    node_count = 3
  }
  linux_profile {
    admin_username = "azureuser"
    ssh_key {
      key_data = <<-EOT
            ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDKwr6gBpqSyrmgnf+tKTHwiiTpqKcLLWcxT/ZHoROAEYtmVWdTQnAgInA3GPqicSwYMBZ3UgRSxrcpKmZ9FkAhOsBCamzWr8CmGmKh5C6M/jSOHzTtbRjN5JThk/KRKWwdKlZ21giCEgDffmDD7n658n0gOFH4VwL9MD7Nn/Zvck4n1r+M2yH7irRrTJxWJjfC7Ki/dduPK/ItbuFZCg41Di/0hyGuyOtQyA+t79B2zbCsYLqtQNBrP5B1XFDfj72R2+6mtkOBVaGGVLE/FyLfeN2f+ghtbv3fXo1st1xuw4EaTdTOUAUex8HpxAKn+NzxwBNiNb/s5dNuNCcWzxyf7qdk2doxV2iwYATsRkzgEP++AKCuvEDO9qzYHFtY3+Lmlu99NoCde2gpOrdi7WcMdxHuQHpmPLaiSMmuhT/ukIG/N7nlC9Z7+8iUmdvLO2NSObi3laupV5x5PvCk7taKziKXlfQTGlCSGhYKI2L04Qz3ibzVRjw4Z4QlfaqGjWPK72rKqL17DKWrRd25cuw+1gfgmXeSXOXA1ga/U1Q4eJgOE9L8WexRjqxzMpCNLoyRelEHrA06vziLrtZ2290XcBWHPG+9M4h1xHw5HyPzwNgH10RkR3XknpxhIxTgrDA5blD79wDGmGT02PahKxdE5ExZd/hd7Apq09eCi/2HFw== stealthybox@LAPTOP-AB44U77P
        EOT
    }
  }
}
# Allow AAD Pod Identity to assign/un-assign identities for the underlying VM/VMSS
#   + Omit the suggested access to identities within the node resource group
#   https://azure.github.io/aad-pod-identity/docs/getting-started/role-assignment/#performing-role-assignments
data "azurerm_resource_group" "stealthybox-nodes" {
  name = azurerm_kubernetes_cluster.stealthybox.node_resource_group
}
resource "azurerm_role_assignment" "stealthybox-aad-pod-identity-vm-contributor" {
  for_each             = { for i, v in azurerm_kubernetes_cluster.stealthybox.kubelet_identity : i => v }
  principal_id         = each.value.object_id
  role_definition_name = "Virtual Machine Contributor"

  scope = data.azurerm_resource_group.stealthybox-nodes.id
}
# Allow AAD Pod Identity to access identities within the terraform managed resource group
#   https://azure.github.io/aad-pod-identity/docs/getting-started/role-assignment/#user-assigned-identities-that-are-not-within-the-node-resource-group
resource "azurerm_role_assignment" "stealthybox-aad-pod-identity-identity-operator" {
  for_each             = { for i, v in azurerm_kubernetes_cluster.stealthybox.kubelet_identity : i => v }
  principal_id         = each.value.object_id
  role_definition_name = "Managed Identity Operator"

  scope = azurerm_resource_group.stealthybox.id
}

resource "azurerm_container_registry" "weavedx" {
  name                = "weavedx"
  resource_group_name = azurerm_resource_group.stealthybox.name
  location            = azurerm_resource_group.stealthybox.location
  sku                 = "Basic"
}
# attach ACR to AKS cluster
resource "azurerm_role_assignment" "stealthybox-aks-acr" {
  for_each             = { for i, v in azurerm_kubernetes_cluster.stealthybox.kubelet_identity : i => v }
  principal_id         = each.value.object_id
  role_definition_name = "AcrPull"

  scope = azurerm_container_registry.weavedx.id
}

resource "azurerm_key_vault" "stealthybox" {
  name                = "stealthybox-flux"
  resource_group_name = azurerm_resource_group.stealthybox.name
  location            = azurerm_resource_group.stealthybox.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions     = ["Get", "List", "Create", "Encrypt", "Decrypt"]
    secret_permissions  = ["Get"]
    storage_permissions = ["Get"]
  }
}
