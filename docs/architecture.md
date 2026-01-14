# Architecture

Talend Remote Engine on Azure ベンチマーク環境のアーキテクチャを説明します。

## システム全体図

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                    Azure Subscription                        │
                    │  ┌───────────────────────────────────────────────────────┐  │
                    │  │              Resource Group (rg-talend-benchmark-dev)  │  │
                    │  │                                                        │  │
                    │  │   ┌──────────────────────────────────────────────┐   │  │
                    │  │   │           Virtual Network (10.0.0.0/16)       │   │  │
                    │  │   │                                               │   │  │
                    │  │   │   ┌───────────────────────────────────┐      │   │  │
                    │  │   │   │     Subnet (10.0.1.0/24)          │      │   │  │
                    │  │   │   │                                    │      │   │  │
┌──────────┐       │  │   │   │   ┌─────────────────────────┐    │      │   │  │
│  User    │──SSH──│──│───│───│───│    Linux VM             │    │      │   │  │
│ Machine  │       │  │   │   │   │    Standard_D8s_v5      │    │      │   │  │
└──────────┘       │  │   │   │   │    ┌─────────────────┐  │    │      │   │  │
                   │  │   │   │   │    │ Talend Remote   │  │    │      │   │  │
                   │  │   │   │   │    │ Engine          │  │────│──────│───│──│───▶ Talend Cloud
                   │  │   │   │   │    └─────────────────┘  │    │      │   │  │
                   │  │   │   │   │    ┌─────────────────┐  │    │      │   │  │
                   │  │   │   │   │    │ Data Disk       │  │    │      │   │  │
                   │  │   │   │   │    │ 512GB Premium   │  │    │      │   │  │
                   │  │   │   │   │    └─────────────────┘  │    │      │   │  │
                   │  │   │   │   └─────────────────────────┘    │      │   │  │
                   │  │   │   │              │ NSG               │      │   │  │
                   │  │   │   └──────────────│───────────────────┘      │   │  │
                   │  │   │                  │                          │   │  │
                   │  │   └──────────────────│──────────────────────────┘   │  │
                   │  │                      │                              │  │
                   │  │   ┌──────────────────▼──────────────────────────┐  │  │
                   │  │   │  Storage Account        Log Analytics       │  │  │
                   │  │   │  - benchmark-results    - VM Metrics        │  │  │
                   │  │   │  - logs                 - Alerts            │  │  │
                   │  │   │  - test-data                                │  │  │
                   │  │   └─────────────────────────────────────────────┘  │  │
                   │  └────────────────────────────────────────────────────┘  │
                   └──────────────────────────────────────────────────────────┘
```

## コンポーネント詳細

### 1. Virtual Network (VNet)

| 項目 | 設定値 |
|------|--------|
| 名前 | vnet-talend-dev |
| アドレス空間 | 10.0.0.0/16 |
| サブネット | snet-talend-dev (10.0.1.0/24) |

**設計理由**:
- /16 のアドレス空間で将来の拡張に対応
- 単一サブネットでシンプルな構成
- 必要に応じて追加サブネット (DB, App 層など) を追加可能

### 2. Network Security Group (NSG)

| ルール名 | 方向 | ポート | 送信元 | 目的 |
|---------|------|--------|--------|------|
| AllowSSH | Inbound | 22 | 指定 IP | 管理アクセス |
| AllowHTTPSOutbound | Outbound | 443 | * | Talend Cloud 接続 |

**セキュリティ考慮事項**:
- SSH は特定 IP からのみ許可
- アウトバウンド HTTPS は Talend Cloud API への接続に必要
- 追加のインバウンドルールは必要に応じて追加

### 3. Virtual Machine

| 項目 | 設定値 |
|------|--------|
| サイズ | Standard_D8s_v5 |
| vCPU | 8 |
| メモリ | 32 GB |
| OS | Ubuntu 22.04 LTS |
| OS ディスク | 128 GB Premium SSD |
| データディスク | 512 GB Premium SSD |

**VM サイズの選定理由**:
- D-series: 汎用ワークロードに最適
- v5: 最新世代で価格性能比が高い
- s サフィックス: Premium Storage 対応

**推奨サイズ一覧**:

| シナリオ | VM サイズ | vCPU | メモリ | 用途 |
|---------|----------|------|--------|------|
| Small | Standard_D4s_v5 | 4 | 16 GB | 開発・テスト |
| **Medium** | **Standard_D8s_v5** | **8** | **32 GB** | **本番推奨** |
| Large | Standard_D16s_v5 | 16 | 64 GB | 高負荷ワークロード |

### 4. Storage Account

| コンテナ | 用途 | 保持期間 |
|---------|------|---------|
| benchmark-results | ベンチマーク結果 | 90 日 |
| logs | ログファイル | 30 日 |
| test-data | テストデータ | 無期限 |
| configs | 設定バックアップ | 無期限 |

**設定**:
- アカウント種別: StorageV2
- レプリケーション: LRS (ローカル冗長)
- TLS: 1.2 以上必須
- ライフサイクルポリシー: 自動クリーンアップ

### 5. Log Analytics Workspace

| 項目 | 設定値 |
|------|--------|
| SKU | PerGB2018 |
| 保持期間 | 30 日 |

**収集メトリクス**:
- CPU 使用率
- メモリ使用量
- ディスク I/O
- ネットワーク I/O

**アラート設定**:
- CPU > 90% (5 分間平均)
- 空きメモリ < 1 GB
- ディスク使用率 > 85%

## Terraform モジュール構成

```
terraform/
├── environments/
│   └── dev/
│       ├── main.tf          # メインオーケストレーション
│       ├── variables.tf     # 変数定義
│       ├── outputs.tf       # 出力定義
│       └── terraform.tfvars # 環境固有値
└── modules/
    ├── network/             # VNet, NSG, Public IP
    ├── vm/                  # VM, ディスク, cloud-init
    ├── storage/             # Storage Account
    └── monitoring/          # Log Analytics, アラート
```

**モジュール設計原則**:
1. **単一責任**: 各モジュールは一つの機能に特化
2. **再利用性**: 変数によるパラメータ化
3. **依存関係の明確化**: outputs による連携

## データフロー

### ベンチマーク実行時

```
1. テストデータ生成
   └─▶ /data/talend/work/test-data/

2. Talend ジョブ実行
   └─▶ Talend Cloud からジョブ定義を取得
   └─▶ ローカルでデータ処理
   └─▶ 結果を出力

3. メトリクス収集
   └─▶ CPU, メモリ, I/O を記録
   └─▶ /data/talend/logs/

4. 結果保存
   └─▶ Storage Account (benchmark-results)
   └─▶ ローカル (/home/azureuser/benchmark/results/)
```

## セキュリティ設計

### ネットワークセキュリティ

- NSG によるトラフィック制御
- SSH は公開鍵認証のみ
- パスワード認証は無効

### データセキュリティ

- ディスク暗号化 (encryption_at_host_enabled)
- Storage Account は HTTPS のみ
- TLS 1.2 以上強制

### アクセス制御

- SSH アクセスは IP 制限
- Talend Cloud 認証はトークンベース

## 拡張オプション

### Azure Bastion 追加

パブリック IP を削除し、Azure Bastion 経由でアクセス:

```hcl
resource "azurerm_bastion_host" "talend_bastion" {
  name                = "bastion-talend-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}
```

### Private Endpoint

Storage Account へのプライベート接続:

```hcl
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-storage-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.talend_storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}
```

## 関連ドキュメント

- [デプロイガイド](./deployment-guide.md)
- [トラブルシューティング](./troubleshooting.md)
