

module "eks-cluster" {
  //tags = local.tags
  source                        = "terraform-aws-modules/eks/aws"
  version                       = "17.1.0"
  cluster_name                  = local.cls_name
  // check default version?
  cluster_version               = "1.22"
  subnets                     = flatten([module.vpc.public_subnets,module.vpc.private_subnets])
  
  cluster_delete_timeout        = "30m"
  cluster_iam_role_name         = "role-eks-cluster-byron" 
  //cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  //cluster_log_retention_in_days = 7
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  //cluster_addons = {
  //  coredns = {
  //    resolve_conflicts = "OVERWRITE"
  //  }
  //  kube-proxy = {}
  //  vpc-cni = {
  //    resolve_conflicts = "OVERWRITE"
  //  }
  //}


  vpc_id = module.vpc.vpc_id
  fargate_pod_execution_role_name = aws_iam_role.fargate_pod_execution_role.name

  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
        },
        {
          namespace = "default"
        //  labels = {
        //    WorkerType = "fargate"
        //  }
        }
      ]
      //subnet_ids = flatten([module.vpc.private_subnets])
      subnets = flatten([module.vpc.private_subnets])
      //tags = {
      //  Owner = "default"
      //}

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }
  }


}


data "aws_eks_cluster" "main" {
  name = module.eks-cluster.cluster_id
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks-cluster.cluster_id
}

data "tls_certificate" "main" {
  //url = aws_eks_cluster.cluster.identity.0.oidc.0.issuer
  url = data.aws_eks_cluster.main.identity.0.oidc.0.issuer
}

