variable "tags" {
  type = map(string)
}

variable "prefix" {
  type        = string
  description = "Prefix to append to resource names"
}

variable "eks_cluster_name" {
  type = string
}

variable "oidc" {}
