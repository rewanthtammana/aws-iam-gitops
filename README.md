# aws-iam-gitops

![8649040a-fd74-46b5-9ad3-16fe468db6c1](https://github.com/rewanthtammana/aws-iam-gitops/assets/22347290/ec558297-34ba-4bf8-a2c3-cfdd111d1582)


## Goal

![49ab7036-63eb-4677-bc21-21b45f19706a](https://github.com/rewanthtammana/aws-iam-gitops/assets/22347290/d3428b8f-4d26-4306-952b-4d4724d0e387)


To achive the goal, we require certain set privileges.

### Github

1. TF_VAR_GITHUB_USERNAME
2. TF_VAR_GITHUB_REPO
3. TF_VAR_GITHUB_TOKEN (write access to above TF_VAR_GITHUB_REPO)

### AWS

1. Env variables setup

  ```bash
  # Change environment variables (MUST/MANDATORY)
  # Make sure TF_VAR_GITHUB_REPO exists on your GitHub
  export TF_VAR_GITHUB_USERNAME=rewanthtammana
  export TF_VAR_GITHUB_REPO=testaws
  export TF_VAR_GITHUB_TOKEN=
  
  # Change environment variables (Optional)
  export TF_VAR_ECR_REPO_NAME=aws-iam-gitops
  
  # Change environment variables (Optional - the suffix is used in image name, role name, lambda function name, policy name, event bridge name, s3 bucket name & cloud trail name)
  export TF_VAR_RANDOM_SUFFIX=31
  export TF_VAR_RANDOM_PREFIX=aws-iam-gitops
  
  # Change environment variables - Recommended to leave them as it is but feel free to change them
  export TF_VAR_ECR_REPO_TAG=v${TF_VAR_RANDOM_SUFFIX}
  export TF_VAR_AWS_PAGER=
  export TF_VAR_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  export TF_VAR_REGION=us-east-1
  export TF_VAR_ROLE_NAME=${TF_VAR_RANDOM_PREFIX}-lambda-role-${TF_VAR_RANDOM_SUFFIX}
  export TF_VAR_IMAGE=${TF_VAR_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TF_VAR_ECR_REPO_NAME}:${TF_VAR_ECR_REPO_TAG}
  export TF_VAR_LAMBDA_FUNCTION_NAME=${TF_VAR_RANDOM_PREFIX}-${TF_VAR_RANDOM_SUFFIX}
  export TF_VAR_POLICY_NAME=${TF_VAR_RANDOM_PREFIX}-lambda-permissions-${TF_VAR_RANDOM_SUFFIX}
  export TF_VAR_LAMBDA_TIMEOUT=120
  export TF_VAR_EVENTBRIDGE_NAME=${TF_VAR_RANDOM_PREFIX}-${TF_VAR_RANDOM_SUFFIX}
  export TF_VAR_S3_BUCKET_NAME=${TF_VAR_RANDOM_PREFIX}-${TF_VAR_RANDOM_SUFFIX}
  export TF_VAR_CLOUDTRAIL_NAME=${TF_VAR_RANDOM_PREFIX}-${TF_VAR_RANDOM_SUFFIX}
  ```

2. Re-tag and push it to your private ecr repo.

  ```bash
  # create ecr repo & login
  aws ecr create-repository --repository-name ${TF_VAR_ECR_REPO_NAME}
  aws ecr get-login-password --region ${TF_VAR_REGION} | docker login --username AWS --password-stdin ${TF_VAR_ACCOUNT_ID}.dkr.ecr.${TF_VAR_REGION}.amazonaws.com
  docker build --platform linux/amd64 --build-arg GITHUB_USERNAME=${TF_VAR_GITHUB_USERNAME} --build-arg GITHUB_REPO=${TF_VAR_GITHUB_REPO} --build-arg GITHUB_TOKEN=${TF_VAR_GITHUB_TOKEN} -t ${TF_VAR_IMAGE} .
  docker push ${TF_VAR_IMAGE}
  ```

3. Everything else is embedded in terraform

  ```bash
  terraform init
  terraform apply
  ```

4. Delete everything

  ```bash
  # Delete terraform resources
  terraform destroy
  
  # Delete all images in the ECR repository
  aws ecr batch-delete-image --repository-name ${TF_VAR_ECR_REPO_NAME} --image-ids "$(aws ecr list-images --region ${TF_VAR_REGION} --repository-name ${TF_VAR_ECR_REPO_NAME} --query 'imageIds[*]' --output json)"
  
  # Delete ECR repository
  aws ecr delete-repository --repository-name ${TF_VAR_ECR_REPO_NAME}
  ```
