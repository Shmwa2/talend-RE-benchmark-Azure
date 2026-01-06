# Talend Remote Engine on Azure - Benchmark Suite

Talend Cloud Remote Engineを Azure VM 上に配置し、ETLバッチ処理のパフォーマンスベンチマークを測定するための完全な実装環境です。

## 概要

このプロジェクトは、以下を提供します:

- **Infrastructure as Code (Terraform)**: Azure VM、ネットワーク、ストレージ、監視を自動構築
- **自動インストール**: Talend Remote Engineのセットアップスクリプト
- **ベンチマークツール**: 総合的なパフォーマンス測定スクリプト
- **監視・可視化**: Azure Monitorとの統合、KQLクエリ集
- **ドキュメント**: デプロイガイド、トラブルシューティング

## アーキテクチャ

```
Azure VNet (10.0.0.0/16)
└── talend-subnet (10.0.1.0/24)
    └── VM: Standard_D8s_v5 (8 vCPU, 32GB RAM)
        ├── OS Disk: Premium SSD 128GB
        ├── Data Disk: Premium SSD 512GB (/data)
        ├── Talend Remote Engine
        └── Benchmark Tools
```

- **VM サイズ**: Standard_D8s_v5 (推奨) - 8 vCPU, 32GB RAM
- **OS**: Ubuntu 22.04 LTS
- **Java**: OpenJDK 11
- **Talend**: Cloud Remote Engine
- **推定コスト**: 約 $400/月 (東日本リージョン)

## 前提条件

- Azure サブスクリプション
- Talend Cloud アカウント (Management Console アクセス権限)
- ローカルマシンに以下がインストール済み:
  - Terraform >= 1.5.0
  - Azure CLI >= 2.49.0
  - SSH クライアント

## クイックスタート

### 1. リポジトリのクローン

```bash
cd ~
git clone <repository-url> talend-azure-benchmark
cd talend-azure-benchmark
```

### 2. Azure 認証

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### 3. Terraform 設定

```bash
cd terraform/environments/dev

# テンプレートから設定ファイルを作成
cp terraform.tfvars.example terraform.tfvars

# 設定ファイルを編集
vi terraform.tfvars
```

**必須設定項目**:
- `resource_group_name`: 既存または新規作成するリソースグループ名
- `location`: Azure リージョン (例: `japaneast`)
- `allowed_ssh_source_ips`: SSH接続を許可するIPアドレス

### 4. インフラ構築

```bash
terraform init
terraform plan
terraform apply
```

実行後、VM の Public IP が出力されます。

### 5. Talend Remote Engine インストール

VMにSSH接続:

```bash
# terraform outputからSSHコマンドを取得
terraform output ssh_command

# または直接接続
ssh -i ~/.ssh/talend-azure-key azureuser@<PUBLIC_IP>
```

Talend Remote Engine をインストール:

```bash
# Talend Remote Engine をダウンロード (Talend Cloud Management Console から)
# /tmp/talend-remote-engine.zip として配置

# インストールスクリプトを実行
cd /path/to/talend-azure-benchmark
./scripts/install/install-talend-remote-engine.sh
```

### 6. ペアリング

Talend Cloud Management Console で:
1. Remote Engines > Add Engine
2. Pre-Authorized Key を生成

VM で:

```bash
vi /opt/talend/remote-engine/etc/engine.properties
# talend.remote.engine.pre.authorized.key=<YOUR_KEY> を設定

sudo systemctl start talend-remote-engine
sudo journalctl -u talend-remote-engine -f
```

詳細は [ペアリング手順書](talend/pairing/pairing-instructions.md) を参照。

### 7. ベンチマーク実行

テストデータを生成:

```bash
cd benchmark/test-data
python3 generate-test-data.py --size 1000 --output medium-1gb.csv
```

ベンチマーク実行:

```bash
cd ../..
./scripts/benchmark/run-benchmark.sh benchmark/scenarios/scenario-2-medium-dataset.json
```

結果は `benchmark/results/<timestamp>/` に保存されます。

## プロジェクト構造

```
talend-azure-benchmark/
├── terraform/              # Infrastructure as Code
│   ├── modules/           # 再利用可能なモジュール
│   │   ├── network/       # VNet, NSG, Public IP
│   │   ├── vm/            # VM, Disk, cloud-init
│   │   ├── storage/       # Storage Account
│   │   └── monitoring/    # Log Analytics, Alerts
│   └── environments/
│       └── dev/           # 開発環境設定
├── scripts/
│   ├── install/           # Talend インストールスクリプト
│   ├── benchmark/         # ベンチマーク実行スクリプト
│   └── utilities/         # ヘルスチェックなど
├── talend/
│   ├── config/            # 設定ファイルテンプレート
│   └── pairing/           # ペアリング手順書
├── benchmark/
│   ├── test-data/         # テストデータ生成
│   ├── scenarios/         # ベンチマークシナリオ (3種)
│   └── results/           # 実行結果
├── monitoring/
│   ├── dashboards/        # Azure Dashboard テンプレート
│   └── queries/           # KQL クエリ集
└── docs/                  # 詳細ドキュメント
```

