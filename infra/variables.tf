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

variable "github_repo" {
  description = "Repo whose GitHub Actions may deploy this infra (owner/name). EDIT before the first apply."
  type        = string
  default     = "soutogustavo/ml-platform-aws"

  validation {
    condition     = !startswith(var.github_repo, "CHANGE-ME/")
    error_message = "Set github_repo to your real <github-user>/ml-platform-aws."
  }
}

