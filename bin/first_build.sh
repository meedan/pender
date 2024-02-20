#!/bin/bash
export REGION=eu-west-1

# Copy the example files  
find . -name '*.example' -not -path '*apollo*' | while read f; do cp "$f" "${f%%.example}"; done

# Replace secrets (if you have access, login first with "aws sso login")
replace_secrets () {
  APP=$1
  FILE=$2
  SSM_NAMES=$(aws ssm get-parameters-by-path --region $REGION --path "/local/$APP/" --recursive --with-decryption --output text --query "Parameters[].[Name]")
  echo 'Replacing placeholder for real value'
  for NAME in $SSM_NAMES; do
    echo '.'
    VALUE=$(aws ssm get-parameters --region $REGION --with-decryption --name "$NAME" | jq .Parameters[].Value)
    VARNAME=$(basename "$NAME")
    sed -i '' "s/$VARNAME: # 'SECRET'/$VARNAME: $VALUE/g" "$FILE"
  done
}

aws sts get-caller-identity >/dev/null 2>&1
if (( $? != 0 )); then
  echo "Error calling AWS get-caller-identity. Do you have valid credentials?"
else 
  replace_secrets 'pender' 'config/config.yml'
fi

# # Build & Run
# docker-compose build
# docker-compose up --abort-on-container-exit