#!/bin/bash
export REGION=eu-west-1
aws sts get-caller-identity >/dev/null 2>&1

if [[ $? != 0 ]]; then
  echo "Error calling AWS get-caller-identity. Do you have valid credentials?"
else
  SSM_NAMES=$(aws ssm get-parameters-by-path --region $REGION --path /test/pender/ --recursive --with-decryption --output text --query "Parameters[].[Name]")

  if [ -f ".env" ]; then
    echo "File .env exists, removing and overwriting."
    rm .env
  fi
  echo "Getting SSM variables"
  for NAME in $SSM_NAMES; do
    echo "."
    VALUE=$(aws ssm get-parameters --region $REGION --with-decryption --name "$NAME" | jq .Parameters[].Value)
    VARNAME=$(basename "$NAME")
    echo "$VARNAME=$VALUE" >> .env
  done
fi
