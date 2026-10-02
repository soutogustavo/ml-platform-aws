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

variable "github_owner_id" {
  description = "gh api repos/<owner>/<repo> --jq .owner.id"
  type        = number
  default     = 9319823

  validation {
    condition     = var.github_owner_id > 0
    error_message = "Set github_owner_id (gh api repos/<owner>/<repo> --jq .owner.id)."
  }
}

variable "github_repo_id" {
  description = "gh api repos/<owner>/<repo> --jq .id"
  type        = number
  default     = 1400165164

  validation {
    condition     = var.github_repo_id > 0
    error_message = "Set github_repo_id (gh api repos/<owner>/<repo> --jq .id)."
  }
}
