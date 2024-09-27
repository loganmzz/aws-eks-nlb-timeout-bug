resource "helm_release" "tester" {
  namespace = helm_release.http_echo.namespace
  name      = "tester"

  chart = "${path.module}/files/helm_charts/tester"

  values = [
    yamlencode({
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
    })
  ]
}
