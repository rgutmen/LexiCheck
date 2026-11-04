terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

resource "aws_kms_key" "db" {
  description         = "${var.name} database encryption"
  enable_key_rotation = true
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "Postgres, reachable only from the API tasks"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "from_api" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = var.client_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_parameter_group" "this" {
  name   = var.name
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }
}

# RDS generates and rotates the master password in Secrets Manager;
# it never appears in Terraform state or variables.
resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = var.max_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.db.arn

  db_name                       = "lexicheck"
  username                      = "lexi_admin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.db.arn

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  backup_retention_period         = var.backup_retention_days
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = !var.deletion_protection
  final_snapshot_identifier       = var.deletion_protection ? "${var.name}-final" : null
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.db.arn
  enabled_cloudwatch_logs_exports = ["postgresql"]
  auto_minor_version_upgrade      = true
  apply_immediately               = false
}
