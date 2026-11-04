terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.60"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

data "aws_region" "current" {}

locals {
  name = "lexicheck-${var.environment}"
  prod = var.environment == "prod"
}

module "network" {
  source             = "../network"
  name               = local.name
  region             = data.aws_region.current.name
  cidr               = var.vpc_cidr
  az_count           = local.prod ? 3 : 2
  single_nat_gateway = !local.prod
}

module "service" {
  source              = "../service"
  name                = local.name
  environment         = var.environment
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  app_subnet_ids      = module.network.app_subnet_ids
  certificate_arn     = var.alb_certificate_arn
  cpu                 = var.task_cpu
  memory              = var.task_memory
  min_tasks           = var.min_tasks
  max_tasks           = var.max_tasks
  spot_weight         = local.prod ? 0 : 3
  db_host             = module.database.endpoint
  db_name             = module.database.db_name
  db_secret_arn       = module.database.master_secret_arn
  db_kms_key_arn      = module.database.kms_key_arn
  log_retention_days  = local.prod ? 365 : 14
  deletion_protection = local.prod
}

module "database" {
  source                   = "../database"
  name                     = local.name
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.data_subnet_ids
  client_security_group_id = module.service.task_security_group_id
  instance_class           = var.db_instance_class
  multi_az                 = local.prod
  backup_retention_days    = local.prod ? 30 : 3
  deletion_protection      = local.prod
}

module "edge" {
  source              = "../edge"
  providers           = { aws = aws, aws.us_east_1 = aws.us_east_1 }
  name                = local.name
  api_origin_domain   = module.service.alb_dns_name
  api_origin_https    = var.alb_certificate_arn != null
  origin_secret       = module.service.origin_secret
  domain_names        = var.domain_names
  acm_certificate_arn = var.cloudfront_certificate_arn
  price_class         = local.prod ? "PriceClass_All" : "PriceClass_100"
  deletion_protection = local.prod
}

module "alarms" {
  source                  = "../alarms"
  name                    = local.name
  alb_arn_suffix          = module.service.alb_arn_suffix
  target_group_arn_suffix = module.service.target_group_arn_suffix
  db_identifier           = module.database.identifier
  alert_emails            = var.alert_emails
}

# ---------------------------------------------------------------- CI deploy role
# GitHub Actions assumes this role via OIDC (no long-lived keys). The trust policy is
# pinned to this repo's GitHub *environment*, so only jobs gated by that environment's
# protection rules can deploy here.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${local.name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload",
      "ecr:DescribeImages", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart",
    ]
    resources = [module.service.ecr_repository_arn]
  }
  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition",
      "ecs:UpdateService", "ecs:ListTaskDefinitions",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = module.service.role_arns
  }
  statement {
    sid       = "SiteUpload"
    actions   = ["s3:ListBucket", "s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = [module.edge.site_bucket_arn, "${module.edge.site_bucket_arn}/*"]
  }
  statement {
    sid       = "Invalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [module.edge.distribution_arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
