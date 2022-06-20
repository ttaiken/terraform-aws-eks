locals {
  aws_account         = "918000919743"   # replace policy content
  pj_name             = "byron"
  cls_name            = "eks-${local.pj_name}"
  app_name            = "spring01-${local.cls_name}"
  cls_version = "1.22"
  region          = "ap-northeast-1"
  role_for_kubect  = "u01kubectl"

  tags = {
    Example    = local.cls_name
    tga2 = "test"
  }

  // for codebuild
  IAM_POLICY_ARN_AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

// used by aws eks moudle
provider "aws" {
        region = local.region

}

// used by aws eks moudle
provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
  //load_config_file       = false
  //load_config_file       = false
  // version                = "~> 1.10"
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

//terraform {
//  required_version = "= 2.4.1"
//  required_providers {
//    aws = {
//      source  = "hashicorp/aws"
//      version = "~> 4.17.1"
//    }
//  }
//}


