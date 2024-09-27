locals {
  cluster_name    = "${var.prefix}main"
  cluster_version = "1.30"

  cluster_addons = {
    coredns = {
      version = "v1.11.1-eksbuild.4"
      configuration = {
        replicaCount = 1
      }
    }
    kube-proxy = {
      version = "v1.29.3-eksbuild.5"
    }
    vpc-cni = {
      version = "v1.16.0-eksbuild.1"
      configuration = {
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      }
    }
    aws-ebs-csi-driver = {
      version  = "v1.33.0-eksbuild.1"
      role_arn = aws_iam_role.aws_ebs_csi_driver.arn
    }
  }

  cluster_security_group_rules = {
    "from_nodes" = {
      type     = "ingress"
      protocol = "tcp"
      ports    = [443, 443]
      source   = aws_security_group.eks_nodes.id
    }
  }
}

## IAM
resource "aws_iam_role" "eks_cluster" {
  name = "${var.prefix}eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_cluster_amazoneks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_amazoneks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.key

  user_name         = try(each.value.user, null)
  kubernetes_groups = try(each.value.groups, [])
}

## Network
resource "aws_security_group" "eks_cluster" {
  name   = "${var.prefix}eks-cluster"
  vpc_id = var.vpc

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "eks_cluster" {
  for_each = local.cluster_security_group_rules

  security_group_id = aws_security_group.eks_cluster.id
  description       = each.key
  type              = each.value.type

  protocol  = each.value.protocol
  from_port = each.value.ports[0]
  to_port   = each.value.ports[1]

  source_security_group_id = each.value.source
}

## EKS
resource "aws_eks_cluster" "this" {
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_amazoneks_cluster_policy,
    aws_iam_role_policy_attachment.eks_cluster_amazoneks_service_policy,
  ]

  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = local.cluster_version

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
    subnet_ids              = concat(var.subnets.public, var.subnets.private)
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = []
}

resource "aws_eks_addon" "this" {
  for_each = local.cluster_addons

  depends_on = [
    aws_eks_node_group.default,
  ]

  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.key
  addon_version = each.value.version

  configuration_values     = try(jsonencode(each.value.configuration), null)
  service_account_role_arn = try(each.value.role_arn, null)

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

## OIDC
data "tls_certificate" "eks_cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
resource "aws_iam_openid_connect_provider" "eks_cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

## Auth
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}
