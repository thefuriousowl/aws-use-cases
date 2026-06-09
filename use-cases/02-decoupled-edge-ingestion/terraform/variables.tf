variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}


variable "project_prefix" {
  description = "Prefix for resource names to avoid collisions"
  type        = string
  default     = "uc02-iot"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}
