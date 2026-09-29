output "namespace" {
  description = "Namespace criado"
  value       = kubernetes_namespace.payment.metadata[0].name
}

output "deployment_name" {
  description = "Nome do deployment"
  value       = kubernetes_deployment.payment.metadata[0].name
}

output "service_endpoint" {
  description = "Endpoint interno do serviço"
  value       = "${kubernetes_service.payment.metadata[0].name}.${kubernetes_namespace.payment.metadata[0].name}.svc.cluster.local:${var.container_port}"
}

output "service_account" {
  description = "ServiceAccount usado pelo pod"
  value       = kubernetes_service_account.payment.metadata[0].name
}

output "network_policy" {
  description = "NetworkPolicy aplicada"
  value       = kubernetes_network_policy.payment.metadata[0].name
}
