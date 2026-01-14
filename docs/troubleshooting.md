# Troubleshooting Guide

Talend Remote Engine on Azure ベンチマーク環境で発生する可能性のある問題と解決策を説明します。

## Terraform 関連

### terraform init が失敗する

**症状**:
```
Error: Failed to install provider
```

**原因**: プロバイダーのダウンロードに失敗

**解決策**:
```bash
# キャッシュをクリア
rm -rf .terraform
rm .terraform.lock.hcl

# 再初期化
terraform init -upgrade
```

### terraform apply で権限エラー

**症状**:
```
Error: AuthorizationFailed
```

**原因**: Azure 権限不足

**解決策**:
```bash
# 現在のアカウントを確認
az account show

# 権限を確認
az role assignment list --assignee $(az account show --query user.name -o tsv)

# 必要な権限: Contributor (リソースグループレベル以上)
```

### リソースプロバイダー未登録エラー

**症状**:
```
Error: The subscription is not registered to use namespace 'Microsoft.Compute'
```

**解決策**:
```bash
# リソースプロバイダーを登録
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.OperationalInsights

# 登録状態を確認
az provider show --namespace Microsoft.Compute --query registrationState
```

### encryption_at_host_enabled エラー

**症状**:
```
Error: The feature 'EncryptionAtHost' is not enabled for this subscription
```

**解決策**:
```bash
# 機能を有効化
az feature register --namespace Microsoft.Compute --name EncryptionAtHost

# 登録状態を確認 (Registered になるまで待機)
az feature show --namespace Microsoft.Compute --name EncryptionAtHost

# プロバイダーを再登録
az provider register --namespace Microsoft.Compute
```

または、`encryption_at_host_enabled = false` に設定。

## SSH 接続

### VM に接続できない

**症状**:
```
ssh: connect to host <IP> port 22: Connection timed out
```

**確認事項**:

1. **NSG ルール確認**:
```bash
az network nsg rule list \
    --resource-group rg-talend-benchmark-dev \
    --nsg-name nsg-talend-dev \
    --output table
```

2. **自分の IP 確認**:
```bash
curl https://api.ipify.org
```

3. **terraform.tfvars の設定確認**:
```hcl
allowed_ssh_source_ips = ["YOUR_IP/32"]
```

4. **VM 状態確認**:
```bash
az vm show \
    --resource-group rg-talend-benchmark-dev \
    --name vm-talend-dev \
    --query powerState
```

### SSH キーが拒否される

**症状**:
```
Permission denied (publickey)
```

**解決策**:
```bash
# キーのパーミッション確認
ls -la ~/.ssh/talend-azure-key*

# パーミッション修正
chmod 600 ~/.ssh/talend-azure-key
chmod 644 ~/.ssh/talend-azure-key.pub

# 正しいユーザー名で接続
ssh -i ~/.ssh/talend-azure-key azureuser@<IP>

# デバッグモードで接続
ssh -vvv -i ~/.ssh/talend-azure-key azureuser@<IP>
```

## VM 内部

### cloud-init が完了していない

**確認方法**:
```bash
# cloud-init のステータス確認
cloud-init status

# ログ確認
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/cloud-init.log

# 完了確認
cat /var/log/cloud-init-complete.log
```

### データディスクがマウントされていない

**症状**:
```
$ df -h /data
df: /data: No such file or directory
```

**解決策**:
```bash
# ディスクを確認
lsblk

# ディスクをフォーマット (注意: データが消える)
sudo mkfs.ext4 -F /dev/sdc

# マウントポイント作成
sudo mkdir -p /data

# マウント
sudo mount /dev/sdc /data

# 永続化
echo '/dev/sdc /data ext4 defaults,nofail 0 0' | sudo tee -a /etc/fstab

# ディレクトリ作成
sudo mkdir -p /data/talend/{work,logs,temp}
sudo chown -R azureuser:azureuser /data/talend
```

### Java が見つからない

**症状**:
```
java: command not found
```

**解決策**:
```bash
# Java インストール状態確認
which java
java -version

# インストール
sudo apt update
sudo apt install -y openjdk-11-jdk

# JAVA_HOME 設定
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> ~/.bashrc
source ~/.bashrc
```

## Talend Remote Engine

### エンジンが起動しない

**症状**:
```
$ sudo systemctl status talend-remote-engine
● talend-remote-engine.service - Talend Remote Engine
   Active: failed
```

**確認事項**:

1. **ログ確認**:
```bash
sudo journalctl -u talend-remote-engine -f
tail -f /opt/talend/remote-engine/logs/*.log
```

2. **設定ファイル確認**:
```bash
cat /opt/talend/remote-engine/etc/engine.properties
```

