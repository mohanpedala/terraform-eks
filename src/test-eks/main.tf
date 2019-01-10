### This data source is included for ease of sample architecture deployment ###
data "aws_availability_zones" "available" {}

### Network Start ###
resource "aws_vpc" "eks-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = "${
    map(
      "Name", "${var.tag-name}",
      "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

resource "aws_subnet" "eks-subnet" {
  count = 2

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.eks-vpc.id}"

  tags = "${
    map(
      "Name", "${var.tag-name}",
      "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

resource "aws_internet_gateway" "eks-gateway" {
  vpc_id = "${aws_vpc.eks-vpc.id}"

  tags {
    Name = "${var.tag-name}"
  }
}

resource "aws_route_table" "eks-route-table" {
  vpc_id = "${aws_vpc.eks-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.eks-gateway.id}"
  }
}

resource "aws_route_table_association" "eks-route-table-association" {
  count = 2

  subnet_id      = "${aws_subnet.eks-subnet.*.id[count.index]}"
  route_table_id = "${aws_route_table.eks-route-table.id}"
}

### Network End ###

### IAM Start ###

### EKS Master cluster IAM Role Start ###
resource "aws_iam_role" "eks-master-iam-role" {
  name        = "${var.cluster-name}"
  description = "Allows EKS to manage clusters on your behalf."

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

resource "aws_iam_role_policy_attachment" "eks-master-iam-role-eksclusterpolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-master-iam-role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-master-iam-role-eksservicepolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-master-iam-role.name}"
}

### EKS Master cluster IAM Role End ###
### EKS worker nodes IAM role Start ###
resource "aws_iam_role" "eks-node-iam-role" {
  name = "${var.cluster-name}-node"

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

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.eks-node-iam-role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.eks-node-iam-role.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.eks-node-iam-role.name}"
}

resource "aws_iam_instance_profile" "eks-node" {
  name = "${var.cluster-name}-node"
  role = "${aws_iam_role.eks-node-iam-role.name}"
}

### EKS worker nodes IAM role End ###
### IAM End ###

#### Security group End ####
### EKS Master Security Group Start ###
resource "aws_security_group" "eks-sg" {
  name        = "${var.cluster-name}"
  description = "EKS master communicating with worker nodes"
  vpc_id      = "${aws_vpc.eks-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.tag-name}"
  }
}

# #### Security group rule Start ####
# # OPTIONAL: Allow inbound traffic from your On-Prem external IP
# resource "aws_security_group_rule" "${var.env}-ingress-onprem-https" {
#   cidr_blocks       = ["x.x.x.x/32"]
#   description       = "Allow On-Prem machine to communicate with the cluster API Server"
#   from_port         = 443
#   protocol          = "tcp"
#   security_group_id = "${aws_security_group.eks-sg.id}"
#   to_port           = 443
#   type              = "ingress"
# }

### EKS Master Security Group End ###
### EKS Node Security Group Start ###
resource "aws_security_group" "eks-node-sg" {
  name        = "${var.cluster-name}-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.eks-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
      map(
        "Name", "${var.tag-name}",
        "kubernetes.io/cluster/${var.cluster-name}", "owned",
      )
    }"
}

resource "aws_security_group_rule" "eks-node-ingress-self" {
  description              = "Establish/Allow node communication between each other"
  from_port                = "0"
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.eks-node-sg.id}"
  source_security_group_id = "${aws_security_group.eks-node-sg.id}"
  to_port                  = "65535"
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-node-ingress_cluster" {
  description              = "Allow worker kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-node-sg.id}"
  source_security_group_id = "${aws_security_group.eks-node-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}

### EKS Node Security Group End ###

### Worker Node Access to EKS Master Cluster Start ###

resource "aws_security_group_rule" "eks-master-ingress-node-https" {
  description              = "Alloiw pods to communicate with eks cluster API server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-sg.id}"
  source_security_group_id = "${aws_security_group.eks-node-sg.id}"
  to_port                  = 443
  type                     = "ingress"
}

### Worker Node Access to EKS Master Cluster End ###

#### Security group End ####

### Start EKS Cluster

resource "aws_eks_cluster" "eks-cluster" {
  name     = "${var.cluster-name}"
  role_arn = "${aws_iam_role.eks-master-iam-role.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.eks-sg.id}"]
    subnet_ids         = ["${aws_subnet.eks-subnet.*.id}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.eks-master-iam-role-eksclusterpolicy",
    "aws_iam_role_policy_attachment.eks-master-iam-role-eksservicepolicy",
  ]
}

### End EKS Cluster

### Fetch the latest Amazon Machine Image (AMI) that Amazon provides with an EKS compatible Kubernetes baked in ###
data "aws_ami" "eks-node" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-1.11-v*"] # AMI Name: amazon-eks-node-1.11-v20181210 AMI ID: ami-094fa4044a2a3cf52
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

### Create Launch Configuration Start ###
data "aws_region" "current" {}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# Ref: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  eks-node-userdata = <<USERDATA
  #!/bin/bash
  set -o xtrace
  /etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks-cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "eks-launch-configuration" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.eks-node.name}"
  image_id                    = "${data.aws_ami.eks-node.id}"
  instance_type               = "${var.instance-type}"
  name_prefix                 = "${var.cluster-name}-node"
  security_groups             = ["${aws_security_group.eks-node-sg.id}"]
  user_data                   = "${base64encode(local.eks-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

### Launch Configuration End ###

### Autoscaling Creation Start ###
resource "aws_autoscaling_group" "eks-asg" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.eks-launch-configuration.id}"
  max_size             = 2
  min_size             = 1
  name                 = "${var.tag-name}-eks"
  vpc_zone_identifier  = ["${aws_subnet.eks-subnet.*.id}"]

  tag {
    key                 = "Name"
    value               = "${var.tag-name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

### Autoscaling Creation End ###

################### NEED A DIFFERENT APPROACH ########################

# IAM Role authentication ConfigMap from Terraform configuration
# This configuration helps to join worker nodes with EKS cluster

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH

  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: aws-auth
    namespace: kube-system
  data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks-node-iam-role.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}

output "config_map_aws_auth" {
  value = "${local.config_map_aws_auth}"
}
