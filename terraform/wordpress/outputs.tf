output "wordpress_namespace" {
  value = kubernetes_namespace.wordpress.metadata[0].name
  description = "The Kubernetes namespace where WordPress is deployed"
}

output "wordpress_service_name" {
  value = kubernetes_service.wordpress.metadata[0].name
  description = "The name of the WordPress service"
}

output "wordpress_nodeport" {
  value = kubernetes_service.wordpress.spec[0].port[0].node_port
  description = "The NodePort where WordPress is accessible"
}

output "mysql_service_name" {
  value = kubernetes_service.mysql.metadata[0].name
  description = "The name of the MySQL service"
}

output "s3_bucket_name" {
  value = var.s3_bucket
  description = "The S3 bucket used for WordPress media storage"
}

output "wordpress_url" {
  value = "http://<your-server-ip>:${kubernetes_service.wordpress.spec[0].port[0].node_port}"
}
