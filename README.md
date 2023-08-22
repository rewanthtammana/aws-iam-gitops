# aws-gitops

This requires certain set of things

### Github

1. GITHUB_USERNAME
2. GITHUB_REPO
3. GITHUB_TOKEN (write access to above GITHUB_REPO)

### AWS

0. Env variables setup

```bash
export TF_VAR_GITHUB_TOKEN=
export TF_VAR_GITHUB_REPO=testaws
export TF_VAR_GITHUB_USERNAME=rewanthtammana
export TF_VAR_ECR_REPO_NAME=aws-iam-gitops
export TF_VAR_RANDOM_SUFFIX=30

export TF_VAR_ECR_REPO_TAG=v${TF_VAR_RANDOM_SUFFIX}
export TF_VAR_AWS_PAGER=
export TF_VAR_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export TF_VAR_REGION=us-east-1
export TF_VAR_ROLE_NAME=LambdaRole-${TF_VAR_RANDOM_SUFFIX}
export TF_VAR_IMAGE=${TF_VAR_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${TF_VAR_ECR_REPO_NAME}:${TF_VAR_ECR_REPO_TAG}
export TF_VAR_LAMBDA_FUNCTION_NAME=hello-world-${TF_VAR_RANDOM_SUFFIX}
export TF_VAR_POLICY_NAME=LambdaExtraPermissions-${TF_VAR_RANDOM_SUFFIX}
export TF_VAR_LAMBDA_TIMEOUT=120
export TF_VAR_EVENTBRIDGE_NAME=hello-world-${TF_VAR_RANDOM_SUFFIX}
export TF_VAR_S3_BUCKET_NAME=hello-world-${TF_VAR_RANDOM_SUFFIX}
export TF_VAR_CLOUDTRAIL_NAME=hello-world-${TF_VAR_RANDOM_SUFFIX}
```

1. Re-tag and push it to your private ecr repo.

```bash
# create ecr repo & login
aws ecr create-repository --repository-name ${TF_VAR_ECR_REPO_NAME}
aws ecr get-login-password --region ${TF_VAR_REGION} | docker login --username AWS --password-stdin ${TF_VAR_ACCOUNT_ID}.dkr.ecr.${TF_VAR_REGION}.amazonaws.com
docker build --build-arg GITHUB_USERNAME=${TF_VAR_GITHUB_USERNAME} --build-arg GITHUB_REPO=${TF_VAR_GITHUB_REPO} --build-arg GITHUB_TOKEN=${TF_VAR_GITHUB_TOKEN} -t ${TF_VAR_IMAGE} .
docker push ${TF_VAR_IMAGE}
```

1. Everything else is embedded in terraform

```bash
terraform init
terraform apply
```

1. Delete everything

```bash
terraform destroy
aws ecr delete-repository --repository-name ${TF_VAR_ECR_REPO_NAME}
```
