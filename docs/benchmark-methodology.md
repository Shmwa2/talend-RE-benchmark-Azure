# Benchmark Methodology

Talend Remote Engine のパフォーマンスベンチマーク方法論を説明します。

## 概要

このベンチマークは、Talend Remote Engine を使用した ETL 処理のパフォーマンスを測定・評価するために設計されています。

### 測定目的

1. **基準値の確立**: 異なる VM サイズでの処理性能ベースライン
2. **ボトルネック特定**: CPU, メモリ, I/O のどこが制約になるか
3. **最適化指針**: コスト対効果の高い構成の選定
4. **キャパシティ計画**: 本番ワークロードに必要なリソース見積もり

## ベンチマークシナリオ

### シナリオ概要

| シナリオ | データサイズ | レコード数 | 目標時間 | 推奨 VM |
|---------|------------|-----------|---------|---------|
| Small | 100 MB | 500,000 | < 2 分 | D4s_v5 |
| **Medium** | **1 GB** | **5,000,000** | **< 5 分** | **D8s_v5** |
| Large | 10 GB | 50,000,000 | < 30 分 | D16s_v5 |

### シナリオ詳細

#### Scenario 1: Small Dataset

**目的**: 基本的な処理性能の確認

```json
{
  "name": "scenario-1-small-dataset",
  "description": "Small dataset benchmark - 100MB CSV processing",
  "data_size_mb": 100,
  "record_count": 500000,
  "iterations": 3,
  "warmup_runs": 1
}
```

**測定内容**:
- コールドスタート性能
- JVM ウォームアップ後の性能
- 小規模データでのオーバーヘッド

#### Scenario 2: Medium Dataset (推奨)

**目的**: 本番ワークロードに近い処理性能の評価

```json
{
  "name": "scenario-2-medium-dataset",
  "description": "Medium dataset benchmark - 1GB CSV processing",
  "data_size_mb": 1000,
  "record_count": 5000000,
  "iterations": 3,
  "warmup_runs": 1
}
```

**測定内容**:
- 持続的な処理スループット
- メモリ使用パターン
- I/O ボトルネック

#### Scenario 3: Large Dataset

**目的**: 大規模データ処理の限界評価

```json
{
  "name": "scenario-3-large-dataset",
  "description": "Large dataset benchmark - 10GB CSV processing",
  "data_size_mb": 10000,
  "record_count": 50000000,
  "iterations": 2,
  "warmup_runs": 1
}
```

**測定内容**:
- 長時間処理の安定性
- メモリ圧力下での挙動
- スケーラビリティ特性

## 測定メトリクス

### パフォーマンスメトリクス

| メトリクス | 単位 | 説明 |
|-----------|------|------|
| Execution Time | 秒 | 処理開始から完了までの時間 |
| Throughput | records/sec | 1 秒あたりの処理レコード数 |
| Data Rate | MB/sec | 1 秒あたりの処理データ量 |

### リソースメトリクス

| メトリクス | 単位 | 説明 |
|-----------|------|------|
| CPU Usage | % | CPU 使用率 (平均/最大) |
| Memory Usage | GB | メモリ使用量 (平均/最大) |
| Disk Read | MB/sec | ディスク読み取り速度 |
| Disk Write | MB/sec | ディスク書き込み速度 |
| Network In | MB/sec | ネットワーク受信量 |
| Network Out | MB/sec | ネットワーク送信量 |

### 派生メトリクス

| メトリクス | 計算式 | 説明 |
|-----------|--------|------|
| CPU Efficiency | throughput / cpu_usage | CPU 効率 |
| Memory Efficiency | throughput / memory_usage | メモリ効率 |
| Cost Efficiency | throughput / hourly_cost | コスト効率 |

## テストデータ

### データ構造

テストデータは以下のスキーマの CSV ファイル:

```csv
id,timestamp,customer_id,product_id,quantity,unit_price,total_amount,status,region
```

| カラム | 型 | 説明 |
|--------|---|------|
| id | INTEGER | 一意の識別子 |
| timestamp | DATETIME | トランザクション日時 |
| customer_id | STRING | 顧客 ID |
| product_id | STRING | 商品 ID |
| quantity | INTEGER | 数量 |
| unit_price | DECIMAL | 単価 |
| total_amount | DECIMAL | 合計金額 |
| status | STRING | ステータス |
| region | STRING | 地域 |

