# Global 360 Auto-Healing Web Tier

This is my implementation of a small self-healing web tier on AWS. Terraform builds an ALB and an Auto Scaling group across two Availability Zones. The EC2 instances run NGINX in Docker and stay in private subnets with no SSH access.

There isn't a live URL now. I deployed the staging environment, checked it, and then tore it down to avoid leaving assessment infrastructure running.

## Architecture

![AWS architecture for the Global 360 web tier](docs/architecture.svg)

[Editable draw.io source](docs/architecture.drawio)

Traffic comes in through the ALB and is sent only to healthy targets on port 80. The NAT Gateway is only for outbound traffic from the private instances, mainly package installation and pulling the container image.

The target group calls `GET /healthz` every 30 seconds. Two failed checks mark a target unhealthy. The ASG uses ELB health checks, so it should terminate that instance and launch a replacement from the launch template. The other healthy target remains available while this happens.

The group runs two instances by default and can scale from 2 to 4. Launch template changes use a rolling instance refresh that keeps the current capacity healthy and rolls back on failure. I set CPU target tracking to 80%. That is high, but this is a low-CPU static site and I did not want short spikes adding assessment cost.

## Key choices

I used `t4g.micro` Graviton instances because they are inexpensive and the image is built for ARM64 as well as AMD64. The instances have encrypted gp3 volumes, require IMDSv2, and are managed through Session Manager. There is no key pair, public IP, bastion, SSH rule, or port 22.

I kept the instances private and made the ALB security group the only source allowed into port 80. That leaves one public entry point: the ALB's HTTP listener. For a real public service I would add a domain, ACM certificate, and HTTPS listener.

I went with one NAT Gateway to keep the assessment cost down. Losing that NAT or its AZ removes internet egress from both private subnets. Existing healthy containers can still serve through the ALB, but replacement bootstrap, image pulls, and Session Manager are affected. I did not test that failure mode. For production I would use one NAT per AZ or remove the dependency with private endpoints and an internal image source.

Terraform state is kept in a versioned S3 bucket with KMS encryption and native S3 state locking. Staging and production have separate root modules and state, but both reuse the modules under `modules/`.

## Repository layout

```text
.
├── bootstrap/              # S3 backend and KMS key
├── environments/
│   ├── staging/
│   └── production/
├── modules/
│   ├── network/
│   ├── alb/
│   └── compute/
├── docker/
├── .github/workflows/
├── Makefile
└── sonar-project.properties
```

Terraform commands run from an environment root rather than the repository root. This keeps each environment's state and lifecycle separate.

## Prerequisites

- Terraform `1.15.x`
- AWS CLI v2
- jq
- Make
- Actionlint `1.7.x`
- TFLint `0.64.x`
- Trivy `0.69.x`
- Docker with Buildx if building the image locally

The examples use `ap-southeast-2`. Check the AWS account before creating anything:

```bash
export AWS_PROFILE=<profile>
aws sts get-caller-identity
```

## Deploy

### 1. Create the remote state backend

The bootstrap stack uses local state because it creates the remote backend itself.

```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -out=bootstrap.tfplan
terraform -chdir=bootstrap apply bootstrap.tfplan
terraform -chdir=bootstrap output
```

Copy the backend example for the environment you want to use, then replace the bucket and KMS placeholders with the bootstrap outputs:

```bash
cp environments/staging/backend.hcl.example environments/staging/backend.hcl
```

### 2. Configure the environment

```bash
cp environments/staging/terraform.tfvars.example environments/staging/terraform.tfvars
```

Replace the image placeholder in `terraform.tfvars`. The public image built for this project is:

```text
ghcr.io/heyallensu/global-360-auto-healing-web-tier@sha256:51f91115cb059d75111a85da1abe6905ce0354c3f160cf459205dabcc43fd982
```

For a local container check:

```bash
make docker-build IMAGE=global-360-web:test
```

The EC2 instances cannot use that local tag. A custom image must be pushed to a registry they can reach, then pinned by digest in `terraform.tfvars`. The Docker workflow handles the multi-architecture GHCR build on a branch push.

### 3. Check and deploy

```bash
make check ENV=staging
make plan ENV=staging
terraform -chdir=environments/staging show staging.tfplan
make apply ENV=staging
make output ENV=staging
```

`make apply` only accepts the saved plan from `make plan`.

### 4. Check the running service

```bash
ALB_URL="$(terraform -chdir=environments/staging output -raw alb_url)"
curl -fsS "${ALB_URL}/healthz"
curl -I "${ALB_URL}"
```

