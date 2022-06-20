// 1.For CLuster
// # role create by moudle module.eks-cluster
// 1.1 role for codebuid to run (kubectl apply -f abc.yml)
resource "aws_iam_role" "kubectl" {
  name                  = "role-kubectl-${local.cls_name}"
  force_detach_policies = true

// trust policy
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { 
        "AWS": "arn:aws:iam::${local.aws_account}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}


// 1.2 set inlinepolicy to cluster role add poliy to allow kubectl


resource "aws_iam_role_policy" "test_policy" {
  name = "inlinepolicy_${local.cls_name}"
  //role = split("/",data.aws_eks_cluster.main.role_arn)[1]
  role = aws_iam_role.kubectl.name
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

// 1.3 trust policy
# resource "aws_iam_policy" "eks_trust" {
#   name        = "trustpolicy_${local.cls_name}"
#   description = "allow assuming eks_cluster role"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect   = "Allow",
#         Action   = "sts:AssumeRole",
#         Resource = "arn:aws:iam::${local.aws_account}:role/${data.aws_eks_cluster.main.role_arn}"
#     }]
#   })
# }



// 2 for fargate pod
resource "aws_iam_role" "fargate_pod_execution_role" {
  name                  = "role-eks-pod-execution-${local.app_name}"
  force_detach_policies = true

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com",
          "eks-fargate-pods.amazonaws.com"
          ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_pod_execution_role.name
}

// 3 for codepipeline
resource "aws_iam_role" "codepipeline" {
  name = "role-codepipeline-${local.app_name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_policy" "codepipeline" {
  policy = file("./template/json/code_pipeline/policy_service_pipeline.json")
}

resource "aws_iam_role_policy_attachment" "attache_pipeline_service" {
  policy_arn = aws_iam_policy.codepipeline.arn
  role       = aws_iam_role.codepipeline.name
}

// 4 for codebuild
resource "aws_iam_role" "build" {
  name = "role-codebuild-${local.app_name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "build_base" {
  name = "Policy-CodeBuildBase-${local.app_name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": ["*"],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.codepipeline.arn}/*"
      ],
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:CreateReportGroup",
        "codebuild:CreateReport",
        "codebuild:UpdateReport",
        "codebuild:BatchPutTestCases",
        "codebuild:BatchPutCodeCoverages"
      ],
      "Resource": [
        "arn:aws:codebuild:ap-northeast-1:${local.aws_account}:report-group/*"
      ]
    }
  ]
}
EOF

}




resource "aws_iam_policy" "sts_eks" {
  name = "Policy-sts-${data.aws_eks_cluster.main.name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole",
                "sts:SetSourceIdentity",
                "sts:AssumeRoleWithSAML",
                "sts:AssumeRoleWithWebIdentity"
            ],
            "Resource": "${aws_iam_role.kubectl.arn}"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "sts:DecodeAuthorizationMessage",
            "Resource": "*"
        }
    ]
}
EOF
}



resource "aws_iam_policy" "build_vpc" {
  name = "Policy-codebuildvpc-${local.app_name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": "arn:aws:ec2:ap-northeast-1:${local.aws_account}:network-interface/*"
    }
  ]
}
EOF
}
resource "aws_iam_policy" "build_ecr_put" {
  name = "Policy-codebuildecr-${local.app_name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ecr:BatchGetImage",
                "ecr:CompleteLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:InitiateLayerUpload",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "build_base_attach" {
  policy_arn = aws_iam_policy.build_base.arn
  role       = aws_iam_role.build.name
}

resource "aws_iam_role_policy_attachment" "sts_eks_attach" {
  policy_arn = aws_iam_policy.sts_eks.arn
  role       = aws_iam_role.build.name
}



resource "aws_iam_role_policy_attachment" "build_vpc_attach" {
  policy_arn = aws_iam_policy.build_vpc.arn
  role       = aws_iam_role.build.name
}

resource "aws_iam_role_policy_attachment" "build_ecr_read" {
  policy_arn = local.IAM_POLICY_ARN_AmazonEC2ContainerRegistryReadOnly
  role       = aws_iam_role.build.name
}
resource "aws_iam_role_policy_attachment" "build_ecr_put" {
  policy_arn = aws_iam_policy.build_ecr_put.arn
  role       = aws_iam_role.build.name
}

resource "aws_iam_role_policy_attachment" "build_kms_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  role       = aws_iam_role.build.name
}
//resource "aws_iam_policy" "build_secret" {
//  name = "Policy-codebuildsecret-${local.app_name}"
//  policy = <<EOF
//{
//    "Version": "2012-10-17",
//    "Statement": [
//      {
//        "Effect": "Allow",
//        "Action": [
//          "ssm:GetParameters"
//        ],
//        "Resource": "arn:aws:ssm:ap-northeast-1:${local.aws_account}:parameter/CodeBuild/*"
//      }
//    ]
//  }
//EOF
//}

//resource "aws_iam_role_policy_attachment" "build_secret_attach" {
  //policy_arn = aws_iam_policy.build_secret.arn
  //role       = aws_iam_role.build.name
//}

//resource "aws_iam_role_policy_attachment" "build_ssm_read" {
//  policy_arn = local.IMA_POLICY_ARN_AmazonSSMReadOnlyAccess
//  role       = aws_iam_role.build.name
//}