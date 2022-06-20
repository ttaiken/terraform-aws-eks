
resource "null_resource" "kubectl_update" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${data.aws_eks_cluster.main.name} --region ap-northeast-1"
  }
  depends_on = [module.eks-cluster]
}

resource "null_resource" "eks_patch" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command = "./template/scripts/eks_patch.sh"
    working_dir = "${path.module}"

  }
  depends_on = [null_resource.kubectl_update]
}
