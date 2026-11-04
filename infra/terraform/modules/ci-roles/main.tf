# Roles GitHub Actions assumes through OIDC to run Terraform. No AWS keys are
# stored in GitHub: a workflow gets short-lived credentials only if its token
# comes from this repo, and (for apply) from the protected `infra` environment.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  oidc = "token.actions.githubusercontent.com"
  # GitHub's OIDC `sub` starts with this. New repos use the immutable form with
  # numeric IDs (repo:owner@123/name@456), older ones repo:owner/name.
  subject = coalesce(var.github_oidc_subject_prefix, "repo:${var.github_repository}")
}

# ---------------------------------------------------------------- plan (read-only)
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Any branch or PR in this repo may plan; planning cannot change anything.
    condition {
      test     = "StringLike"
      variable = "${local.oidc}:sub"
      values   = ["${local.subject}:*"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "${var.name}-github-tf-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan also writes the state lockfile (use_lockfile), so it needs to put and delete it.
data "aws_iam_policy_document" "plan_state" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

# ---------------------------------------------------------------- apply (admin, gated)
data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only jobs running in the `infra` GitHub environment, which is restricted
    # to the main branch, can create or destroy infrastructure.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:sub"
      values   = ["${local.subject}:environment:infra"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = "${var.name}-github-tf-apply"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

# Terraform creates IAM roles, VPCs, RDS, CloudFront and WAF, so a narrow policy
# would just be AdministratorAccess spelled out. The OIDC trust above is the guard.
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
