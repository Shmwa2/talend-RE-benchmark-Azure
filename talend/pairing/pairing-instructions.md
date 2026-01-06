# Talend Remote Engine ペアリング手順

このドキュメントでは、Azure VM上のTalend Remote EngineをTalend Cloud Management Consoleとペアリングする手順を説明します。

## 前提条件

- Talend Cloudアカウントとアクセス権限
- Talend Remote Engineがインストール済み
- インターネット接続（HTTPS 443ポート）

## ステップ 1: Management Consoleでペアリングキーを生成

1. Talend Cloud Management Consoleにログイン
   ```
   https://cloud.talend.com/
   ```

2. 左側メニューから **Management** > **Remote Engines** を選択

3. **Add Engine** ボタンをクリック

4. Engine情報を入力:
   - **Name**: `azure-benchmark-engine-dev` (環境に応じて変更)
   - **Description**: Talend Remote Engine for Azure benchmark
   - **Environment**: Development (または該当する環境)

5. **Pre-Authorized Key** を生成してコピー
   - 形式: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - このキーは一度しか表示されないため、必ず安全に保存してください

## ステップ 2: VMでペアリングキーを設定

### 方法 1: 設定ファイルに直接記載

1. VMにSSH接続
   ```bash
   ssh -i ~/.ssh/talend-azure-key azureuser@<PUBLIC_IP>
   ```

2. Engine設定ファイルを編集
   ```bash
   sudo vi /opt/talend/remote-engine/etc/engine.properties
   ```

3. 以下の行を追加または編集
   ```properties
   talend.remote.engine.pre.authorized.key=<YOUR_PAIRING_KEY>
   talend.remote.engine.name=azure-benchmark-engine-dev
   ```

4. ファイルを保存して終了 (`:wq`)

### 方法 2: テンプレートから設定ファイルを生成（推奨）

1. プロジェクトのテンプレートをVMにコピー
   ```bash
   scp -i ~/.ssh/talend-azure-key \
       talend/config/engine.properties.template \
       azureuser@<PUBLIC_IP>:/tmp/engine.properties
   ```

2. VMで編集
   ```bash
   ssh -i ~/.ssh/talend-azure-key azureuser@<PUBLIC_IP>
   vi /tmp/engine.properties

   # YOUR_PAIRING_KEY_HERE を実際のキーに置換
   ```

3. 本番の設定ファイルに配置
   ```bash
   sudo cp /tmp/engine.properties /opt/talend/remote-engine/etc/
   sudo chown azureuser:azureuser /opt/talend/remote-engine/etc/engine.properties
   sudo chmod 600 /opt/talend/remote-engine/etc/engine.properties
   ```

## ステップ 3: Remote Engineサービスを起動

1. サービスを起動
   ```bash
   sudo systemctl start talend-remote-engine
   ```

2. ステータスを確認
   ```bash
   sudo systemctl status talend-remote-engine
   ```

3. ログでペアリング状況を確認
   ```bash
   sudo journalctl -u talend-remote-engine -f
   ```

   成功時の出力例:
   ```
   INFO  [main] o.t.r.engine.Engine - Remote Engine started successfully
   INFO  [main] o.t.r.engine.Pairing - Pairing with Talend Cloud...
   INFO  [main] o.t.r.engine.Pairing - Pairing successful
   ```

## ステップ 4: Management Consoleで確認

1. Management Console > Remote Engines ページに戻る

2. エンジン一覧で、あなたのエンジンを確認
   - **Status**: **Running** (緑色のアイコン)
   - **Version**: インストールしたバージョン
   - **Last Contact**: 数秒前

3. エンジンをクリックして詳細を表示
   - CPU使用率
   - メモリ使用率
   - 実行中のジョブ数

## トラブルシューティング

### ペアリングが失敗する

**症状**: ログに "Pairing failed" または "Connection refused" が表示される

**原因と対処**:

1. **ペアリングキーが無効**
   - Management Consoleで新しいキーを生成
   - 設定ファイルを更新して再起動

2. **ネットワーク接続の問題**
   - HTTPS (443) ポートがブロックされていないか確認
   ```bash
   curl -I https://api.us.cloud.talend.com/
   ```

3. **リージョンが間違っている**
   - `talend.cloud.url` が正しいリージョンを指しているか確認
   - US: `https://api.us.cloud.talend.com`
   - EU: `https://api.eu.cloud.talend.com`
   - AP: `https://api.ap.cloud.talend.com`

### エンジンが "Unavailable" と表示される

**原因と対処**:

1. **サービスが停止している**
   ```bash
   sudo systemctl restart talend-remote-engine
   ```

2. **メモリ不足**
   ```bash
   free -h
   dmesg | grep -i "out of memory"
   ```
   - JVMヒープサイズを調整 (`-Xmx` パラメータ)

3. **ログで詳細を確認**
   ```bash
   tail -f /data/talend/logs/talend-engine.log
   ```

### ペアリング後もジョブが実行されない

1. **タスク割り当ての確認**
   - Management Consoleでジョブがこのエンジンに割り当てられているか確認

2. **ワークスペース権限の確認**
   ```bash
   ls -la /data/talend/work
   # azureuser が所有者であることを確認
   ```

3. **ディスク容量の確認**
   ```bash
   df -h /data
   ```

## セキュリティのベストプラクティス

1. **ペアリングキーの管理**
   - 設定ファイルの権限を制限
     ```bash
     chmod 600 /opt/talend/remote-engine/etc/engine.properties
     ```
   - キーをGitにコミットしない（.gitignoreで除外）

2. **Azure Key Vaultの使用（オプション）**
   - ペアリングキーをKey Vaultに保存
   - Managed Identityで取得
   ```bash
   az keyvault secret set \
       --vault-name <VAULT_NAME> \
       --name talend-pairing-key \
       --value "<YOUR_PAIRING_KEY>"
   ```

## 次のステップ

ペアリングが成功したら:

1. ベンチマークジョブをデプロイ
2. テスト実行で動作確認
3. 本格的なベンチマーク測定を開始

詳細は [deployment-guide.md](../../docs/deployment-guide.md) を参照してください。
