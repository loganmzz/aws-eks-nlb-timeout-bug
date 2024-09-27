locals {
  http_echo = {
    loadbalancer = {
      tags = join(",",
        concat(
          [
            for key, value in var.tags :
            "${key}=${value}"
          ],
          [
            "ApiGateway=owned",
          ]
        )
      )
    }
  }
}

resource "helm_release" "http_echo" {
  namespace = "http-echo"
  name      = "http-echo"

  chart = "${path.module}/files/helm_charts/http-echo"

  create_namespace = true
  values = [
    yamlencode({
      replicaCount = 2
      topologySpreadConstraints = [
        {
          maxSkew = 1
          whenUnsatisfiable = "DoNotSchedule"
          topologyKey = "kubernetes.io/hostname"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/name" = "http-echo"
            }
            matchLabelKeys = [
              "pod-template-hash",
            ]
          }
        },
      ]
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-name"                              = "${var.prefix}eks-http-echo"
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"                   = "instance"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internal"
          "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags"          = local.http_echo.loadbalancer.tags
          "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol"              = "http"
          "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path"                  = "/health"
          "service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval"              = "30"
          "service.beta.kubernetes.io/aws-load-balancer-target-node-labels"                = "custom/nlb-loadbalancer=true"
        }
      }
    }),
  ]
}
