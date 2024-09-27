provider "aws" {
  region              = var.aws.region
  allowed_account_ids = [var.aws.account]

  assume_role {
    role_arn = var.aws.role
  }

  default_tags {
    tags = var.aws.tags
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.auth.host
    cluster_ca_certificate = module.eks.auth.cluster_ca_certificate
    token                  = module.eks.auth.token
  }
}
