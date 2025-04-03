# Create namespace for WordPress
resource "kubernetes_namespace" "wordpress" {
  metadata {
    name = "wordpress"
  }
  depends_on = [module.k3s_cluster]
}

# Create persistent volume claim for MySQL
resource "kubernetes_persistent_volume_claim" "mysql_pvc" {
  metadata {
    name      = "mysql-pvc"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = "local-path"
  }
}

# Create persistent volume claim for WordPress
resource "kubernetes_persistent_volume_claim" "wordpress_pvc" {
  metadata {
    name      = "wordpress-pvc"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    storage_class_name = "local-path"
  }
}

# Deploy MySQL
resource "kubernetes_deployment" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
    labels = {
      app = "mysql"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          image = "mysql:5.7"
          name  = "mysql"

          port {
            container_port = 3306
          }

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "rootpassword" # Use kubernetes_secret in production
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "wordpress"
          }

          env {
            name  = "MYSQL_USER"
            value = "wordpress"
          }

          env {
            name  = "MYSQL_PASSWORD"
            value = "wordpress" # Use kubernetes_secret in production
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

# Create MySQL Service
resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  spec {
    selector = {
      app = "mysql"
    }
    port {
      port        = 3306
      target_port = 3306
    }
    cluster_ip = "None"
  }
}

# Deploy WordPress with NGINX
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
    labels = {
      app = "wordpress"
    }
  }

  spec {
    replicas = 2 # Two WordPress instances as required

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          image = "wordpress:php8.1-fpm"
          name  = "wordpress"

          port {
            container_port = 9000
            name           = "wordpress"
          }

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mysql"
          }

          env {
            name  = "WORDPRESS_DB_USER"
            value = "wordpress"
          }

          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "wordpress" # Use kubernetes_secret in production
          }

          env {
            name  = "WORDPRESS_DB_NAME"
            value = "wordpress"
          }

          # S3 integration for media files
          env {
            name  = "WORDPRESS_CONFIG_EXTRA"
            value = <<-EOT
              define('AS3CF_SETTINGS', serialize(array(
                  'provider' => 'aws',
                  'access-key-id' => '${var.aws_access_key}',
                  'secret-access-key' => '${var.aws_secret_key}',
                  'bucket' => 'ds-exam-app-data-xotjx8lp',
                  'region' => 'eu-west-3'
              )));
            EOT
          }

          volume_mount {
            name       = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }
        }

        # NGINX container
        container {
          image = "nginx:1.21"
          name  = "nginx"

          port {
            container_port = 80
            name           = "http"
          }

          volume_mount {
            name       = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
          }
        }

        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wordpress_pvc.metadata[0].name
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = kubernetes_config_map.nginx_config.metadata[0].name
          }
        }
      }
    }
  }
}

# NGINX ConfigMap
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "nginx-config"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  data = {
    "default.conf" = <<-EOT
      server {
          listen 80;
          server_name _;
          
          root /var/www/html;
          index index.php;
          
          location / {
              try_files $uri $uri/ /index.php?$args;
          }
          
          location ~ \.php$ {
              fastcgi_pass 127.0.0.1:9000;
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              include fastcgi_params;
          }
      }
    EOT
  }
}

# Create WordPress Service
resource "kubernetes_service" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  spec {
    selector = {
      app = "wordpress"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

# NGINX Load Balancer
resource "kubernetes_deployment" "nginx_lb" {
  metadata {
    name      = "nginx-lb"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
    labels = {
      app = "nginx-lb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-lb"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-lb"
        }
      }

      spec {
        container {
          image = "nginx:1.21"
          name  = "nginx-lb"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "nginx-lb-config"
            mount_path = "/etc/nginx/conf.d"
          }
        }

        volume {
          name = "nginx-lb-config"
          config_map {
            name = kubernetes_config_map.nginx_lb_config.metadata[0].name
          }
        }
      }
    }
  }
}

# NGINX Load Balancer ConfigMap
resource "kubernetes_config_map" "nginx_lb_config" {
  metadata {
    name      = "nginx-lb-config"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  data = {
    "default.conf" = <<-EOT
      upstream wordpress {
          server wordpress.wordpress.svc.cluster.local;
      }
      
      server {
          listen 80;
          
          location / {
              proxy_pass http://wordpress;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
          }
      }
    EOT
  }
}

# Load Balancer Service (exposed externally)
resource "kubernetes_service" "nginx_lb" {
  metadata {
    name      = "nginx-lb"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }
  spec {
    selector = {
      app = "nginx-lb"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
