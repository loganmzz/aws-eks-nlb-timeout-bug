/**
 * Minimum, Complete and Verifiable Example
 * ===
 *
 * Demonstrates networking issue in AWS EKS when calling from Pod another Pod through AWS NLB.
 */

module "network" {
  source = "./modules/network"

  prefix = var.prefix
}

module "eks" {
  source = "./modules/eks"

  tags   = var.aws.tags
  prefix = var.prefix
  vpc    = module.network.vpc.id
  subnets = {
    for visibility in ["public", "private"] :
    "${visibility}" => [
      for key, subnet in module.network.subnets : subnet.resource.id if subnet.purpose == "k8s" && subnet.kind == visibility
    ]
  }
  access_entries = var.eks_access_entries
}

module "kubernetes" {
  source = "./modules/kubernetes"

  tags             = var.aws.tags
  prefix           = var.prefix
  eks_cluster_name = module.eks.cluster_name
  oidc             = module.eks.oidc
}
