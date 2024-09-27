variable "aws" {
  type = object({
    account = string
    region  = string
    role    = string
    tags    = map(string)
  })
}

variable "prefix" {
  type        = string
  description = "Prefix to append to resource names"
}

variable "eks_access_entries" {
  type = map( // principal_arn
    object({
      user   = optional(string)       // user_name
      groups = optional(list(string)) // kubernetes_groups
    })
  )
  description = "Set EKS IAM auth & privilegies. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry. Note: assumed role is automatically added as admin."
  default     = {}
}
