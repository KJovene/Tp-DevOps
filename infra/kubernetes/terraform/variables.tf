variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "Contexte kubectl à utiliser, par exemple minikube ou kind-devops-training."
  default     = "minikube"
}

variable "namespace" {
  type    = string
  default = "devops-training"
}

variable "app_name" {
  type    = string
  default = "devops-app"
}

variable "image_repository" {
  type    = string
  default = "devops-app"
}

variable "image_tag" {
  type    = string
  default = "1.0.0"
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "app_replicas" {
  type    = number
  default = 3
}

variable "node_env" {
  type    = string
  default = "production"
}

variable "app_log_level" {
  type    = string
  default = "info"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_user" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "postgres_storage" {
  type    = string
  default = "1Gi"
}