
#!/usr/bin/env bash
set -euo pipefail

SECRET_NAME="platform/dev/postgres"
AWS_REGION="us-east-1"

echo "AWS identity:"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table

echo
read -r -p "Enter the expected AWS account ID: " EXPECTED_ACCOUNT
ACTUAL_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

if [[ "$ACTUAL_ACCOUNT" != "$EXPECTED_ACCOUNT" ]]; then
  echo "ERROR: AWS account does not match."
  exit 1
fi

echo
echo "Checking that the secret exists..."
aws secretsmanager describe-secret \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --query '{Name:Name,ARN:ARN}' \
  --output table

echo
read -r -p "Type YES to update this secret: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
  echo "Cancelled."
  exit 1
fi

echo
read -r -s -p "Enter PostgreSQL password: " POSTGRES_PASSWORD
echo

if [[ -z "$POSTGRES_PASSWORD" ]]; then
  echo "ERROR: Password cannot be empty."
  exit 1
fi

export POSTGRES_PASSWORD

# Generate the JSON payload without printing the password.
SECRET_JSON=$(python3 -c '
import json
import os
print(json.dumps({"password": os.environ["POSTGRES_PASSWORD"]}))
')

unset POSTGRES_PASSWORD

# Pass the secret through standard input instead of CLI arguments.
printf '%s' "$SECRET_JSON" | aws secretsmanager put-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --secret-string file:///dev/stdin \
  --query '{ARN:ARN,VersionId:VersionId}' \
  --output json

unset SECRET_JSON

echo "PostgreSQL secret updated successfully."
