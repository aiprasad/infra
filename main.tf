provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "challenge-rg" {
  name     = "challenge-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "challenge-vnet" {
  name                = "challenge-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.challenge-rg.location
  resource_group_name = azurerm_resource_group.challenge-rg.name
}

resource "azurerm_subnet" "challenge-subnet" {
  name                 = "challenge-subnet"
  resource_group_name  = azurerm_resource_group.challenge-rg.name
  virtual_network_name = azurerm_virtual_network.challenge-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_key_vault" "challenge-keyvault" {
  name                = "challenge-keyvault"
  resource_group_name = azurerm_resource_group.challenge-rg.name
  location            = azurerm_resource_group.challenge-rg.location
  enabled_for_disk_encryption        = true
  enabled_for_template_deployment    = true
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

resource "azurerm_key_vault_secret" "challenge-keyvault-secret" {
  name         = "openai-key"
  value        = var.azure_openai_key
  key_vault_id = azurerm_key_vault.challenge-keyvault.id
}

data "azurerm_key_vault" "challenge-keyvault-data" {
  name                = azurerm_key_vault.challenge-keyvault.name
  resource_group_name = azurerm_key_vault.challenge-keyvault.resource_group_name
}

resource "azurerm_lb" "challenge-lb" {
  name                = "challenge-lb"
  resource_group_name = azurerm_resource_group.challenge-rg.name
  location            = azurerm_resource_group.challenge-rg.location

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    subnet_id            = azurerm_subnet.challenge-subnet.id
    private_ip_address   = "10.0.1.20"
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_private_link_service" "challenge-privatelink" {
  name                = "challenge-privatelink"
  resource_group_name = azurerm_resource_group.challenge-rg.name
  location            = "West Europe"

  auto_approval_subscription_ids              = ["00000000-0000-0000-0000-000000000000"]
  visibility_subscription_ids                 = ["00000000-0000-0000-0000-000000000000"]
  load_balancer_frontend_ip_configuration_ids = [azurerm_lb.challenge-lb.frontend_ip_configuration.0.id]

  nat_ip_configuration {
    name                       = "primary"
    private_ip_address         = "10.5.1.17"
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.challenge-subnet.id
    primary                    = true
  }

  nat_ip_configuration {
    name                       = "secondary"
    private_ip_address         = "10.5.1.18"
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.challenge-subnet.id
    primary                    = false
  }
}

resource "azurerm_cognitive_account" "challenge-account" {
  name                = "challenge-account"
  location            = azurerm_resource_group.challenge-rg.location
  resource_group_name = azurerm_resource_group.challenge-rg.name
  kind                = "CognitiveServices"
  sku_name            = "S0"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "challenge-deploy" {
  name                 = "challenge-deploy"
  cognitive_account_id = azurerm_cognitive_account.challenge-account.id

  model {
    format  = "OpenAI"
    name    = "gpt-35-turbo"
    version = "1"
  }

  scale {
    type = "Standard"
  }
}

data "azurerm_client_config" "current" {}

variable "azure_openai_key" {
  type  = string
}

variable "subscription_id" {
  type  = string
}

variable "client_id" {
  type  = string
}

variable "client_secret" {
  type  = string
}

variable "tenant_id" {
  type  = string
}
