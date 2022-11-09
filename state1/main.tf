terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet1" {
vpc_id                  = aws_vpc.myvpc.id
cidr_block              = "10.0.1.0/24"
availability_zone       = "us-east-1a"
map_public_ip_on_launch = true
tags = {
   Name = "public subnet a1"
 }
}
resource "aws_subnet" "private_subnet1" {
vpc_id                 = aws_vpc.myvpc.id
cidr_block             = "10.0.2.0/24"
availability_zone      = "us-east-1a"
tags = {
  Name = "private subnet a1"
  }
}
resource "aws_subnet" "public_subnet2" {
vpc_id                  = aws_vpc.myvpc.id
cidr_block              = "10.0.3.0/24"
availability_zone       = "us-east-1b"
map_public_ip_on_launch = true
tags = {
   Name = "public subnet a2"
 }
}
resource "aws_subnet" "private_subnet2" {
vpc_id                 = aws_vpc.myvpc.id
cidr_block             = "10.0.4.0/24"
availability_zone      = "us-east-1b"
tags = {
  Name = "private subnet a2"
  }
}

resource "aws_internet_gateway" "igw" {
   vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Route Table"
  }
}
resource "aws_route_table_association" "rt_association" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "rt_association1" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_iam_role" "eks" {
  name="eks_role"
  assume_role_policy =  <<EOF
  {
    "Version": "2012-10-17",
    "Statement":[
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role=aws_iam_role.eks.name
}
resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role=aws_iam_role.eks.name
}

resource "aws_eks_cluster" "cluster1" {
  name = "cluster1"
  role_arn = aws_iam_role.eks.arn
  vpc_config {
    subnet_ids=[aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]
  }
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role=aws_iam_role.eks.name
}
resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role=aws_iam_role.eks.name
}
resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role=aws_iam_role.eks.name
}

resource "aws_eks_node_group" "sre-pool-main" {
  cluster_name    = aws_eks_cluster.cluster1.name
  node_group_name = "sre-pool-main"
  node_role_arn   = aws_iam_role.eks.arn
  subnet_ids=[aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]
  instance_types = ["t2.micro"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_node_group" "sre-pool-sec" {
  cluster_name    = aws_eks_cluster.cluster1.name
  node_group_name = "sre-pool-sec"
  node_role_arn   = aws_iam_role.eks.arn
  subnet_ids=[aws_subnet.public_subnet1.id,aws_subnet.public_subnet2.id]
  instance_types = ["t2.micro"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}