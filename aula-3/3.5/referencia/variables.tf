variable "namespace" {
  description = "Namespace Kubernetes para o serviço"
  type        = string
  default     = "payment"
}

variable "environment" {
  description = "Nome do ambiente"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Nome da aplicação"
  type        = string
  default     = "payment-api"
}

variable "image" {
  description = "Imagem do container com tag fixa"
  type        = string
  default     = "hashicorp/http-echo:0.2.3"
}

variable "container_args" {
  description = "Argumentos do container"
  type        = list(string)
  default     = ["-text=payment-api running"]
}

variable "replicas" {
  description = "Número de réplicas"
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Porta do container"
  type        = number
  default     = 5678
}

variable "cpu_limit" {
  description = "Limite de CPU"
  type        = string
  default     = "100m"
}

variable "memory_limit" {
  description = "Limite de memória"
  type        = string
  default     = "128Mi"
}

variable "log_level" {
  description = "Nível de log"
  type        = string
  default     = "info"
}

variable "quota_max_pods" {
  description = "Máximo de pods no namespace"
  type        = string
  default     = "6"
}

variable "quota_max_memory" {
  description = "Máximo de memória total no namespace"
  type        = string
  default     = "1Gi"
}

variable "db_password" {
  description = "Password do banco de dados"
  type        = string
  sensitive   = true
  default     = "lab-db-pass-456"
}

variable "api_key" {
  description = "API key do serviço"
  type        = string
  sensitive   = true
  default     = "lab-api-key-789"
}
