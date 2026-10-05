# ML Platform AWS

Shared AWS infrastructure for my ML portfolio projects: **one managed MLflow tracking server, one artifact store, and a keyless CI/CD identity for GitHub Actions, all provisioned with Terraform.**

Project repos like `rossmann-forecasting-benchmark` own their data, pipelines and compute. This repo owns only what is **shared** among them and must outlive any single project: experiment history and the identity CI uses to reach AWS.

## Contents

1. [Services provided](#services-provided)
2. [Architecture](#architecture)
3. [Repository layout](#repository-layout)
4. [Reproduce from scratch](#reproduce-from-scratch)
5. [Day-to-day workflow](#day-to-day-workflow)
6. [Consume the platform from a project](#consume-the-platform-from-a-project)
7. [Problems faced and how they were solved](#problems-faced-and-how-they-were-solved)
8. [Cost](#cost)
9. [Teardown](#teardown)


## Services provided

| Service | AWS resource | What it is for |
|---|---|---|
| **Experiment tracking + model registry** | SageMaker AI serverless MLflow App | Params, metrics, runs and registered models for every project, in one place |
| **Artifact store** | S3 bucket `gs-shared-ml-platform-mlflow-artifacts` | Models, plots and files logged with `log_artifact` / `log_model`. Private, encrypted, protected against accidental deletion |
| **MLflow server identity** | IAM role `gs-shared-ml-platform-mlflow-execution` | Lets the MLflow App read and write the artifact bucket |
| **MLflow client access** | IAM policy `gs-shared-ml-platform-mlflow-consumer` | Attach to any role that logs runs (ECS task, CI, your CLI). Covers both the MLflow API and the S3 artifact path |
| **Keyless CI identity** | GitHub OIDC provider + roles `...-gh-plan` (read-only) and `...-gh-apply` (main only) | Lets GitHub Actions deploy infra with short-lived credentials. No AWS keys stored anywhere |

**Not** provided here, on purpose: data buckets, ECS clusters, ECR repos, schedulers. Those belong to each project and live in its repo.

### Platform contract (Terraform outputs)

Other repos depend **only** on these outputs. Renaming one is a breaking change.

| Output | Used for |
|---|---|
| `mlflow_tracking_uri` | Value of `MLFLOW_TRACKING_URI` (the MLflow App ARN) |
| `artifact_bucket_name` | Where artifacts land |
| `mlflow_consumer_policy_arn` | Attach to any role that needs to log to MLflow |
| `github_oidc_provider_arn` | Reused by other repos for their own CI roles (one provider per AWS account) |
| `github_plan_role_arn`, `github_apply_role_arn` | Copied into this repo's GitHub variables |
| `region` | `eu-central-1` |




## Architecture

### Runtime: how a project uses MLflow

<img width="5508" height="1350" alt="Image" src="https://github.com/user-attachments/assets/0d76c246-1312-4e34-b6f0-9f3ffe8eece7" />


Two paths, and both need permissions: **metadata** goes to the MLflow App, **artifacts** go straight from the client to S3. The server never proxies artifact bytes, which is why the consumer policy includes S3 access.

### CI/CD: how infra changes reach AWS

<img width="8125" height="1574" alt="Image" src="https://github.com/user-attachments/assets/db8aa3ce-fe41-4e09-a79c-c49b5004042f" />

- **Terraform state** lives in HCP Terraform (org `gsouto-labs`, workspace `ml-platform-aws`), execution mode **Local**: HCP only stores and locks the state, Terraform runs on the GitHub runner or on my laptop.
- **AWS credentials** come from GitHub OIDC: each job exchanges a signed GitHub token for 1-hour credentials. The role trust policies only accept tokens from this repo, and only from PRs (plan) or `main` (apply).


## Repository layout

```
ml-platform-aws/
├── infra/                           # Terraform root (HCP workspace: ml-platform-aws)
│   ├── base_terraform.tf            # cloud block, provider, common tags, name prefix
│   ├── main.tf                      # wires the three modules together
│   ├── variables.tf                 # region, environment, GitHub repo and IDs
│   ├── outputs.tf                   # the platform CONTRACT
│   └── modules/
│       ├── artifact_store/          # S3: private, encrypted, ACLs off, no force_destroy
│       ├── mlflow/                  # execution role, MLflow App, consumer policy
│       └── github_oidc/             # OIDC provider, gh-plan and gh-apply roles
├── .github/workflows/terraform.yml  # PR: plan + comment | main: apply
└── pyproject.toml                   # uv: mlflow, sagemaker-mlflow, boto3
```


## Local machine setup

Everything needed to work on this repo from a fresh laptop. Nothing here is stored in the repo: credentials stay in `~/.aws`, helpers stay in your shell config.

### 1. Tools

AWS CLI v2, Terraform >= 1.6, `uv`, `git`.

### 2. AWS profiles (`~/.aws/config` and `~/.aws/credentials`)

Day-to-day access never uses root. An IAM user whose only permission is to assume an admin role, protected by MFA:

```ini
# ~/.aws/credentials  (the only long-lived key; it can do nothing except assume the role)
[gsouto]
aws_access_key_id     = <access key>
aws_secret_access_key = <secret>

# ~/.aws/config
[profile portfolio-admin]
role_arn       = arn:aws:iam::<account_id>:role/PortfolioAdmin
source_profile = gsouto
mfa_serial     = arn:aws:iam::<account_id>:mfa/<device>
region         = eu-central-1
```

### 3. Shell helper: export temporary credentials (`~/.zshrc`)

```bash
alias awsadmin='eval "$(aws configure export-credentials --profile portfolio-admin --format env)" && export AWS_REGION=eu-central-1 AWS_DEFAULT_REGION=eu-central-1'
```

Run `awsadmin` once per session: the AWS CLI asks for the MFA code, assumes `PortfolioAdmin` and exports short-lived `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN` into the shell. Terraform and Python then pick them up from the environment.

**Why not just `AWS_PROFILE=portfolio-admin`?** Terraform cannot prompt for an MFA code, so a profile with `mfa_serial` fails inside Terraform (see [problem 8](#8-terraform-cannot-prompt-for-the-mfa-code)). The CLI does the MFA step, Terraform only sees ready-made temporary credentials.

Check who you are before any `plan` or `apply`:

```bash
awsadmin
aws sts get-caller-identity   # Arn should end in assumed-role/PortfolioAdmin/...
```

Credentials expire (about 1 hour): if a command suddenly returns `ExpiredToken`, run `awsadmin` again.

### 4. HCP Terraform

```bash
terraform login   # stores a user token in ~/.terraform.d/credentials.tfrc.json
```

### 5. MLflow environment

```bash
export MLFLOW_TRACKING_URI=$(terraform -chdir=infra output -raw mlflow_tracking_uri)
```

Read it from the Terraform output instead of hard-coding the ARN: if the MLflow App is ever recreated, the ARN changes and a hard-coded value silently points to nothing. `MLFLOW_TRACKING_URI` is the name the MLflow client reads automatically; any other name (e.g. `MLFLOW_APP_ARN`) only works if your code reads it explicitly.


## Reproduce from scratch

Order matters: the CI cannot create the identity it needs to run, so the first apply is local. After that, every change goes through a PR.

### 0. Prerequisites

| Tool / account | Notes |
|---|---|
| AWS account | A profile that can create IAM, S3 and SageMaker resources. Here: `portfolio-admin` (assumes a role with MFA) |
| Terraform >= 1.6 | `terraform login` to HCP Terraform |
| HCP Terraform (free) | Organization + workspace `ml-platform-aws`, **execution mode: Local** |
| GitHub repo | Public, so rulesets are available on the free plan |
| `uv` | Only for the smoke test |

> In Local mode, variables set in the HCP UI are **ignored**. Values come from `variables.tf` defaults.

### 1. Point the code at your GitHub repo

In `infra/variables.tf`, set the defaults of:

| Variable | How to get it |
|---|---|
| `github_repo` | `<owner>/<repo>`, e.g. `soutogustavo/ml-platform-aws` |
| `github_owner_id` | `gh api repos/<owner>/<repo> --jq .owner.id` |
| `github_repo_id` | `gh api repos/<owner>/<repo> --jq .id` |

The IDs are needed because GitHub's OIDC `sub` claim includes them for repos created after 2026-07-15 (see [problem 6](#6-ci-could-not-assume-the-role-new-oidc-sub-format)). They must be `default`s, not `-var` flags: the CI runner has nobody to answer a prompt.

Also update the `repo` tag in `infra/base_terraform.tf`.

### 2. Bootstrap: first apply from your machine

```bash
export AWS_PROFILE=portfolio-admin
terraform -chdir=infra init
terraform -chdir=infra plan     # expect: 13 to add
terraform -chdir=infra apply
terraform -chdir=infra output
```

The 13 resources: artifact store (4), MLflow (4), OIDC provider + 2 roles + 2 policy attachments (5).

### 3. Lock providers for both platforms

The lock file was generated on macOS, CI runs on Linux:

```bash
terraform -chdir=infra providers lock -platform=darwin_amd64 -platform=linux_amd64
```

Commit `infra/.terraform.lock.hcl`.

### 4. Create an HCP API token for CI

HCP Terraform: *Account settings > Tokens > Create an API token* (not the "GitHub App OAuth token", which is for the opposite direction). Name it `github-actions-ml-platform` and give it an expiry, with a calendar reminder to rotate it.

### 5. Configure the GitHub repo

*Settings > Secrets and variables > Actions*

| Type | Name | Value |
|---|---|---|
| Secret | `TF_API_TOKEN` | Token from step 4 |
| Variable | `AWS_PLAN_ROLE_ARN` | `terraform output -raw github_plan_role_arn` |
| Variable | `AWS_APPLY_ROLE_ARN` | `terraform output -raw github_apply_role_arn` |

ARNs are variables, not secrets: they are addresses, not credentials.

### 6. First push to `main`

Push the code. The `apply` job should end with **"No changes"**. That single run proves three things: the HCP token works, the apply role's OIDC trust works, and CI and laptop share the same state.

### 7. Protect `main`

*Settings > Rules > Rulesets > New branch ruleset*:

- Name `protect-main`, enforcement **Active**, target **default branch**
- Restrict deletions, block force pushes
- Require a pull request, **required approvals: 0** (GitHub does not let you approve your own PR)
- Require status check **`plan`** (it appears in the search only after it ran once; if missing, add it after step 8)

### 8. Validate the PR path

Open a PR with a harmless change (e.g. a tag). Expect a PR comment with the plan, then merge and watch `apply` run on `main`.



## Day-to-day workflow

| Situation | What to do |
|---|---|
| Change infra | Branch, commit, open PR. Read the plan comment. Merge. CI applies. |
| Quick feedback before a PR | `terraform plan` locally is fine (read-only) |
| `terraform apply` locally | **Only as break-glass**, e.g. when CI cannot assume its own role. Anything applied locally that is not on `main` is reverted by the next CI apply |
| Draft PRs | Work normally: `plan` runs on drafts too |



## Consume the platform from a project

**Terraform** (in the project's `infra/`): read the outputs, never hard-code ARNs.

```hcl
data "tfe_outputs" "platform" {
  organization = "gsouto-labs"
  workspace    = "ml-platform-aws"
}

resource "aws_iam_role_policy_attachment" "task_logs_to_mlflow" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = data.tfe_outputs.platform.values.mlflow_consumer_policy_arn
}
```

Allow the project workspace to read this one: HCP *Settings > General > Remote state sharing*.

**Python**: same MLflow code as locally, only the URI changes.

```python
import os
import mlflow  # with `sagemaker-mlflow` installed

mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])  # the App ARN
mlflow.set_experiment("rossmann/xgb-global")
```

**Conventions**

| Thing | Convention | Example |
|---|---|---|
| Experiment | `<project>/<experiment>` | `rossmann/xgb-global` |
| Run tag `env` | `dev` or `prod` | separates environments in one server ([ADR 0005](docs/decisions/0005-single-shared-environment.md)) |
| Run tag `git_sha` | commit of the training code | reproducibility |
| Registered model | `<project>-<model>` | `rossmann-xgb-global` |



## Problems faced and how they were solved

Real issues hit while building this, kept here because each one is a lesson.

#### 1. Wrong Terraform resource for the MLflow App
- **Symptom**: first draft used the `awscc` (Cloud Control) provider.
- **Cause**: assumed the classic `aws` provider only had the older, hourly-billed `aws_sagemaker_mlflow_tracking_server`.
- **Fix**: `aws_sagemaker_mlflow_app` exists in `hashicorp/aws` v6, and was already working in the Rossmann repo.
- **Lesson**: check the code that already works before reaching for a second provider.

#### 2. Client permissions incomplete
- **Symptom**: consumer policy only had `sagemaker-mlflow:*`.
- **Cause**: MLflow Apps also authorize data-plane calls with `sagemaker:CallMlflowAppApi`.
- **Fix**: both actions in the consumer policy, plus S3 access because artifacts bypass the server.

#### 3. Variable validation rejected a valid value
- **Symptom**: `Set github_repo to your real <github-user>/ml-platform-aws` with the correct repo name.
- **Cause**: the placeholder was replaced in the `default` **and** in the `condition`, so the rule rejected the real name.
- **Fix**: replaced the placeholder check with a format check: `can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", ...))`.
- **Lesson**: a `condition` must be `true` for valid values. Read it as "valid if...".

#### 4. Plan showed 8 resources instead of 13, then outputs were missing
- **Cause**: the `github_oidc` module was not wired in `main.tf`; later, its outputs were not added to `outputs.tf`.
- **Fix**: add module (then `terraform init`, required for any new module), then outputs. A second `apply` with **"No changes"** was enough to write the new outputs to state.
- **Lesson**: resources and outputs are separate; outputs only reach the state on apply.

#### 5. HCP token type
- **Question**: "API token" or "GitHub App OAuth token"?
- **Answer**: API token. The OAuth token lets HCP read GitHub (VCS-driven runs), the opposite direction. A separate token per consumer (laptop vs CI) allows revoking one without breaking the other.

#### 6. CI could not assume the role: new OIDC `sub` format
- **Symptom**: `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`, with the right repo and branch.
- **Cause**: repos created after 2026-07-15 send an immutable `sub`: `repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/main`. The trust policy expected the old `repo:<owner>/<repo>:...`, and `StringEquals` requires an exact match.
- **Fix**: build the `sub` from owner and repo IDs; apply **locally** (CI cannot fix a role it cannot assume).
- **Lesson**: the IDs also close a real risk: a deleted repo recreated under the same name cannot inherit the trust. When in doubt, print the actual `sub` from the token instead of guessing.

#### 7. Required check + path filter = PR blocked forever
- **Cause**: `plan` is required by the ruleset, but the workflow only ran on PRs touching `infra/`. A README-only PR never reports the check.
- **Fix**: no `paths` filter on `pull_request` (plan runs on every PR, "No changes" in seconds); `push` to `main` keeps the filter.
- **Lesson**: branch rules and workflow triggers must agree.

#### 8. Terraform cannot prompt for the MFA code
- **Symptom**: with `AWS_PROFILE=portfolio-admin`, Terraform fails to assume the role, while `aws` CLI commands with the same profile work.
- **Cause**: the profile requires MFA (`mfa_serial`). The AWS CLI can ask for the code interactively; the Terraform AWS provider cannot.
- **Fix**: let the CLI do the MFA step and export temporary credentials into the shell (`awsadmin` alias, see [Local machine setup](#local-machine-setup)).
- **Lesson**: in CI the same problem does not exist, because OIDC replaces both the long-lived key and the MFA step.



## Cost

| Item | Cost |
|---|---|
| Serverless MLflow App | No additional charge per the AWS launch post (re-check the pricing page) |
| S3 | Cents per month at portfolio scale. No versioning or lifecycle rules: MLflow writes each run to its own path, and the bucket cannot be destroyed by Terraform |
| IAM, OIDC | Free |
| HCP Terraform | Free tier |

Set an AWS Budget alert regardless. "Should be free" is a hypothesis; the bill is the measurement.



## Teardown

The bucket has `force_destroy = false` on purpose.

1. Export anything worth keeping (`mlflow-export-import`).
2. Empty the bucket manually.
3. `terraform -chdir=infra destroy` locally. Destroying the CI roles from CI would cut the branch it is sitting on.

---
