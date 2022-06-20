# export ACCOUNT_ID=918000919743
# export NAME=role-kubectl-eks-byron
# ROLE="    - rolearn: arn:aws:iam::$ACCOUNT_ID:role/$NAME\n      useurname: aws\n      grops:\n        - system:masters"
# kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > ./aws-auth-patch.yml
# kubectl patch configmap/aws-auth -n kube-system --patch "$(cat ./aws-auth-patch.yml)"
resource "null_resource" "prepare_sh" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command = "chmod a+x ./template/scripts/*.sh"
    working_dir = "${path.module}"

  }
  depends_on = [module.lb_role]
}

resource "null_resource" "configmap_patch" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command = "./template/scripts/configmap_patch.sh -r ${aws_iam_role.kubectl.arn} -a ${local.role_for_kubect}"
    working_dir = "${path.module}"

  }
  depends_on = [module.lb_role,null_resource.prepare_sh]
}



# resource "kubernetes_config_map" "aws-auth" {
#   data = {
#     "mapRoles" = <<EOT
# - rolearn: ${data.aws_eks_cluster.main.role_arn}
#   username: system:node:{{SessionName}}
#   groups:
#     - system:bootstrappers
#     - system:nodes
#     - system:node-proxier
# # Add as below 
# - rolearn: ${aws_iam_role.kubectl.arn}
#   username:  ${local.role_for_kubect}
#   groups: # REF: https://kubernetes.io/ja/docs/reference/access-authn-authz/rbac/
#     - system:masters
# EOT
#   }

#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }
# }






# prepare fargateprofile
resource "aws_eks_fargate_profile" "test_app" {
  cluster_name           = data.aws_eks_cluster.main.name
  fargate_profile_name   = "fp01-byron"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
  subnet_ids             = flatten([module.vpc.private_subnets])

  selector {
    namespace = "byron-ns"
  }

}

#=========================#
# CodeBuild - 1.gradle build 
#=========================#

resource "aws_codebuild_project" "buildGradle" {

  name         = "build-gradle-${local.app_name}"
  service_role = aws_iam_role.build.arn
  artifacts {
    type = "CODEPIPELINE"
    // type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
  }
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspecGradle.yml"
  }
}

#=========================#
# CodeBuild - 2."docker build" and "docker push"
#=========================#
resource "aws_codebuild_project" "buildDocker" {

  name         = "build-docker-${local.app_name}"
  service_role = aws_iam_role.build.arn
  artifacts {
    type = "CODEPIPELINE"
    // type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name = "IMAGE_REPO_NAME"
      value = "ecr-byron-aucnet"
  
    }
    
  }
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspecDocker.yml"
  }
}

#=========================#
# CodeBuild - 3."Deploy app by "kubectl apply -f"
#=========================#
resource "aws_codebuild_project" "deployTestApp" {
  depends_on = [aws_iam_role_policy.test_policy]
  name         = "deploy-testapp-${local.app_name}"
  service_role = aws_iam_role.build.arn
  artifacts {
    type = "CODEPIPELINE"
    // type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      //data "aws_eks_cluster" "main"
      name = "EKS_KUBECTL_ROLE_ARN"
      //value = data.aws_eks_cluster.main.role_arn
      value = aws_iam_role.kubectl.arn
    }
    environment_variable {
      name = "EKS_KUBECTL_ROLE_Alias"
      value = "${local.role_for_kubect}"
    }
    environment_variable {
      name = "EKS_CLUSTER_NAME"
      value = data.aws_eks_cluster.main.name
    }
  }
  source {
    type = "CODEPIPELINE"
    buildspec = "buildspecEKS.yml"
  }
}

#=========================#
# CodePipeline - Pipeline #
#=========================#
resource "aws_codepipeline" "pipeline01" {
  depends_on = [
    helm_release.lb
  ]
  name = "demo-pipeline01"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    type = "S3"
    location = aws_s3_bucket.codepipeline.bucket
  }

  stage {
    name = "Source"

    action {
      name = "GradleSource"
      category = "Source"
      owner = "AWS"
      provider = "CodeCommit"
      version = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = "java-byron-aucnet"
        BranchName = "master"
        PollForSourceChanges = "true"
      }
    }
  }

  stage {
    name = "BuildGradle"

    action {
      name = "BuildGradle"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      input_artifacts = ["source_output"]
      output_artifacts = ["build_gradle_output"]
      version = "1"

      configuration = {
        ProjectName = aws_codebuild_project.buildGradle.name
      }
    }
  }

  stage {
    name = "BuildDocker"

    action {
      name = "BuildDocker"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      input_artifacts = ["build_gradle_output"]
      output_artifacts = ["build_docker_output"]
      version = "1"

      configuration = {
        ProjectName = aws_codebuild_project.buildDocker.name
      }
    }
  }

    stage {
    name = "DeployEksApp"

    action {
      name = "DeployTestApp"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      input_artifacts = ["build_docker_output"]
      output_artifacts = ["Deploy_app_output"]
      version = "1"

      configuration = {
        ProjectName = aws_codebuild_project.deployTestApp.name
      }
    }
  }

}