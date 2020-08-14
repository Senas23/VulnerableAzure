#Provision AKS cluster in Azure

resource "azurerm_kubernetes_cluster" "vuln_k8_cluster" {
  name                = "${var.vulnvm-name}-kubecluster"
  location            = azurerm_resource_group.victim-network-rg.location
  resource_group_name = azurerm_resource_group.victim-network-rg.name
  dns_prefix          = "${var.vulnvm-name}-k8"

  default_node_pool {
    name       = "default"
    node_count = var.nodecount
    vm_size    = "Standard_D2_v2"
  }

 service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }
  
  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"     # Options are calico or azure - only if network plugin is set to azure
    dns_service_ip     = "172.16.0.10" # Required when network plugin is set to azure, must be in the range of service_cidr and above 1
    docker_bridge_cidr = "172.17.0.1/16"
    service_cidr       = "172.16.0.0/16" # Must not overlap any address from the VNEt
  }
}



#Authenticate to Terraform Kubernetes Module

#Provider for K8, used after built
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.vuln_k8_cluster.kube_config.0.host
  username               = azurerm_kubernetes_cluster.vuln_k8_cluster.kube_config.0.username
  password               = azurerm_kubernetes_cluster.vuln_k8_cluster.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.vuln_k8_cluster.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.vuln_k8_cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.vuln_k8_cluster.kube_config.0.cluster_ca_certificate)

depends_on = [
    azurerm_kubernetes_cluster.vuln_k8_cluster
  ]

}


#Perform Configuration on K8 cluster itself



resource "kubernetes_namespace" "vuln-k8" {
  metadata {
    name                   = "vuln-k8"
  }
}


resource "kubernetes_deployment" "vuln-k8-deployment" {
  metadata {
    name                   = "vuln-k8"
    namespace              = "vuln-k8"
    labels                 = {
      app                  = "vuln-k8"
    }
  }

  spec {
    replicas               = 2

    selector {
      match_labels         = {
        app                = "vuln-k8"
      }
    }

    template {
      metadata {
        labels             = {
          app              = "vuln-k8"
        }
      }

      spec {
        container {
          image            = "yonatanph/logicdemo:latest"
          name             = "user-app"
          port {
            container_port = "80"
          }
          security_context {
            capabilities {
              add          = ["SYS_ADMIN"]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "vuln-k8-service" {
  metadata {
    name                   = "vuln-k8"
    namespace              = "vuln-k8"
  }
  spec {
    selector               = {
      app                  = "vuln-k8"
    }
    port {
      port                 = 80
    }

    type                   = "LoadBalancer"
  }
}