terraform {
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
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "${var.project}-${var.region}-frontend-${random_id.bucket_suffix.hex}"
  force_destroy = true
    tags = {
    Name        = "${var.project}-frontend-bucket-${random_id.bucket_suffix.hex}"
    Project     = var.project
  }
}

# Modern versioning configuration
resource "aws_s3_bucket_versioning" "frontend_versioning" {
  bucket = aws_s3_bucket.frontend_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Modern website configuration
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Modern ACL configuration (private by default)
resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.frontend_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${aws_s3_bucket.frontend_bucket.bucket}"
}

# S3 Bucket Policy (Allow CloudFront Only)
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.oai.id}"
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
}
# _____________________Creating CloudFront Distribution___________________
# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

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
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [
    aws_s3_bucket.frontend_bucket,
  ]
}

# _____________________Creating RDS-database____________________
# Get the default security group for your VPC
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = "vpc-0297cd44f118eae2f"  # Replace with your actual VPC ID
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

# _____________________Creating App-runner___________________
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
            S3_BUCKET_NAME  = aws_s3_bucket.frontend_bucket.bucket
            DB_USER           = aws_db_instance.my_database.username
            DB_PASSWORD       = var.db_password
            DB_HOST           = aws_db_instance.my_database.address
            DB_NAME           = aws_db_instance.my_database.db_name
            DB_PORT           = "5432"
            DB_SSL            = "true" # Always use SSL with public RDS
          }
        }
      }
    }
  }

  instance_configuration {
    cpu               = "1024"
    memory            = "2048"
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
    aws_s3_bucket.frontend_bucket,
    aws_db_instance.my_database
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
  value = aws_s3_bucket.frontend_bucket.bucket
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
