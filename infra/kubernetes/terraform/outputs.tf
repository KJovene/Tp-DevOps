output "namespace" {
  value = kubernetes_namespace_v1.main.metadata[0].name
}

output "app_service" {
  value = kubernetes_service_v1.app.metadata[0].name
}

output "port_forward_command" {
  value = "kubectl port-forward -n ${kubernetes_namespace_v1.main.metadata[0].name} svc/${kubernetes_service_v1.app.metadata[0].name} 18080:80"
}

output "runtime_contract" {
  value = {
    runtime       = "kubernetes"
    replicas      = var.app_replicas
    app_log_level = var.app_log_level
    database_host = kubernetes_service_v1.postgres.metadata[0].name
  }
}