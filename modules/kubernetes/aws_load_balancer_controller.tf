locals {
  aws_load_balancer_controller = {
    version       = "v2.8.3"
    chart_version = "1.8.3"
  }
}

data "http" "aws_load_balancer_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${local.aws_load_balancer_controller.version}/docs/install/iam_policy.json"
  request_headers = {
    Accept = "application/json"
  }
}
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.prefix}aws-load-balancer-controller"
  policy      = tostring(data.http.aws_load_balancer_controller_policy.response_body)
  description = "Load Balancer Controller add-on for EKS"
}

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [var.oidc.arn]
      type        = "Federated"
    }
  }
}
resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.prefix}aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller.json
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_policy" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "helm_release" "aws_load_balancer_controller" {
  name          = "aws-load-balancer-controller"
  repository    = "https://aws.github.io/eks-charts"
  chart         = "aws-load-balancer-controller"
  version       = local.aws_load_balancer_controller.chart_version
  wait          = false
  force_update  = false
  recreate_pods = true
  namespace     = "kube-system"
  values = [
    templatefile(
      "${path.module}/templates/aws_load_balancer_controller/helm_values.yaml",
      {
        cluster_name         = var.eks_cluster_name
        role_arn             = aws_iam_role.aws_load_balancer_controller.arn
        service_account_name = "aws-load-balancer-controller"
        default_tags         = var.tags
      },
    ),
  ]
}
