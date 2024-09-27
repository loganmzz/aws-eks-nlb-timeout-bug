output "auth" {
  value = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "oidc" {
  value = aws_iam_openid_connect_provider.eks_cluster
}