## ベンチマークシナリオ

| シナリオ | サイズ | レコード数 | 目標実行時間 | 推奨VM |
|---------|--------|-----------|-------------|--------|
| Small | 100MB | 500,000 | < 2分 | D4s_v5 |
| **Medium** | **1GB** | **5,000,000** | **< 5分** | **D8s_v5** |
| Large | 10GB | 50,000,000 | < 30分 | D16s_v5 |

各シナリオは `benchmark/scenarios/` に定義されています。

## 主要コマンド

### Terraform

```bash
# インフラ構築
cd terraform/environments/dev
terraform apply

# インフラ削除
terraform destroy

# 出力確認
terraform output
```

### Talend 管理

```bash
# サービス状態確認
sudo systemctl status talend-remote-engine

# ログ確認
sudo journalctl -u talend-remote-engine -f

# ヘルスチェック
./scripts/utilities/health-check.sh
```

### ベンチマーク

```bash
# テストデータ生成
python3 benchmark/test-data/generate-test-data.py --size 1000 --output test.csv

# ベンチマーク実行
./scripts/benchmark/run-benchmark.sh benchmark/scenarios/scenario-2-medium-dataset.json

# レポート確認
cat benchmark/results/<timestamp>/report.md
```

### 監視

```bash
# Azure Monitor メトリクス取得
az monitor metrics list \
    --resource <VM_RESOURCE_ID> \
    --metric "Percentage CPU" \
    --output table

# KQL クエリ実行
# monitoring/queries/azure-monitor-queries.kql を参照
```

## ドキュメント

- **[デプロイガイド](docs/deployment-guide.md)**: 詳細なデプロイ手順
- **[アーキテクチャ](docs/architecture.md)**: システムアーキテクチャ
- **[ベンチマーク方法論](docs/benchmark-methodology.md)**: 測定方法と分析
- **[トラブルシューティング](docs/troubleshooting.md)**: よくある問題と解決策
- **[ペアリング手順](talend/pairing/pairing-instructions.md)**: Talend Cloud接続

## セキュリティ

- SSH 公開鍵認証のみ (パスワード無効)
- NSG で送信元IP制限
- ディスク暗号化有効 (encryption_at_host_enabled)
- TLS 1.2以上強制
- 機密情報は `.gitignore` で除外

**重要**: 本番環境では、`allowed_ssh_source_ips` を必ず特定IPに制限してください。

## コスト管理

推定月額コスト (Standard_D8s_v5, 東日本):

| リソース | 月額 (USD) |
|---------|-----------|
| VM (D8s_v5) | $280 |
| Premium SSD (640GB) | $95 |
| Storage Account | $5 |
| Log Analytics | $15 |
| **合計** | **約 $400** |

コスト削減策:
- 非稼働時は VM を停止: `az vm deallocate`
- 開発環境は D4s_v5 に変更
- Reserved Instance で最大 40% 削減

## トラブルシューティング

### VM に接続できない

```bash
# NSG ルールを確認
az network nsg rule list \
    --resource-group <RG_NAME> \
    --nsg-name nsg-talend-dev \
    --output table

# SSH キーのパーミッション確認
chmod 600 ~/.ssh/talend-azure-key
```

### Talend ペアリングが失敗

```bash
# ログ確認
sudo journalctl -u talend-remote-engine -f

# ネットワーク接続確認
curl -I https://api.us.cloud.talend.com/

# 設定ファイル確認
cat /opt/talend/remote-engine/etc/engine.properties
```

詳細は [トラブルシューティングガイド](docs/troubleshooting.md) を参照。

## 貢献

Issues や Pull Requests を歓迎します。

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。

## サポート

問題が発生した場合:

1. [トラブルシューティングガイド](docs/troubleshooting.md) を確認
2. ログを確認: `sudo journalctl -u talend-remote-engine -f`
3. GitHub Issues で報告

## 関連リンク

- [Talend Cloud Documentation](https://help.talend.com/category/cloud)
- [Azure Virtual Machines](https://docs.microsoft.com/azure/virtual-machines/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)

---

**作成者**: Your Name
**最終更新**: 2026-01-07
