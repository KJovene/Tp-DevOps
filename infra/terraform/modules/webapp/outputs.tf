output "container_ids" {
  value = docker_container.app[*].id
}

output "urls" {
  value = [
    for c in docker_container.app :
    "http://localhost:${c.ports[0].external}"
  ]
}

output "ansible_hosts" {
  value = {
    for c in docker_container.app :
    c.name => {
      public_url  = "http://localhost:${c.ports[0].external}"
      public_port = c.ports[0].external
    }
  }
}