# Talend Remote Engine on Azure - Benchmark Suite

Azure VM 上の Talend Remote Engine で任意のジョブを実行し、リソース使用量（CPU、メモリ、ディスクI/O、ネットワーク）を測定するツールです。

## 使い方の流れ

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. 準備                                                                      │
│    ├─ Azure CLI インストール & ログイン                                       │
│    ├─ Terraform インストール                                                 │
│    └─ SSH キーペア作成                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. インフラ構築 (Terraform)                                                  │
│    ├─ terraform.tfvars.example → terraform.tfvars にコピー & 編集           │
│    ├─ terraform init && terraform apply                                      │
│    └─ → Azure VM、ネットワーク、ストレージが作成される                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. Talend Remote Engine セットアップ (VM内)                                  │
│    ├─ SSH で VM に接続                                                       │
│    ├─ Talend Cloud から Remote Engine をダウンロード → /tmp/ に配置          │
│    ├─ ./scripts/install/install-talend-remote-engine.sh 実行                │
│    └─ Talend Cloud Management Console でペアリング                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. ベンチマーク実行                                                          │
│    ├─ ./benchmark.sh start [name]    # メトリクス収集開始                    │
│    ├─ (Talend Cloud からジョブ実行)                                          │
│    └─ ./benchmark.sh stop            # 収集停止 & レポート生成               │
├─────────────────────────────────────────────────────────────────────────────┤
│ 5. 結果確認                                                                  │
│    ├─ ./benchmark.sh list            # 過去の結果一覧                        │
│    ├─ cat results/<name>/report.md   # レポート                              │
│    └─ cat results/<name>/summary.json                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ 6. クリーンアップ                                                            │
│    └─ terraform destroy              # 全リソース削除                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. 準備

### 必要なツール

| ツール | バージョン | 用途 |
|--------|-----------|------|
| [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) | >= 2.49.0 | Azure 認証・操作 |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5.0 | インフラ構築 |
| SSH クライアント | - | VM 接続 |

### SSH キーペア作成

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/talend-azure-key -N ""
chmod 600 ~/.ssh/talend-azure-key
```

### Azure ログイン

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

---

## 2. インフラ構築

```bash
cd terraform/environments/dev

# 設定ファイル作成
cp terraform.tfvars.example terraform.tfvars

# 編集（リソースグループ名、リージョン、SSH許可IP等）
vi terraform.tfvars

# 構築
terraform init
terraform apply
```

**terraform.tfvars の主要設定**:

```hcl
resource_group_name    = "rg-talend-benchmark-dev"
location               = "japaneast"          # または eastus 等
vm_size                = "Standard_D8s_v5"    # 8vCPU, 32GB RAM
admin_ssh_key_path     = "~/.ssh/talend-azure-key.pub"
allowed_ssh_source_ips = ["YOUR_IP/32"]       # curl https://api.ipify.org で確認
```

---

## 3. Talend Remote Engine セットアップ

### VM に接続

```bash
# Terraform 出力から SSH コマンド取得
terraform output ssh_command

# または直接
ssh -i ~/.ssh/talend-azure-key azureuser@<PUBLIC_IP>
```

### Remote Engine インストール

1. **Talend Cloud Management Console** から Remote Engine (Linux) をダウンロード
2. VM に転送:
   ```bash
   scp -i ~/.ssh/talend-azure-key ~/Downloads/Talend-RemoteEngine-*.zip \
       azureuser@<PUBLIC_IP>:/tmp/talend-remote-engine.zip
   ```
3. インストール実行:
   ```bash
   ./scripts/install/install-talend-remote-engine.sh
   ```

### ペアリング

1. Management Console > Remote Engines > Add Engine
2. Pre-Authorized Key を生成・コピー
3. VM で設定:
   ```bash
   sudo vi /opt/talend/remote-engine/etc/engine.properties
   # talend.remote.engine.pre.authorized.key=<YOUR_KEY>
   ```
4. サービス起動:
   ```bash
   sudo systemctl start talend-remote-engine
   sudo journalctl -u talend-remote-engine -f  # ログ確認
   ```

詳細: [ペアリング手順](talend/pairing/pairing-instructions.md)

---

## 4. ベンチマーク実行

### コマンド一覧

```
./benchmark.sh <command> [options]

  start [name]              メトリクス収集開始
  stop                      メトリクス収集停止、レポート生成
  run "command" [name]      コマンド実行しながらメトリクス収集
  status                    現在の状態確認
  list                      過去の結果一覧
```

### 使用例

```bash
# 方法1: 手動モード（任意の Talend ジョブに対応）
./benchmark.sh start my-etl-job
# → Talend Cloud からジョブを実行
./benchmark.sh stop

# 方法2: 自動モード（コマンド指定）
./benchmark.sh run "python3 my_script.py" python-test

