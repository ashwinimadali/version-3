terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.104.2"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "688bbb24-df9e-4ca0-8c1d-ebe968c3671d"
  client_id       = "c84a9f96-a466-4091-a968-d790f3e25c8f"
  client_secret   = "Tye8Q~wWoZq2roQmkkDjgV1KZ9dG2AKsO3jaibnf"
  tenant_id       = "b0a69871-4f2a-4ff6-a556-4cc8d78aad82"
}