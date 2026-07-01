terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kube_context
}

locals {
  labels = {
    app        = var.app_name
    managed-by = "terraform"
  }
}

resource "kubernetes_namespace_v1" "main" {
  metadata {
    name = var.namespace
    labels = {
      project    = "devops-training"
      managed-by = "terraform"
    }
  }
}

resource "kubernetes_config_map_v1" "app" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  data = {
    NODE_ENV      = var.node_env
    APP_PORT      = tostring(var.app_port)
    DB_HOST       = "postgres-svc"
    DB_PORT       = "5432"
    DB_NAME       = var.db_name
    APP_LOG_LEVEL = var.app_log_level
    LOG_LEVEL     = var.app_log_level
  }
}

resource "kubernetes_secret_v1" "app" {
  metadata {
    name      = "app-secrets"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  data = {
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim_v1" "postgres" {
  metadata {
    name      = "postgres-pvc"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.postgres_storage
      }
    }
  }
}

resource "kubernetes_deployment_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:16-alpine"

          port {
            name           = "postgres"
            container_port = 5432
          }

          env {
            name = "POSTGRES_DB"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map_v1.app.metadata[0].name
                key  = "DB_NAME"
              }
            }
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.app.metadata[0].name
                key  = "DB_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.app.metadata[0].name
                key  = "DB_PASSWORD"
              }
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.db_user]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.postgres.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = "postgres-svc"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = "postgres"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.main.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = var.app_replicas

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name              = "app"
          image             = "${var.image_repository}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = var.app_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.app.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.app.metadata[0].name
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }

    type = "ClusterIP"
  }
}