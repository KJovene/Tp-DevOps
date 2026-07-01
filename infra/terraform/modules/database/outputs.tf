output "connection_string" {
  value     = "postgresql://${var.db_user}:${var.db_password}@localhost:${var.db_port}/${var.db_name}"
  sensitive = true
}

output "container_id" {
  value = docker_container.db.id
}

output "ansible_host" {
  value = {
    name = docker_container.db.name
    port = var.db_port
  }
}