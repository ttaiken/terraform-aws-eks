//data.aws_eks_cluster.main.endpoint
// enable oidc : allow k8s to manage aws role.
resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.main.certificates[0].sha1_fingerprint]
  //url             = aws_eks_cluster.cluster.identity.0.oidc.0.issuer
  url               = data.aws_eks_cluster.main.identity.0.oidc.0.issuer

}

// from the role, k8s can create lb by the role(eksctl get iamserviceaccount --cluster cls-name)
module "lb_role" {
  depends_on = [module.eks-cluster]
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "role_lb_iamserviceaccount_${local.cls_name}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      // provider_arn               = module.eks.oidc_provider_arn
      provider_arn               = aws_iam_openid_connect_provider.main.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}


resource "kubernetes_service_account" "service-account" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
        "app.kubernetes.io/name"= "aws-load-balancer-controller"
        "app.kubernetes.io/component"= "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}



resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account , null_resource.eks_patch
  ]

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  //set {
  //  name  = "image.repository"
  //  value = "602401143452.dkr.ecr.eu-west-2.amazonaws.com/amazon/aws-load-balancer-controller"
  //}

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "clusterName"
    value = local.cls_name 
  }
}
