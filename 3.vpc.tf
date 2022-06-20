data "aws_availability_zones" "available" {}

//locals {
//  cluster_name = "education-eks-${random_string.suffix.result}"
//}

//resource "random_string" "suffix" {
//  length  = 8
//  special = false
//}

module "vpc" {
  source                        = "terraform-aws-modules/vpc/aws"
  version                       = "3.11.0"
  name                          = "vpc-eks-aucnet"
  cidr                          = "10.168.0.0/16"
  //azs                           = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  azs                           = data.aws_availability_zones.available.names
  private_subnets               = ["10.168.1.0/24","10.168.3.0/24","10.168.5.0/24"]
  public_subnets                = ["10.168.2.0/24","10.168.4.0/24","10.168.6.0/24"]
  enable_nat_gateway            = true
  single_nat_gateway            = true
  enable_dns_hostnames          = true
  //manage_default_security_group = true
  default_security_group_name   = "sg-eks-byron-vpc"
  
  public_subnet_tags = {
    // "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"               = "1"
  }

  private_subnet_tags = {
    // "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }

//  tags = {
//    "kubernetes.io/cluster/vpc-serverless" = "shared"
//  }

}

