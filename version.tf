terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      version = "~> 5"
    }
    helm = {
      version = "~> 2"
    }
    http = {
      version = "~> 3"
    }
    tls = {
      version = "~> 4"
    }
  }
}
