####################################################
# CodePipeLine - S3 Artifact Store
####################################################
resource "aws_s3_bucket" "codepipeline" {
  bucket = "s3-codepipeline-${local.app_name}"
  //acl = "private"

  // enable terraform to delete the s3
  force_destroy = true  
}

