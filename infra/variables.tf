variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Platform Environment"
  type        = string
  default     = "shared"
}

variable "mlflow_app_name" {
  description = "Name of the serverless MLflow App"
  type        = string
  default     = "ml-platform"
}
