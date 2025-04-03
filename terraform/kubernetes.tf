provider "kubernetes" {
  config_path    = "${path.module}/kubeconfig.yaml"
  config_context = "default"
  insecure       = true  # Skip certificate verification
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig.yaml"
    insecure    = true
  }
}
