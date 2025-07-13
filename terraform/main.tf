terraform {
    backend "s3" {
    bucket         = "craftapp-state-bucket"
    key            = "v2-test/terraform.tfstate"
    region         = "eu-north-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# _____________________Creating s3 bucket___________________
# Create S3 Bucket for Static Files
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.project}-${var.region}-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true
    tags = {
    Name        = "${var.project}-bucket-${random_id.bucket_suffix.hex}"
    Project     = var.project
  }
}

# Modern versioning configuration
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Modern website configuration
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Modern ACL configuration (private by default)
resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${aws_s3_bucket.s3_bucket.bucket}"
}

# S3 Bucket Policy (Allow CloudFront Only)
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.oai.id}"
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.s3_bucket.arn}/*"
      }
    ]
  })
}

# IAM Policy for Backend Access
resource "aws_iam_policy" "backend_s3_access" {
  name        = "${var.project}-backend-s3-access"
  description = "Allows backend service to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = [
          aws_s3_bucket.s3_bucket.arn,
          "${aws_s3_bucket.s3_bucket.arn}/*"
        ]
      }
    ]
  })
}
# Create the CloudFront function with lifecycle management
resource "aws_cloudfront_function" "append_html_extension" {
  name    = "AppendHtmlExtension"
  runtime = "cloudfront-js-1.0"
  comment = "Appends .html extension to requests for Next.js static export"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // If uri does not contain a '.' (no extension) and does not end with '/'
    if (!uri.includes('.') && !uri.endsWith('/')) {
        request.uri = uri + '.html';
    }
    return request;
}
EOF

  lifecycle {
    # Prevent accidental deletion of the function
    prevent_destroy = true
    
    # Ignore changes to the code if you want manual updates outside Terraform
    # ignore_changes = [code]
  }
}

# CloudFront Distribution with enhanced tags
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.s3_bucket.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.s3_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.append_html_extension.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  tags = {
    Name        = "${var.project}-cloudfront-${random_id.bucket_suffix.hex}-cdn-distributio"
    Project     = var.project
  }
  
  depends_on = [
    aws_s3_bucket.s3_bucket,
    aws_cloudfront_function.append_html_extension
  ]
}

# _____________________Creating RDS-database____________________
# Get the default security group for your VPC
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = "vpc-0297cd44f118eae2f"  # Replace with your actual VPC ID
}

resource "aws_security_group_rule" "allow_postgres_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.default.id        # <-- RDS SG
  source_security_group_id = var.ec2_security_group_id  # <-- your EC2 SG ID
}
resource "aws_db_instance" "my_database" {
  identifier             = "${var.project}-${var.region}-database-${random_id.bucket_suffix.hex}"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres15"
  skip_final_snapshot    = true
  publicly_accessible    = true  # Changed to true for public access
  vpc_security_group_ids = [data.aws_security_group.default.id]
  multi_az               = false
  tags = {
    Name = "${var.project}-database-${random_id.bucket_suffix.hex}"
  }

}

# _____________________Data Sources for Secrets___________________
#data "aws_secretsmanager_secret" "existing_credentials" {
#  arn = "arn:aws:secretsmanager:us-east-1:135808921133:secret:prod/aws/credentials-1czvrt"
#}

#data "aws_secretsmanager_secret_version" "current_creds" {
 # secret_id = data.aws_secretsmanager_secret.existing_credentials.id
#}
data "aws_secretsmanager_secret" "access_key_id" {
  name = "prod/aws/access_key_id"
}

data "aws_secretsmanager_secret" "secret_access_key" {
  name = "prod/aws/secret_access_key"
}

data "aws_secretsmanager_secret_version" "access_key_id" {
  secret_id = data.aws_secretsmanager_secret.access_key_id.id
}

data "aws_secretsmanager_secret_version" "secret_access_key" {
  secret_id = data.aws_secretsmanager_secret.secret_access_key.id
}

# _____________________IAM Role and Policies___________________
resource "aws_iam_role" "apprunner_execution_role" {
  name = "${var.project}-apprunner-exec-role-${random_id.bucket_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy" "apprunner_secrets_access" {
  name = "apprunner-secrets-access"
  role = aws_iam_role.apprunner_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Effect = "Allow",
        Resource = [
          data.aws_secretsmanager_secret.access_key_id.arn,
          data.aws_secretsmanager_secret.secret_access_key.arn
        ]
      }
    ]
  })
}

#resource "aws_iam_role_policy_attachment" "apprunner_secrets_access" {
#  role       = aws_iam_role.apprunner_execution_role.name
#  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
#}

resource "aws_iam_role_policy_attachment" "apprunner_s3_access" {
  role       = aws_iam_role.apprunner_execution_role.name
  policy_arn = aws_iam_policy.backend_s3_access.arn
}

# _____________________Creating AppRunner Service___________________
resource "aws_apprunner_service" "backend_service" {
  service_name = "${var.project}-backend-${random_id.bucket_suffix.hex}"

  source_configuration {
    authentication_configuration {
      connection_arn = "arn:aws:apprunner:us-east-1:135808921133:connection/new-connection/45c0ab0285b64f8abd68e04dde58f1ff"
    }

    auto_deployments_enabled = true

    code_repository {
      repository_url = var.repository_url
      source_code_version {
        type  = "BRANCH"
        value = var.branch
      }

      code_configuration {
        configuration_source = "API"
        code_configuration_values {
          runtime        = "PYTHON_311"
          build_command = "chmod +x terraform/build.sh && chmod +x terraform/start.sh && ./terraform/build.sh"
          start_command = "./terraform/start.sh"
          port           = 8080
          runtime_environment_variables = {
            NODE_ENV        = "production"
            FRONTEND_DOMAIN  = aws_cloudfront_distribution.cdn.domain_name
            S3_BUCKET_NAME  = aws_s3_bucket.s3_bucket.bucket
            DB_USER           = aws_db_instance.my_database.username
            DB_PASSWORD       = var.db_password
            DB_HOST           = aws_db_instance.my_database.address
            DB_NAME           = aws_db_instance.my_database.db_name
            DB_PORT           = "5432"
            DB_SSL            = "true"
            AWS_REGION        = var.region
            S3_BUCKET_NAME  = aws_s3_bucket.s3_bucket.bucket
            }
            runtime_environment_secrets = {
              AWS_ACCESS_KEY_ID     = data.aws_secretsmanager_secret.access_key_id.arn
              AWS_SECRET_ACCESS_KEY = data.aws_secretsmanager_secret.secret_access_key.arn
            }

        }
      }
    }
  }

  instance_configuration {
    cpu               = "1024"
    memory            = "2048"
    instance_role_arn = aws_iam_role.apprunner_execution_role.arn  # Explicitly set the IAM role
  }

  tags = {
    Name        = "${var.project}-backend-${random_id.bucket_suffix.hex}"
    Project     = var.project
    Environment = "production"
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 5
  }

  depends_on = [
    aws_cloudfront_distribution.cdn,
    aws_s3_bucket.s3_bucket,
    aws_db_instance.my_database,
    aws_iam_role_policy_attachment.apprunner_s3_access
  ]
}
# Output CloudFront URL and Distribution ID
output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}
output "s3_bucket_name" {
  value = aws_s3_bucket.s3_bucket.bucket
}

output "apprunner_service_url" {
  value       = aws_apprunner_service.backend_service.service_url
}

output "rds_endpoint" {
  value = aws_db_instance.my_database.endpoint
}

output "rds_username" {
  value = aws_db_instance.my_database.username
}
