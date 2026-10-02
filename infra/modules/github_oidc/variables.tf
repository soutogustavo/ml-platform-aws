variable "name_prefix" {
  type = string
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the roles, as owner/name."
  type        = string
}

variable "github_owner_id" {
  description = "Numeric ID of the repo owner: gh api repos/<owner>/<repo> --jq .owner.id"
  type        = number
}

variable "github_repo_id" {
  description = "Numeric ID of the repo: gh api repos/<owner>/<repo> --jq .id"
  type        = number
}
