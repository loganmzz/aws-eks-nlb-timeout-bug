locals {
  nodes_security_group_rules = {
    from_cluster = {
      type     = "ingress"
      protocol = "tcp"
      ports    = [443, 443]
      source   = aws_security_group.eks_cluster.id
    }
    webhook = {
      type     = "ingress"
      protocol = "tcp"
      ports    = [9443, 9443]
      source   = aws_security_group.eks_cluster.id
    }
    kubelet = {
      type     = "ingress"
      protocol = "tcp"
      ports    = [10250, 10250]
      source   = aws_security_group.eks_cluster.id
    }
    coredns_tcp = {
      type     = "ingress"
      protocol = "tcp"
      ports    = [53, 53]
      self     = true
    }
    coredns_udp = {
      type     = "ingress"
      protocol = "udp"
      ports    = [53, 53]
      self     = true
    }
    egress_all = {
      type        = "egress"
      protocol    = "all"
      ports       = [0, 0]
      cidr_blocks = ["0.0.0.0/0"]
    }
    ephemeral = {
      type     = "ingress"
      protocol = "tcp"
      ports    = [1025, 65535]
      self     = true
    }
  }
}

## IAM
resource "aws_iam_instance_profile" "eks_nodes" {
  name = "${var.prefix}eks-nodes"
  role = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role" "eks_nodes" {
  name = "${var.prefix}eks-nodes"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_nodes-amazoneks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes-amazoneks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes-amazonec2_containerregistry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes-ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_policy" "eks_nodes_cloudwatch" {
  name = "${var.prefix}eks-nodes-cloudwatch"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:TagResource",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "eks_nodes-cloudwatch" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = aws_iam_policy.eks_nodes_cloudwatch.arn
}

## Network
resource "aws_security_group" "eks_nodes" {
  name   = "${var.prefix}eks-nodes"
  vpc_id = var.vpc

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "eks_nodes" {
  for_each = local.nodes_security_group_rules

  security_group_id = aws_security_group.eks_nodes.id
  description       = each.key
  type              = each.value.type

  protocol  = each.value.protocol
  from_port = each.value.ports[0]
  to_port   = each.value.ports[1]

  self                     = lookup(each.value, "self", null)
  source_security_group_id = lookup(each.value, "source", null)
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
}

## Compute

data "aws_ssm_parameter" "bottlerocket_image_id" {
  name = "/aws/service/bottlerocket/aws-k8s-${local.cluster_version}/x86_64/latest/image_id"
}
data "aws_ami" "bottlerocket" {
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.bottlerocket_image_id.value]
  }

  most_recent = true
  owners      = ["amazon"]
}
resource "aws_launch_template" "eks_nodes" {
  name     = "${var.prefix}eks-nodes"
  image_id = data.aws_ami.bottlerocket.id

  user_data = base64encode(templatefile(
    "${path.module}/templates/aws_launch_template.eks_nodes.userdata.toml.tpl",
    {
      cluster_name        = aws_eks_cluster.this.name
      api_server          = aws_eks_cluster.this.endpoint
      cluster_certificate = aws_eks_cluster.this.certificate_authority[0].data
    }
  ))

  vpc_security_group_ids = [aws_security_group.eks_nodes.id]
  instance_type          = "t3.large"
  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp3"
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdb"
    ebs {
      volume_type = "gp3"
    }
  }

  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume", "network-interface"])
    content {
      resource_type = tag_specifications.key
      tags = merge(
        var.tags,
        {
          ManagedBy                                            = "${var.prefix}eks-nodes"
          "kubernetes.io/cluster/${aws_eks_cluster.this.name}" = "owned"
        }
      )
    }
  }

  metadata_options {
    http_put_response_hop_limit = 2
  }
}

## EKS
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.prefix}default"

  node_role_arn = aws_iam_role.eks_nodes.arn
  subnet_ids    = var.subnets.private
  capacity_type = "SPOT"
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 2
  }

  labels = {
    "custom/nlb-loadbalancer" = "true"
  }
}
