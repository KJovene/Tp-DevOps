terraform {
  required_version = ">= 1.6"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

locals {
  workspace_suffix = terraform.workspace == "default" ? "" : "-${terraform.workspace}"
  port_offsets = {
    default = 0
    dev     = 10
    staging = 20
    prod    = 30
  }
  port_offset           = lookup(local.port_offsets, terraform.workspace, 40)
  scoped_environment    = "${var.environment}${local.workspace_suffix}"
  scoped_web_port_start = var.web_port + local.port_offset
  scoped_db_port        = var.db_port + local.port_offset
}

resource "docker_network" "main" {
  name = "devops-${local.scoped_environment}"
}

module "webapp" {
  source      = "../../modules/webapp"
  app_name    = var.app_name
  environment = local.scoped_environment
  port        = local.scoped_web_port_start
  replicas    = var.web_replicas
  network_id  = docker_network.main.name
}

module "database" {
  source      = "../../modules/database"
  app_name    = var.app_name
  environment = local.scoped_environment
  db_password = var.db_password
  db_port     = local.scoped_db_port
  network_id  = docker_network.main.name
}

variable "app_name" { type = string }
variable "environment" { type = string }
variable "web_port" { type = number }
variable "web_replicas" { type = number }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_port" { type = number }

output "web_urls" {
  value = module.webapp.urls
}

output "db_connection" {
  value     = module.database.connection_string
  sensitive = true
}

variable "app_log_level" {
  type    = string
  default = "info"
}

output "ansible_inventory" {
  value = yamlencode({
    all = {
      vars = {
        ansible_connection         = "docker"
        ansible_python_interpreter = "/usr/bin/python3"
        app_name                   = var.app_name
        app_environment            = var.environment
        app_log_level              = var.app_log_level
        database_host              = module.database.ansible_host.name
        database_port              = module.database.ansible_host.port
      }
      children = {
        webservers = {
          hosts = module.webapp.ansible_hosts
        }
        databases = {
          hosts = {
            (module.database.ansible_host.name) = {}
          }
        }
      }
    }
  })
}