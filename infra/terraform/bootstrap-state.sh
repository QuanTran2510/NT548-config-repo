#!/usr/bin/env bash
# Creates the S3 bucket that holds the Terraform state and writes backend.hcl. Run ONCE per AWS account.
set -euo pipefail
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${1:-platform-tfstate-$ACCOUNT}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "bucket $BUCKET already exists"
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
fi
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  || echo "WARNING: could not block public access (Learner Lab may forbid it); the bucket has no public policy anyway"

cat > "$(dirname "$0")/backend.hcl" <<HCL
bucket       = "$BUCKET"
key          = "platform/terraform.tfstate"
region       = "$REGION"
use_lockfile = true
HCL
echo "OK. Next: terraform init -migrate-state -backend-config=backend.hcl"
echo "GitHub repository variable TF_STATE_BUCKET = $BUCKET"
