#!/usr/bin/env sh
set -eu

terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test

if command -v tflint >/dev/null 2>&1; then
  tflint --init
  tflint --recursive
fi

if command -v trivy >/dev/null 2>&1; then
  trivy config --exit-code 1 --severity HIGH,CRITICAL .
fi

echo "AKS module quality gates completed successfully."
