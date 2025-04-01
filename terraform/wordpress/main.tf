provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "kubernetes_namespace" "wordpress" {
  metadata {
    name = "wordpress"
  }
}

resource "kubernetes_secret" "mysql_password" {
  metadata {
    name      = "mysql-pass"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  data = {
    password = var.mysql_password
  }
}

resource "kubernetes_secret" "aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.aws_access_key
    AWS_SECRET_ACCESS_KEY = var.aws_secret_key
  }
}

resource "kubernetes_config_map" "s3_config" {
  metadata {
    name      = "s3-config"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  data = {
    S3_BUCKET = var.s3_bucket
    S3_REGION = var.s3_region
  }
}

resource "kubernetes_persistent_volume_claim" "mysql_pvc" {
  metadata {
    name      = "mysql-pv-claim"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "local-path"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "mysql" {
  metadata {
    name      = "wordpress-mysql"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "wordpress-mysql"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "wordpress-mysql"
        }
      }

      spec {
        container {
          image = "mysql:5.7"
          name  = "mysql"
          
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_password.metadata[0].name
                key  = "password"
              }
            }
          }
          
          port {
            container_port = 3306
            name           = "mysql"
          }
          
          volume_mount {
            name       = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }
        }
        
        volume {
          name = "mysql-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mysql" {
  metadata {
    name      = "wordpress-mysql"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  
  spec {
    selector = {
      app = kubernetes_deployment.mysql.spec[0].template[0].metadata[0].labels.app
    }
    
    port {
      port = 3306
    }
  }
}

resource "kubernetes_persistent_volume_claim" "wordpress_pvc" {
  metadata {
    name      = "wp-pv-claim"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "local-path"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          image = "wordpress:latest"
          name  = "wordpress"
          
          env {
            name  = "WORDPRESS_DB_HOST"
            value = kubernetes_service.mysql.metadata[0].name
          }
          
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_password.metadata[0].name
                key  = "password"
              }
            }
          }
          
          env {
            name  = "WORDPRESS_DB_USER"
            value = "root"
          }
          
          env {
            name = "S3_BUCKET"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.s3_config.metadata[0].name
                key  = "S3_BUCKET"
              }
            }
          }
          
          env {
            name = "S3_REGION"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.s3_config.metadata[0].name
                key  = "S3_REGION"
              }
            }
          }
          
          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.aws_credentials.metadata[0].name
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          }

          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.aws_credentials.metadata[0].name
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          }
          
          port {
            container_port = 80
            name           = "wordpress"
          }
          
          volume_mount {
            name       = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }
        }
        
        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wordpress_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  
  spec {
    selector = {
      app = kubernetes_deployment.wordpress.spec[0].template[0].metadata[0].labels.app
    }
    
    port {
      port        = 80
      target_port = 80
    }
    
    type = "NodePort"
  }
}
