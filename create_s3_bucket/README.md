# 前準備
- このディレクトリに入った時環境変数を自動で定義するための設定
```shell
$ brew install direnv
$ echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
```
---

# .envrc 準備
- 環境変数を設定
```shell
$ cp .envrc.sample .envrc
# .envrc に AWS_PROFILE を設定。
# .envrc に BACKEND_BUCKET を設定。state の保存先
# .envrc に DYNAMO_DB_TABLE を設定。state のロック用
# .envrc に TF_VAR_region を設定。var.region として参照可能
# .envrc に TF_VAR_project_id を設定。var.project_id として参照可能
$ direnv allow
```
---

# terraform.tfvars 準備
- コード内で参照する変数を設定
```shell
$ cp terraform.tfvars_sample terraform.tfvars
# terraform.tfvars に common_tags を設定。後で Tag でリソースの絞り込みが行えるようにする（任意）
```
---

# backend 準備
- state の保存先とロック用の DynamoDB テーブルを作成
```shell
$ aws s3 mb s3://${BACKEND_BUCKET}-${TF_VAR_project_id} 

$ aws dynamodb create-table \
  --table-name ${DYNAMO_DB_TABLE}-${TF_VAR_project_id} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```
---

# terraform インストール
- asdf のインストールについては割愛
```shell
$ asdf plugin add terraform
$ asdf list all terraform
$ asdf install terraform 1.9.5
$ asdf global terraform 1.9.5

$ terraform version # 1.9.5
```


# terraform 環境初期化
```shell
$ terraform init \
  -backend-config="region=$TF_VAR_region" \
  -backend-config="bucket=$BACKEND_BUCKET" \
  -backend-config="dynamodb_table=${DYNAMO_DB_TABLE}-${TF_VAR_project_id}"
  -backend-config="project_id=$TF_VAR_project_id"
```
---

# リソース操作
```shell
$ terraform validate
$ terraform plan
$ terraform apply
```
---

# お片付け

> [!CAUTION]
> リソースを全削除する

```shell
# terraform destroy
# aws s3 rb s3://${BACKEND_BUCKET}-${TF_VAR_project_id} --force
# aws dynamodb delete-table --table-name ${DYNAMO_DB_TABLE}-${TF_VAR_project_id}
```
---
