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
  -backend-config="bucket=${BACKEND_BUCKET}-${TF_VAR_project_id}" \
  -backend-config="dynamodb_table=${DYNAMO_DB_TABLE}-${TF_VAR_project_id}"
```
---

# 実行
- bucket にファイルをアップロードすると実行される関数を作成
```shell
# lambda にデプロイする関数を作成する
$ cat << EOF >> index.js
exports.handler = async (event) => {
    console.log("Event: ", event)
    return {
        statusCode: 200,
        body: JSON.stringify('complete!'),
    }
}
EOF

$ zip lambda_function.zip index.js && rm index.js

# 反映
$ terraform apply
```

- 関数の実行
```shell
# 動作確認
# ログを見ておく
$ logGroupName=$(aws logs describe-log-groups | jq ".logGroups[] | select(.logGroupName | contains(\"${TF_VAR_project_id}\")) | .logGroupName" -r)
$ aws logs tail --follow $logGroupName

# 一時ファイルを生成してアップロードしてローカルのファイルは削除する
# これで lambda が実行されるはず
$ echo "txt_$(date -u +%Y-%m-%d_%H-%M-%S)" > test.txt \
    && aws s3 cp test.txt s3://"target-bucket-${TF_VAR_project_id}"/ \
    && rm test.txt
```

- 関数の更新
```shell
$ tee index.js > /dev/null << 'EOF'
exports.handler = async ({ Records }) => {
    const [event] = Records;
    const { eventTime, eventName, requestParameters, s3 } = event;
    console.log(`eventTime: ${eventTime}, `, `eventName: ${eventName}, `, `sourceIPAddress: ${requestParameters.sourceIPAddress}`);
    
    const { key, size } = s3.object;
    console.log(`key: ${key}, `, `size: ${size}`);
    
    return {
        statusCode: 200,
        body: JSON.stringify('complete!'),
    };
}
EOF

$ zip lambda_function.zip index.js && rm index.js && \
    aws lambda update-function-code \
      --function-name "s3-upload-function-${TF_VAR_project_id}" \
      --zip-file fileb://lambda_function.zip && \
    rm lambda_function.zip
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
