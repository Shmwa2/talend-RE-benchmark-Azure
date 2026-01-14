# Deployment Guide

Talend Remote Engine on Azure のデプロイ手順を詳細に説明します。

## 前提条件

### 必要なツール

| ツール | バージョン | インストール方法 |
|--------|----------|-----------------|
| Terraform | >= 1.5.0 | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | >= 2.49.0 | [docs.microsoft.com](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| SSH クライアント | - | OS 標準 |

### Azure 権限

デプロイに必要な Azure RBAC ロール:
- **Contributor** (リソースグループレベル以上)
- または以下の個別権限:
  - `Microsoft.Resources/subscriptions/resourceGroups/*`
  - `Microsoft.Compute/virtualMachines/*`
  - `Microsoft.Network/*`
  - `Microsoft.Storage/storageAccounts/*`
  - `Microsoft.OperationalInsights/workspaces/*`

### Talend Cloud

- Talend Cloud アカウント
- Management Console へのアクセス権限
- Remote Engine 追加権限

## Step 1: 環境準備

### 1.1 Azure 認証

```bash
# Azure にログイン
az login

# サブスクリプションを確認
az account list --output table

# 使用するサブスクリプションを設定
az account set --subscription "<SUBSCRIPTION_ID>"

# 確認
az account show
```

### 1.2 SSH キーペア作成

```bash
# SSH キーペアを作成
ssh-keygen -t rsa -b 4096 -f ~/.ssh/talend-azure-key -N ""

# 権限を設定
chmod 600 ~/.ssh/talend-azure-key
chmod 644 ~/.ssh/talend-azure-key.pub

# 公開鍵を確認
cat ~/.ssh/talend-azure-key.pub
```

## Step 2: Terraform 設定

### 2.1 設定ファイルの準備

```bash
cd ~/talend-azure-benchmark/terraform/environments/dev

# テンプレートから設定ファイルを作成
cp terraform.tfvars.example terraform.tfvars

# 設定ファイルを編集
vi terraform.tfvars
```

### 2.2 設定項目

`terraform.tfvars` で設定する主要項目:

```hcl
# リソースグループ名 (新規作成される)
resource_group_name = "rg-talend-benchmark-dev"

# Azure リージョン
location = "japaneast"  # または "eastus"

# 環境識別子
environment = "dev"

# VM サイズ (推奨: Standard_D8s_v5)
vm_size = "Standard_D8s_v5"

# SSH 公開鍵のパス
admin_ssh_key_path = "~/.ssh/talend-azure-key.pub"

# SSH 接続を許可する IP アドレス (本番環境では必ず制限)
allowed_ssh_source_ips = ["YOUR_PUBLIC_IP/32"]

# アラート通知先メールアドレス (オプション)
alert_email = "your-email@example.com"

# タグ
tags = {
  Project     = "Talend Benchmark"
  Environment = "dev"
  Owner       = "your-name"
  ManagedBy   = "Terraform"
}
```

**セキュリティ注意**: `allowed_ssh_source_ips` は必ず特定の IP アドレスに制限してください。

現在の IP アドレスを確認:
```bash
curl https://api.ipify.org
```

## Step 3: インフラ構築

### 3.1 Terraform 初期化

```bash
cd ~/talend-azure-benchmark/terraform/environments/dev

# 初期化
terraform init

# 設定検証
terraform validate
```

### 3.2 実行プラン確認

```bash
# 実行プランを確認
terraform plan

# 出力を保存する場合
terraform plan -out=tfplan
```

### 3.3 リソース作成

```bash
# リソースを作成
terraform apply

# または保存したプランを適用
terraform apply tfplan
```

確認プロンプトで `yes` を入力してください。

### 3.4 出力確認

```bash
# 出力値を確認
terraform output

# SSH コマンドを取得
terraform output ssh_command
```

## Step 4: VM 接続確認

### 4.1 SSH 接続

```bash
# terraform output から取得した SSH コマンドを実行
ssh -i ~/.ssh/talend-azure-key azureuser@<PUBLIC_IP>

# または
$(terraform output -raw ssh_command)
```

### 4.2 初期設定確認

VM に接続後:

```bash
# cloud-init の完了確認
cat /var/log/cloud-init-complete.log

# Java 確認
java -version

# ディスクマウント確認
df -h /data

# ディレクトリ確認
ls -la /opt/talend /data/talend
```

## Step 5: Talend Remote Engine インストール

詳細は [ペアリング手順書](../talend/pairing/pairing-instructions.md) を参照。

### 5.1 インストーラーの準備

1. Talend Cloud Management Console にログイン
2. Remote Engines > Download を選択
3. Linux 用インストーラーをダウンロード
4. SCP で VM に転送:

```bash
scp -i ~/.ssh/talend-azure-key \
    ~/Downloads/Talend-RemoteEngine-*.zip \
    azureuser@<PUBLIC_IP>:/tmp/talend-remote-engine.zip
```

### 5.2 インストール実行

```bash
# VM 上で実行
cd /home/azureuser
./install-talend-remote-engine.sh
```

## Step 6: ベンチマーク実行

### 6.1 ベンチマーク開始

```bash
cd ~/talend-azure-benchmark

# 方法1: 手動モード（任意のジョブ対応）
./benchmark.sh start my-test      # メトリクス収集開始
# Talend Cloud からジョブを実行
./benchmark.sh stop               # メトリクス収集停止、レポート生成

# 方法2: 自動モード（コマンド指定）
./benchmark.sh run "sleep 60" my-test
```

### 6.2 結果確認

```bash
./benchmark.sh list               # 過去の結果一覧
cat results/<name>/report.md      # レポート確認
cat results/<name>/summary.json   # JSON形式
```

## クリーンアップ

### リソース削除

```bash
cd ~/talend-azure-benchmark/terraform/environments/dev

# 削除プランを確認
terraform plan -destroy

# リソースを削除
terraform destroy
```

**注意**: `terraform destroy` は全リソースを削除します。ベンチマーク結果は事前にバックアップしてください。

### 一時停止 (コスト削減)

VM を停止するだけの場合:

```bash
# VM を停止 (課金も停止)
az vm deallocate \
    --resource-group rg-talend-benchmark-dev \
    --name vm-talend-dev

# VM を再開
az vm start \
    --resource-group rg-talend-benchmark-dev \
    --name vm-talend-dev
```

## トラブルシューティング

問題が発生した場合は [トラブルシューティングガイド](./troubleshooting.md) を参照してください。

## 次のステップ

- [アーキテクチャ](./architecture.md) - システム構成の詳細
- [ペアリング手順](../talend/pairing/pairing-instructions.md) - Talend Cloud 接続
