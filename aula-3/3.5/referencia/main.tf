terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# --- Namespace ---
resource "kubernetes_namespace" "payment" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      environment = var.environment
    }
  }
}

# --- ResourceQuota ---
resource "kubernetes_resource_quota" "payment" {
  metadata {
    name      = "${var.namespace}-quota"
    namespace = kubernetes_namespace.payment.metadata[0].name
  }

  spec {
    hard = {
      pods            = var.quota_max_pods
      "limits.memory" = var.quota_max_memory
    }
  }
}

# --- LimitRange ---
resource "kubernetes_limit_range" "payment" {
  metadata {
    name      = "${var.namespace}-limits"
    namespace = kubernetes_namespace.payment.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = var.cpu_limit
        memory = var.memory_limit
      }

      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

# --- ConfigMap ---
resource "kubernetes_config_map" "payment" {
  metadata {
    name      = "${var.app_name}-config"
    namespace = kubernetes_namespace.payment.metadata[0].name
    labels = {
      app        = var.app_name
      managed-by = "terraform"
    }
  }

  data = {
    APP_ENV      = var.environment
    LOG_LEVEL    = var.log_level
    SERVICE_NAME = var.app_name
  }
}

# --- Secret ---
resource "kubernetes_secret" "payment" {
  metadata {
    name      = "${var.app_name}-secret"
    namespace = kubernetes_namespace.payment.metadata[0].name
    labels = {
      app        = var.app_name
      managed-by = "terraform"
    }
  }

  data = {
    DB_PASSWORD = var.db_password
    API_KEY     = var.api_key
  }
}

# --- ServiceAccount ---
resource "kubernetes_service_account" "payment" {
  metadata {
    name      = "${var.app_name}-sa"
    namespace = kubernetes_namespace.payment.metadata[0].name
    labels = {
      app        = var.app_name
      managed-by = "terraform"
    }
  }
}

# --- Role ---
resource "kubernetes_role" "payment" {
  metadata {
    name      = "${var.app_name}-role"
    namespace = kubernetes_namespace.payment.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list"]
  }
}

# --- RoleBinding ---
resource "kubernetes_role_binding" "payment" {
  metadata {
    name      = "${var.app_name}-rolebinding"
    namespace = kubernetes_namespace.payment.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.payment.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.payment.metadata[0].name
    namespace = kubernetes_namespace.payment.metadata[0].name
  }
}

# --- Deployment ---
resource "kubernetes_deployment" "payment" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.payment.metadata[0].name
    labels = {
      app         = var.app_name
      managed-by  = "terraform"
      environment = var.environment
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = var.app_name }
    }

    template {
      metadata {
        labels = {
          app         = var.app_name
          environment = var.environment
        }
      }

      spec {
        service_account_name = kubernetes_service_account.payment.metadata[0].name

        container {
          name  = var.app_name
          image = var.image

          args = var.container_args

          port {
            container_port = var.container_port
          }

          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.payment.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.payment.metadata[0].name
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }
      }
    }
  }
}

# --- Service ---
resource "kubernetes_service" "payment" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.payment.metadata[0].name
    labels = {
      app        = var.app_name
      managed-by = "terraform"
    }
  }

  spec {
    selector = { app = var.app_name }

    port {
      port        = var.container_port
      target_port = var.container_port
    }

    type = "ClusterIP"
  }
}

# --- NetworkPolicy ---
resource "kubernetes_network_policy" "payment" {
  metadata {
    name      = "${var.app_name}-allow-labeled-only"
    namespace = kubernetes_namespace.payment.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = { app = var.app_name }
    }

    ingress {
      from {
        pod_selector {
          match_labels = { "allowed-client" = "true" }
        }
      }

      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "ai-iac-lab" }
        }
      }

      ports {
        port     = var.container_port
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}
