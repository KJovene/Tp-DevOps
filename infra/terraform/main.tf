# Configuration Terraform
terraform {
  required_version = ">= 1.6"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Provider Docker (local)
provider "docker" {}

# --- Réseau ---
resource "docker_network" "app_network" {
  name = "devops-network"
}

# --- Image Nginx ---
resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

# --- Conteneur Nginx ---
resource "docker_container" "web" {
  name  = "${var.app_name}-${var.environment}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.web_port
  }

  networks_advanced {
    name = docker_network.app_network.name
  }

  env = [
    "NGINX_HOST=localhost",
    "NGINX_PORT=80"
  ]
}

# --- Outputs ---
output "web_url" {
  value       = "http://localhost:${docker_container.web.ports[0].external}"
  description = "URL du serveur web"
}

output "container_id" {
  value = docker_container.web.id
}

locals {
  common_tags = {
    project     = var.app_name
    environment = var.environment
    managed_by  = "terraform"
  }

  container_name = "${var.app_name}-${var.environment}"
}

data "docker_network" "bridge" {
  name = "bridge"
}