### データ生成

```bash
cd ~/talend-azure-benchmark/benchmark/test-data

# Small (100MB, 500K records)
python3 generate-test-data.py --size 100 --output small-100mb.csv

# Medium (1GB, 5M records)
python3 generate-test-data.py --size 1000 --output medium-1gb.csv

# Large (10GB, 50M records)
python3 generate-test-data.py --size 10000 --output large-10gb.csv
```

## 実行手順

### 1. 事前準備

```bash
# システム状態の確認
./scripts/utilities/health-check.sh

# 他のプロセスを停止
sudo systemctl stop unnecessary-service

# キャッシュのクリア
sudo sync && sudo sysctl -w vm.drop_caches=3
```

### 2. ウォームアップ

```bash
# JVM ウォームアップのためのテスト実行
./scripts/benchmark/run-benchmark.sh benchmark/scenarios/scenario-1-small-dataset.json --warmup-only
```

### 3. ベンチマーク実行

```bash
# メトリクス収集を開始
./scripts/benchmark/collect-metrics.sh start &

# ベンチマーク実行
./scripts/benchmark/run-benchmark.sh benchmark/scenarios/scenario-2-medium-dataset.json

# メトリクス収集を停止
./scripts/benchmark/collect-metrics.sh stop
```

### 4. レポート生成

```bash
# レポート生成
./scripts/benchmark/generate-report.sh benchmark/results/<timestamp>/

# 結果確認
cat benchmark/results/<timestamp>/report.md
```

## 結果分析

### 期待値との比較

| シナリオ | 目標 | 許容範囲 |
|---------|------|---------|
| Small (D8s_v5) | < 2 分 | 1-3 分 |
| Medium (D8s_v5) | < 5 分 | 3-8 分 |
| Large (D8s_v5) | < 30 分 | 20-45 分 |

### ボトルネック判定

| 状況 | CPU | Memory | Disk I/O | 判定 |
|------|-----|--------|----------|------|
| CPU > 90%, Memory < 70% | High | Low | - | CPU バウンド |
| CPU < 50%, Memory > 90% | Low | High | - | メモリバウンド |
| CPU < 50%, Memory < 70%, Disk > 90% | Low | Low | High | I/O バウンド |

### 推奨アクション

**CPU バウンド**:
- より多くの vCPU を持つ VM に変更
- 並列処理の最適化

**メモリバウンド**:
- より多くのメモリを持つ VM に変更
- JVM ヒープサイズの調整
- バッチサイズの縮小

**I/O バウンド**:
- Premium SSD への変更
- Ultra Disk の検討
- データディスクの追加

## レポートフォーマット

### サマリーレポート

```markdown
# Benchmark Report

## Summary
- **Scenario**: Medium Dataset (1GB)
- **Date**: 2026-01-14 10:30:00
- **Duration**: 4m 32s
- **Status**: PASS

## Performance
| Metric | Value |
|--------|-------|
| Total Records | 5,000,000 |
| Throughput | 18,382 records/sec |
| Data Rate | 3.67 MB/sec |

## Resource Usage
| Metric | Average | Peak |
|--------|---------|------|
| CPU | 72% | 95% |
| Memory | 18 GB | 24 GB |
| Disk Read | 45 MB/s | 120 MB/s |
| Disk Write | 30 MB/s | 80 MB/s |

## Recommendation
Current VM size (D8s_v5) is appropriate for this workload.
```

## ベストプラクティス

### 測定の一貫性

1. **ウォームアップ**: 必ず 1 回以上のウォームアップ実行
2. **複数回実行**: 最低 3 回実行して平均を取る
3. **外乱の排除**: 他のプロセスを停止
4. **時間帯**: Azure のピーク時間を避ける

### 結果の解釈

1. **外れ値の除外**: 最大/最小を除いた平均
2. **標準偏差の確認**: ばらつきが大きい場合は再測定
3. **トレンド分析**: 複数回の測定結果を比較

## 関連ドキュメント

- [デプロイガイド](./deployment-guide.md)
- [アーキテクチャ](./architecture.md)
- [トラブルシューティング](./troubleshooting.md)
