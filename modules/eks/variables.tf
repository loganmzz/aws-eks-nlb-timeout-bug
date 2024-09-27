variable "tags" {
  type = map(string)
}

variable "prefix" {
  type        = string
  description = "Prefix to append to resource names"
}

variable "vpc" {
  type = string
}

variable "subnets" {
  type = object({
    public  = list(string)
    private = list(string)
  })
}

variable "access_entries" {
  type = map( // principal_arn
    object({
      user   = optional(string)       // user_name
      groups = optional(list(string)) // kubernetes_groups
    })
  )
  description = "Set EKS IAM auth & privilegies. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry."
}