`/healthz` should return `ok`, and the root path should return HTTP 200. An unchanged deployment should also produce an empty plan:

```bash
terraform -chdir=environments/staging plan \
  -input=false \
  -lock-timeout=5m \
  -var-file=terraform.tfvars \
  -detailed-exitcode
```

### 5. Clean up

Destroy the environment before deleting its state backend:

```bash
make destroy ENV=staging
```

The versioned S3 bucket must be emptied before destroying the bootstrap stack. Keep the local bootstrap state until this finishes:

```bash
BUCKET="$(terraform -chdir=bootstrap output -raw state_bucket_name)"
DELETE_REQUEST="$(aws s3api list-object-versions --bucket "$BUCKET" | \
  jq -c '{Objects: ((.Versions // []) + (.DeleteMarkers // []) |
    map({Key, VersionId})), Quiet: true}')"

if [ "$(jq '.Objects | length' <<<"$DELETE_REQUEST")" -gt 0 ]; then
  aws s3api delete-objects --bucket "$BUCKET" --delete "$DELETE_REQUEST"
fi

terraform -chdir=bootstrap destroy
```

KMS keys are scheduled for deletion, so they remain in `PendingDeletion` for the configured seven-day window.

## CI/CD

The branch flow is:

```text
feature/* -> develop -> main
               |          |
            staging    production
```

Pull requests to `develop` and `main` run Terraform validation, TFLint, and Trivy. SonarQube runs for pull requests to `main` and pushes to `main`; its free plan does not provide branch analysis for `develop`. Pushes build and publish the multi-architecture image, then scan the pushed digest.

Authenticated Terraform plans are manual. A staging plan can run only from `develop`, and a production plan only from `main`. GitHub Actions assumes an AWS role through OIDC, so there are no long-lived AWS access keys in the repository.

The CI plan is advisory and is not kept as a build artifact. To deploy, the operator runs `make plan` locally, reviews that saved plan, and then runs `make apply`. The Makefile applies the same local plan that was reviewed.

The plan job expects `AWS_PLAN_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_KMS_KEY_ARN`, and `CONTAINER_IMAGE` as GitHub environment variables. SonarQube uses `SONAR_HOST_URL` as a variable and `SONAR_TOKEN` as a secret.

## Cost

An always-on deployment does not fit the AUD 20 target. My rough monthly estimate for Sydney is:

- NAT Gateway: about USD 43
- ALB and light LCU usage: about USD 24
- Two `t4g.micro` instances: about USD 16
- Storage, public IPv4 addresses, KMS, and alarms: about USD 13
- Total: roughly USD 95-100 per month, before tax and data transfer

For this assessment the stack is meant to be short-lived. Eight hours is roughly USD 1-2, depending on traffic. The NAT Gateway and ALB are the main fixed costs.

## What I verified

I ran Terraform format and validation for both environments, Actionlint against the workflows, followed by `make lint` and `make scan`. The configured high/critical gate passed with four accepted exceptions: `AVD-AWS-0053` and `AVD-AWS-0054` cover the public, HTTP-only ALB required for this assessment; `AVD-AWS-0095` covers the unencrypted SNS topic; and `AVD-AWS-0104` covers unrestricted TCP 443 egress used for package downloads, image pulls, and Session Manager.

Those IDs are repository-wide suppressions in `.trivyignore`, so they would also hide matching findings on future resources. I would scope them more tightly before extending the repository. For a production deployment I would also add HTTPS and encrypt the SNS topic rather than retain those two exceptions.

The SonarQube exclusions are narrower: each one matches a rule and file. They cover tag-plus-digest image pinning, omitted access-log buckets for this short-lived stack, the required HTTP listener, and the non-sensitive SNS alarm topic.

The staging deployment had two private `t4g.micro` instances in different Availability Zones, and both targets were healthy. `/healthz` returned `ok`, the root returned HTTP 200, and a second Terraform plan had no changes.

I also used Session Manager to confirm that Docker was active and both containers were healthy. The first rollout exposed an Amazon Linux 2023 package conflict between `curl-minimal` and `curl`; the bootstrap now installs Docker without replacing the system curl package.

I did not run the destructive instance-termination or application-failure tests. The ALB and ASG configuration for self-healing is in place, but I would not claim the full replacement path as tested yet. The staging workload and remote-state resources were destroyed after the checks above.

## If I had more time

- Run both failure scenarios and record replacement time and client-visible errors
- Add HTTPS with ACM and Route 53
- Add a second NAT Gateway or remove the outbound dependency
- Add automated module tests with Terratest
