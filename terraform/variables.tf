variable "AWS_ACCESS_KEY_ID" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "customer_name" {
  type        = string
  description = "Name of the customer"
}

variable "project" {
  type        = string
  description = "Name of the project"
}

variable "repository_url" {
  type        = string
  description = "GitHub repository URL for the backend service"
}

variable "branch" {
  type        = string
  description = "Name of the repo branch"
  default     = "master"
}

variable "db_password" {
  description = "Password for the database admin user"
  type        = string
  sensitive   = true
}
variable "db_username" {
  description = "Username for the database"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}
