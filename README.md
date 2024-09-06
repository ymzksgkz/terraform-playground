# 前準備
brew install direnv
eval "$(direnv hook zsh)" を .zshrc に追加

# .envrc 準備
cp .envrc.sample .envrc
.envrc に AWS_PROFILE を設定
.envrc に BACKEND_BUCKET を設定
.envrc に DYNAMO_DB_TABLE を設定
.envrc に TF_VAR_region を設定

direnv allow

# terraform.tfvars 準備
cp terraform.tfvars.sample terraform.tfvars
terraform.tfvars に project_id を設定
terraform.tfvars に common_tags を設定

# tfbackend 準備
aws s3 mb s3://$BACKEND_BUCKET
aws s3 rb s3://$BACKEND_BUCKET

aws dynamodb create-table \
--table-name terraform-state-lock \
--attribute-definitions AttributeName=LockID,AttributeType=S \
--key-schema AttributeName=LockID,KeyType=HASH \
--billing-mode PAY_PER_REQUEST

aws dynamodb delete-table --table-name terraform-state-lock

# terraform インストール
asdf plugin add terraform
asdf list all terraform
asdf install terraform 1.9.5
asdf global terraform 1.9.5


# terraform 環境初期化
terraform init \
  -backend-config="region=$TF_VAR_region" \
  -backend-config="bucket=$BACKEND_BUCKET" \
  -backend-config="dynamodb_table=$DYNAMO_DB_TABLE" \

terraform validate
terraform plan
terraform apply
terraform destroy