3. **Java ヒープサイズ調整**:
```bash
vi /opt/talend/remote-engine/etc/setenv
# JAVA_OPTS="-Xmx8g -Xms4g"
```

4. **再起動**:
```bash
sudo systemctl restart talend-remote-engine
```

### Talend Cloud にペアリングできない

**症状**:
Engine が "Pending" のまま

**確認事項**:

1. **ネットワーク接続**:
```bash
# Talend Cloud API への接続確認
curl -I https://api.us.cloud.talend.com/
curl -I https://api.eu.cloud.talend.com/

# DNS 解決確認
nslookup api.us.cloud.talend.com
```

2. **Pre-Authorized Key 確認**:
```bash
grep "pre.authorized.key" /opt/talend/remote-engine/etc/engine.properties
```

3. **ファイアウォール確認**:
```bash
# アウトバウンド 443 が許可されているか
sudo iptables -L OUTPUT -n | grep 443
```

### ジョブが実行されない

**確認事項**:

1. **Engine ステータス確認**:
   - Talend Cloud Management Console で Engine の状態を確認

2. **ローカルログ確認**:
```bash
tail -f /opt/talend/remote-engine/logs/engine.log
tail -f /opt/talend/remote-engine/logs/jobs/*.log
```

3. **ディスク容量確認**:
```bash
df -h
```

## ベンチマーク

### テストデータ生成が遅い

**解決策**:
```bash
# Python の高速化オプション
python3 -O generate-test-data.py --size 1000 --output test.csv

# または、既存のテストデータを使用
wget https://example.com/sample-data.csv
```

### メトリクス収集が失敗

**確認事項**:
```bash
# sysstat が有効か確認
sudo systemctl status sysstat

# 有効化
sudo systemctl enable sysstat
sudo systemctl start sysstat

# sar コマンド確認
sar -u 1 5
```

### Out of Memory エラー

**症状**:
```
java.lang.OutOfMemoryError: Java heap space
```

**解決策**:

1. **JVM ヒープサイズ増加**:
```bash
vi /opt/talend/remote-engine/etc/setenv
# JAVA_OPTS="-Xmx16g -Xms8g"
```

2. **スワップ追加**:
```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

3. **VM サイズ変更**: より多くのメモリを持つ VM に変更

## Azure Monitor

### メトリクスが表示されない

**確認事項**:

1. **Log Analytics エージェント確認**:
```bash
az vm extension list \
    --resource-group rg-talend-benchmark-dev \
    --vm-name vm-talend-dev \
    --output table
```

2. **診断設定確認**:
```bash
az monitor diagnostic-settings list \
    --resource-type Microsoft.Compute/virtualMachines \
    --resource rg-talend-benchmark-dev/vm-talend-dev
```

### アラートが発火しない

**確認事項**:

1. **Action Group 確認**:
```bash
az monitor action-group list \
    --resource-group rg-talend-benchmark-dev
```

2. **アラートルール確認**:
```bash
az monitor metrics alert list \
    --resource-group rg-talend-benchmark-dev
```

3. **メールアドレス確認**: spam フォルダを確認

## よくある質問

### Q: VM を停止してもコストはかかりますか?

A: `az vm stop` では課金が続きます。`az vm deallocate` を使用してください。

```bash
# 課金を停止する正しい方法
az vm deallocate \
    --resource-group rg-talend-benchmark-dev \
    --name vm-talend-dev
```

### Q: terraform destroy が途中で止まる

A: リソースの依存関係が原因の可能性があります。

```bash
# 強制削除
terraform destroy -auto-approve

# または、Azure Portal から直接リソースグループを削除
az group delete --name rg-talend-benchmark-dev --yes --no-wait
```

### Q: 複数の環境を作りたい

A: 新しい環境ディレクトリを作成:

```bash
cp -r terraform/environments/dev terraform/environments/prod
cd terraform/environments/prod
vi terraform.tfvars  # 環境固有の値を設定
terraform init
terraform apply
```

## サポート

問題が解決しない場合:

1. ログを収集:
```bash
# システムログ
sudo journalctl --since "1 hour ago" > /tmp/system.log

# Talend ログ
tar -czf /tmp/talend-logs.tar.gz /opt/talend/remote-engine/logs/

# cloud-init ログ
sudo tar -czf /tmp/cloud-init-logs.tar.gz /var/log/cloud-init*
```

2. GitHub Issues で報告

3. Talend サポートに連絡 (ライセンス契約がある場合)

## 関連ドキュメント

- [デプロイガイド](./deployment-guide.md)
- [アーキテクチャ](./architecture.md)
- [ベンチマーク方法論](./benchmark-methodology.md)
