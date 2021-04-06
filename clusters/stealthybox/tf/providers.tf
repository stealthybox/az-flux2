terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "0.1.3"
    }

    azurerm = {
      source  = "azurerm"
      version = "2.54.0"
    }
  }
}

provider "azuredevops" {
  org_service_url = "https://dev.azure.com/leigh-weave"
}

provider "azurerm" {
  features {}
}