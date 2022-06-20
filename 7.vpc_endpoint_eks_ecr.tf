// https://zenn.dev/samuraikun/articles/0d22699a9878cd

resource "aws_security_group" "vpc_endpoint" {
  name   = "vpcendpoint_eks_ecr"
  //vpc_id = aws_vpc.app_network.id
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    //cidr_blocks = [aws_vpc.app_network.cidr_block]
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  //subnet_ids          = aws_subnet.app_private[*].id
  subnet_ids =flatten([module.vpc.private_subnets])
  //flatten([module.vpc.private_subnets])
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}