# Azure Monitor メトリクスも取得する場合
VM_RESOURCE_ID="/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/vm-name" \
  ./benchmark.sh start with-azure
```

### 測定項目

| カテゴリ | ツール | メトリクス |
|---------|--------|-----------|
| CPU | sar | 使用率 (user/system/iowait) |
| メモリ | vmstat | 使用量、空き容量 |
| ディスク | iostat | 読み書きスループット |
| ネットワーク | sar | 送受信バイト数 |
| Azure | az monitor | CPU%, メモリ, ディスク, ネットワーク |

---

## 5. 結果確認

```bash
./benchmark.sh list
# 出力例:
# my-etl-job  |  125s  |  CPU: 45.2%
# python-test |  60s   |  CPU: 12.8%

# レポート確認
cat results/my-etl-job/report.md

# JSON データ
cat results/my-etl-job/summary.json
```

**生成ファイル**:
- `summary.json` - 結果サマリー (JSON)
- `report.md` - レポート (Markdown)
- `cpu.log`, `memory.log`, `disk_io.log`, `network.log` - 生ログ
- `azure_metrics.json` - Azure Monitor メトリクス (オプション)

---

## 6. VMサイズ変更

ベンチマーク結果に応じてVMサイズを変更できます。**Talend Remote Engine の再インストールは不要**です。

### 変更手順

```bash
# 方法1: Terraform（推奨）
cd terraform/environments/dev
vi terraform.tfvars  # vm_size = "Standard_D16s_v5" に変更
terraform apply

# 方法2: Azure CLI
az vm deallocate --resource-group rg-talend-benchmark-dev --name vm-talend-dev
az vm resize --resource-group rg-talend-benchmark-dev --name vm-talend-dev --size Standard_D16s_v5
az vm start --resource-group rg-talend-benchmark-dev --name vm-talend-dev
```

### 変更時の影響

| 項目 | 状態 |
|------|------|
| OS / Data ディスク | 保持される |
| Talend Remote Engine | 保持される（再インストール不要） |
| ペアリング設定 | 保持される |
| systemd サービス | 自動起動（enabled設定済み） |

### 変更後の確認

```bash
ssh -i ~/.ssh/talend-azure-key azureuser@<PUBLIC_IP>

# サービス状態確認
sudo systemctl status talend-remote-engine

# 起動していなければ
sudo systemctl start talend-remote-engine

# Talend Cloud との再接続を確認
sudo journalctl -u talend-remote-engine -f
```

### 推奨サイズ

| サイズ | vCPU | メモリ | 月額目安 | 用途 |
|--------|------|--------|----------|------|
| Standard_D4s_v5 | 4 | 16 GB | ~$200 | 小規模テスト |
| Standard_D8s_v5 | 8 | 32 GB | ~$400 | 標準 |
| Standard_D16s_v5 | 16 | 64 GB | ~$800 | 大規模処理 |

---

## 7. クリーンアップ

```bash
cd terraform/environments/dev

# VM 停止のみ（課金停止、データ保持）
az vm deallocate --resource-group rg-talend-benchmark-dev --name vm-talend-dev

# 全リソース削除
terraform destroy
```

---

## プロジェクト構造

```
talend-azure-benchmark/
├── benchmark.sh                    # ベンチマークツール (メイン)
├── results/                        # ベンチマーク結果
├── terraform/
│   ├── environments/dev/           # 環境設定
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── modules/                    # Terraform モジュール
│       ├── network/                # VNet, NSG, Public IP
│       ├── vm/                     # VM, ディスク
│       ├── storage/                # Storage Account
│       └── monitoring/             # Log Analytics
├── scripts/
│   ├── install/
│   │   ├── install-talend-remote-engine.sh
│   │   └── configure-system.sh
│   └── utilities/
│       └── health-check.sh
├── talend/pairing/                 # ペアリング手順
├── monitoring/                     # Azure Dashboard, KQL クエリ
└── docs/                           # ドキュメント
    ├── deployment-guide.md
    ├── architecture.md
    └── troubleshooting.md
```

---

## インフラ構成

```
Azure VNet (10.0.0.0/16)
└── Subnet (10.0.1.0/24)
    └── VM: Standard_D8s_v5 (8 vCPU, 32GB RAM)
        ├── OS: Ubuntu 22.04 LTS
        ├── OS Disk: 128 GB Premium SSD
        ├── Data Disk: 512 GB Premium SSD (/data)
        └── Talend Remote Engine
```

**推定コスト**: 約 $400/月 (東日本リージョン、常時稼働時)

---

## ドキュメント

- [デプロイガイド](docs/deployment-guide.md) - 詳細なデプロイ手順
- [アーキテクチャ](docs/architecture.md) - システム構成の詳細
- [トラブルシューティング](docs/troubleshooting.md) - よくある問題と解決策
- [ペアリング手順](talend/pairing/pairing-instructions.md) - Talend Cloud 接続

---

## ライセンス

MIT License
