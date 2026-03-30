# `mpconfig.toml` マニュアル

このドキュメントでは、Money Printer のメイン設定ファイルと、ボットが実行時にそれをどのように使用するかを説明します。

以下のファイルとあわせて使用してください。
- [`../mpconfig.example.toml`](../mpconfig.example.toml)
- [`../config/README.md`](../config/README.md)

## 目的

`mpconfig.toml` はオペレーター向けのメイン設定ファイルです。以下を定義します。
- ウォレットの場所
- information RPC endpoints
- トランザクション送信チャネル
- sender の認証情報
- 外部設定ソース
- 実行時に調整可能な値と placeholder バインディング

このファイルは起動時に一度だけ読み込まれます。変更は監視されません。`mpconfig.toml` を編集した場合は、ボットを再起動してください。

## ボットが設定ファイルを見つける方法

Money Printer は、メイン設定ファイルのパスを次の順序で解決します。

1. 環境変数 `MP_CONFIG`
2. `--config <path>`、`-c <path>`、または `--config=<path>`
3. 実行ファイルの隣にある `mpconfig.toml`

重要:
- `MP_CONFIG` はコマンドライン引数より優先されます。
- override が指定されていない場合、ボットはバイナリと同じディレクトリに `mpconfig.toml` があることを前提とします。

## 静的フィールドと Runtime バインド可能フィールド

コードは以下を区別します。
- startup-fixed fields: 起動時に読み込まれ、hot reload では再読み込みされないリテラル値
- bindable fields: リテラルとして直接書くことも、`misc` JSON から `{enable_cu_limit}` のような placeholder で参照することもできる値

### 起動時固定フィールド

これらのフィールドは `mpconfig.toml` 内でリテラルな文字列または数値でなければなりません。`{placeholder}` 構文は使用できません。

- `info_rpc`
- `info_rpc_fallback`
- `base_token`
- `key_pair.path_to_secret`
- `server_config.server_enabled`
- `server_config.password`
- `server_config.port`
- `external_config.markets`
- `external_config.lut`
- `external_config.misc`
- `local_config.markets`
- `local_config.lut`
- `rpc_config.endpoint`
- `rpc_config.auth`
- `jito_config.endpoint`
- `jito_config.auth`
- `helius_config.api_key`
- `flashblock_config.auth`
- `astra_config.api_key`
- `temporal_config.client_id`
- `hellomoon_config.api_key`

これらのいずれかを変更するには、`mpconfig.toml` を編集し、プロセスを再起動する必要があります。

### Bindable フィールド

多くの運用値は、次のどちらかの方法で指定できます。
- 直接記述する。例: `cu_limit = 350000`
- 参照で記述する。例: `cu_limit = "{enable_cu_limit}"`

placeholder 構文を使用した場合、その値は `external_config.misc` から読み込まれた JSON ドキュメントから解決されます。

placeholder が使われているのに JSON ファイルが存在しない、壊れている、または参照先のキーが存在しない場合、設定解決は失敗します。

## Placeholder バインディング

placeholder の構文は次のとおりです。

```toml
cu_limit = "{enable_cu_limit}"
```

対応する JSON:

```json
{
  "enable_cu_limit": 350000
}
```

注意:
- placeholder 名は大文字小文字を区別します
- placeholders は bindable values として実装されたフィールドでのみ動作します
- 型は対象フィールドと一致している必要があります
- placeholder の解決は、`misc` から runtime 設定を構築または再構築するときに行われます

## 外部設定と Hot Reload

Money Printer は 3 つの外部ソースをサポートします。
- markets file
- LUT file
- misc JSON file

これらは `[external_config]` で設定します。

### `use_external_data = true` の場合

ボットは設定された外部ソースをポーリングし、実行時に再読み込みします。

現在の挙動:
- ローカルファイルパスと `http://` / `https://` URL をサポートします
- ポーリング間隔は `external_config.poll_interval_ms` です
- 変更は、同じ内容が 2 回連続して観測された場合にのみ適用されます
  これは小さな debounce のように動作し、書き込み途中の内容を読み込むことを避けます

ファイル種別ごとの再読み込み挙動:
- `markets`: 市場ユニバースが再読み込みされ、pool データベースが再構築されます
- `lut`: lookup tables が再読み込みされ、トランザクション LUT キャッシュが更新されます
- `misc`: runtime 値が再解決され、ボットを再起動せずに再公開されます

メインの `mpconfig.toml` ファイル自体は再読み込みされません。

### `use_external_data = false` の場合

ボットは外部ファイルを監視しませんが、いくつかのパスは起動時の一回限りのソースとして使用される場合があります。

現在の起動時挙動:
- `local_config.markets` と `local_config.lut` は、一回限りの起動時読み込みソースとして優先されます
- `local_config` が存在しない場合でも、`external_config.markets` と `external_config.lut` は一回限りの起動時入力として使われることがあります
- `external_config.misc` も placeholder 解決のために起動時に一度だけ読み込まれる場合があります

つまり、設定で `{placeholder}` 形式の値を使っている場合、監視しないモードでも `external_config.misc` は重要です。

## 一般的な値の規約

- tip 値は raw lamports で指定します
- priority fee の範囲もトランザクション単位の raw lamports で指定します
- 内部的には priority fee は compute-budget price 値に変換されます
- cooldown 値はミリ秒単位です
- endpoint のリストはリテラルな URL です

## トップレベルフィールド

### `use_external_data`

Type: `bool`

設定された外部ソースを監視し、実行時に再読み込みするかどうかを制御します。

推奨:
- `true`: markets 一覧、LUT、runtime チューニング値に hot reload を使いたい場合
- `false`: 起動時のみ有効な静的設定にしたい場合

### `base_token`

Type: `string`

ベース取引 mint。実運用上、現在のコードと example 設定は WSOL を前提にしています。

例:

```toml
base_token = "So11111111111111111111111111111111111111112"
```

### `info_rpc`

Type: `string`

主 information RPC endpoint。以下に使用されます。
- accounts の読み取り
- markets の読み込み
- recent blockhash の取得
- その他の非送信系情報クエリ

通常、ここには最も優れた読み取り向け endpoint を設定すべきです。

### `info_rpc_fallback`

Type: `string`, optional

information RPC 用の任意の fallback です。

現在の挙動:
- プライマリ endpoint が 3 回連続で失敗すると
- ボットは 30 秒間 fallback に切り替わります
- プライマリが回復すると、ボットは元に戻ります

これは information RPC path にのみ適用され、トランザクション送信 fanout には適用されません。

### `recent_block_hash_refresh_interval`

Type: `u64`, optional

blockhash 更新間隔をミリ秒で指定する高度な設定です。

省略した場合、現在のコードでは `400` が使われます。

### `enable_flash`

Type: bindable `bool`

ボットが flash-loan 有効のトレード命令を構築するかどうかを制御します。

この値は次のいずれかにできます。
- `mpconfig.toml` に直接書かれたリテラル値
- `misc` からの placeholder バインド値

### `cu_limit`

Type: bindable `u64`

トランザクション構築時に使われるグローバル compute unit 制限です。

通常、この設定は `misc` を通じて管理し、メイン設定ファイルを書き換えずに変更できるようにします。

## `[network]`

この section は任意であり、example 設定には含まれていません。

### `account_refresh_interval`

Type: `u64`

pool updater における accounts 更新のポーリング間隔（ミリ秒）です。

省略した場合、現在のデフォルト値は `2000` です。

より小さい値を使うのは、インフラがそれに耐えられる場合に限ってください。

## `[key_pair]`

ウォレット設定です。

### `path_to_secret`

Type: `string`

トランザクション署名に使う Solana keypair ファイルへの絶対パスまたは相対パスです。

期待される形式:
- JSON array keypair file

初回起動時、`keypair` ファイルがまだ暗号化されていなければ、自動的に暗号化されます。

これは startup-fixed の値であり、placeholder では指定できません。

## `[server_config]`

組み込み Web ダッシュボードのための任意設定です。

この section は組み込みブラウザ UI とその待受ポートを制御しますが、起動時にはコマンドライン引数で一部の値を上書きできます。

### `server_enabled`

Type: `bool`, optional

設定ファイルから組み込みサーバーモードを有効にします。

現在の挙動:
- `true` の場合、`--server` がなくてもボットは組み込み Web ダッシュボードを起動します
- `false` または未指定の場合でも、コマンドラインの `--server` でサーバーモードを有効にできます

### `password`

Type: `string`, optional

ブラウザダッシュボード用のパスワードです。

このフィールドは startup-fixed であり、リテラル文字列でなければなりません。

起動時の実際のパスワード優先順位:
1. `BOT_PASSWD`
2. `--server-pass`
3. `server_config.password`
4. 起動時に生成されて表示されるランダムパスワード

### `port`

Type: `u16`, optional

組み込みサーバーの待受ポートです。

現在の挙動:
- デフォルトは `9090` です
- `--port` は `server_config.port` を上書きします

## `[auto_unwrap]`

WSOL 残高保護のための任意 section です。

この section は `base_token` が WSOL の場合に意味があります。

### `enabled`

Type: bindable `bool`

ウォレット内の SOL 残高が設定した最小値を下回ったときに、ボットが WSOL を自動 unwrap してよいかを制御します。

### `minimum_balance`

Type: bindable `u64`, optional

ウォレット内の最小 SOL 残高です。単位は生の lamports です。

現在の挙動:
- このフィールドがない場合、残高ベースの送信制御は適用されません
- このフィールドがあり `enabled = false` の場合、SOL 残高がしきい値を下回っている間は通常送信がスキップされます
- このフィールドがあり `enabled = true` の場合、ボットは WSOL から SOL を回復するためのメンテナンストランザクションを送ることがあります

現在の auto-unwrap 実装:
- メンテナンス経路は通常のトレード送信とは独立しています
- canonical な WSOL ATA を閉じて同じトランザクション内で再作成する versioned transaction を 1 つ構築します
- トランザクションが受理され、事後条件が確認されるまで再試行が続きます
- 利用可能な WSOL だけでは SOL 残高を設定最小値まで戻せない場合、残高がしきい値未満の間は通常送信が引き続きスキップされます

## `[external_config]`

markets、LUT、および runtime チューニング値の外部ソースです。

### `markets`

Type: `string`, optional

markets ファイルへのパスまたは URL。

形式:
- TOML
- `[[group]]` によるグルーピング
- 各 group に pool アドレスの `markets = [ ... ]` リストを含みます

### `lut`

Type: `string`, optional

lookup table ファイルへのパスまたは URL。

形式:
- plain text
- 1 行に 1 つの LUT アドレス

### `misc`

Type: `string`, optional

placeholder から参照される runtime 調整値を保持する JSON ファイルへのパスまたは URL。

形式:
- JSON object

このファイルは以下のような値のソースです。
- `enable_cu_limit`
- `enable_min_prio`
- `enable_jito`
- `helius_min_tip`
- その他の runtime 調整キー

### `poll_interval_ms`

Type: `u64`

`use_external_data = true` のときに、監視対象の外部ソースをポーリングする間隔です。

省略した場合、現在のデフォルト値は `100` です。

## `[local_config]`

高度な任意 section です。

example 設定には含まれていませんが、現在のコードはこれをサポートしています。

目的:
- `use_external_data = false` の場合に、markets と LUT ファイルを起動時に一度だけ読み込む

フィールド:
- `markets`
- `lut`

監視しないモードでの現在の優先順位:
1. `local_config.*`
2. `external_config.*`

`[external_config]` と異なり、この section には `misc` は含まれません。

## `[rpc_config]`

標準 RPC send path の設定です。

通常の RPC transaction fanout にはこの section を使います。

### `endpoint`

Type: `array<string>`

トランザクション送信に使う RPC endpoint の一覧です。

RPC 送信を有効にしたい場合、通常は少なくとも 1 つの endpoint が必要です。

### `auth`

Type: `string`

必要な場合に RPC sender が使用する任意の authentication token です。

プロバイダが URL ですでに認証している場合は、このフィールドを空にできます。

### `enabled`

Type: bindable `bool`

RPC submission fanout を有効または無効にします。

### `priority_lamports_from`

Type: bindable `u64`

トランザクションごとの最小 priority fee。raw lamports 単位です。

### `priority_lamports_to`

Type: bindable `u64`

トランザクションごとの最大 priority fee。raw lamports 単位です。

### `cool_down`

Type: bindable `u64`

RPC 送信サイクル間の cooldown（ミリ秒）です。

### `retries`

Type: `u64`

標準 RPC `sendTransaction` に渡される最大再試行回数です。

これは RPC sender の設定であり、Jito や Flashblock のような relay sender は制御しません。

### Networking Fields

以下はリテラルな数値フィールドです。
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

これらは標準 RPC sender の HTTP client の挙動を制御します。

## `[jito_config]`

Jito トランザクション送信設定です。

### `endpoint`

Type: `array<string>`

Jito transaction endpoint の一覧です。

Helius、Astra、Flashblock、Temporal、HelloMoon とは異なり、Jito の endpoint は `mpconfig.toml` に直接設定します。

### `auth`

Type: `string`, optional

任意の Jito authentication token です。

### `enabled`

Type: bindable `bool`

Jito 送信を有効または無効にします。

### `tip_lamports_from`

Type: bindable `u64`

最小 Jito tip（raw lamports）。

### `tip_lamports_to`

Type: bindable `u64`

最大 Jito tip（raw lamports）。

### `jito_min_prio`

Type: bindable `u64`

Jito path におけるトランザクションごとの最小 priority fee。

### `jito_max_prio`

Type: bindable `u64`

Jito path におけるトランザクションごとの最大 priority fee。

### `jito_cooldown_ms`

Type: bindable `u64`

Jito sender の cooldown（ミリ秒）です。

### Networking Fields

リテラルな数値:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

これらは Jito 専用の HTTP client 設定です。

## `[helius_config]`

Helius fast sender の設定です。

現在の実装上の注意:
- endpoints はコードに組み込まれています
- この section は主に API key と runtime チューニング値を提供します

### `api_key`

Type: `string`

組み込み Helius sender URL に付加される API key。

### `enabled`

Type: bindable `bool`

Helius fast sender を有効または無効にします。

### `helius_min_tip`

Type: bindable `u64`

最小 Helius tip（raw lamports）。

### `helius_max_tip`

Type: bindable `u64`

最大 Helius tip（raw lamports）。

### `helius_min_prio`

Type: bindable `u64`

トランザクションごとの最小 Helius priority fee（raw lamports）。

### `helius_max_prio`

Type: bindable `u64`

トランザクションごとの最大 Helius priority fee（raw lamports）。

### `helius_cooldown_ms`

Type: bindable `u64`

Helius sender の cooldown（ミリ秒）。

省略した場合、現在のデフォルト値は `250` です。

## `[helius_swqos_config]`

Helius SWQoS sender の設定です。

現在の実装上の注意:
- Helius と同じ組み込み endpoint ファミリを使用します
- API key の挙動は `[helius_config]` から継承されます
- sender レイヤーで `swqos_only=true` が追加されます

### `enabled`

Type: bindable `bool`

Helius SWQoS sender を有効または無効にします。

### `helius_swqos_min_tip`

Type: bindable `u64`

最小 SWQoS tip（raw lamports）。

### `helius_swqos_max_tip`

Type: bindable `u64`

最大 SWQoS tip（raw lamports）。

### `helius_swqos_min_prio`

Type: bindable `u64`

トランザクションごとの最小 SWQoS priority fee（raw lamports）。

### `helius_swqos_max_prio`

Type: bindable `u64`

トランザクションごとの最大 SWQoS priority fee（raw lamports）。

### `helius_swqos_cooldown_ms`

Type: bindable `u64`

SWQoS sender の cooldown（ミリ秒）。

省略した場合、現在のデフォルト値は `300` です。

## `[temporal_config]`

Temporal / Nozomi sender の設定です。

現在の実装上の注意:
- endpoints はコードに組み込まれています
- この section は主に `client_id` と runtime チューニング値を提供します

### `client_id`

Type: `string`

組み込み Temporal sender URL に付加される任意の client identifier。

### `enabled`

Type: bindable `bool`

Temporal 送信を有効または無効にします。

### `temporal_min_tip`

Type: bindable `u64`

最小 Temporal tip（raw lamports）。

### `temporal_max_tip`

Type: bindable `u64`

最大 Temporal tip（raw lamports）。

### `temporal_min_prio`

Type: bindable `u64`

トランザクションごとの最小 Temporal priority fee（raw lamports）。

### `temporal_max_prio`

Type: bindable `u64`

トランザクションごとの最大 Temporal priority fee（raw lamports）。

### `temporal_cooldown_ms`

Type: bindable `u64`

Temporal sender の cooldown（ミリ秒）。

省略した場合、現在のデフォルト値は `300` です。

## `[flashblock_config]`

Flashblock sender の設定です。

現在の実装上の注意:
- endpoints はコードに組み込まれています
- この section は主に auth と runtime チューニング値を提供します

### `auth`

Type: `string`

HTTP リクエストで送信される Flashblock Authorization token。

### `enabled`

Type: bindable `bool`

Flashblock 送信を有効または無効にします。

### `flashblock_min_tip`

Type: bindable `u64`

最小 Flashblock tip（raw lamports）。

### `flashblock_max_tip`

Type: bindable `u64`

最大 Flashblock tip（raw lamports）。

### `flashblock_min_prio`

Type: bindable `u64`

トランザクションごとの最小 Flashblock priority fee（raw lamports）。

### `flashblock_max_prio`

Type: bindable `u64`

トランザクションごとの最大 Flashblock priority fee（raw lamports）。

### `flashblock_cooldown_ms`

Type: bindable `u64`

Flashblock sender の cooldown（ミリ秒）。

省略した場合、現在のデフォルト値は `320` です。

## `[astra_config]`

Astra sender の設定です。

現在の実装上の注意:
- endpoints はコードに組み込まれています
- この section は主に API key と runtime チューニング値を提供します

### `api_key`

Type: `string`

Astra endpoints に送信するときに使う API key。

### `enable_astra`

Type: bindable `bool`

Astra 送信を有効または無効にします。

### `enable_astra_min_tip`

Type: bindable `u64`

最小 Astra tip（raw lamports）。

### `enable_astra_max_tip`

Type: bindable `u64`

最大 Astra tip（raw lamports）。

### `astra_min_prio`

Type: bindable `u64`

トランザクションごとの最小 Astra priority fee（raw lamports）。

### `astra_max_prio`

Type: bindable `u64`

トランザクションごとの最大 Astra priority fee（raw lamports）。

### `astralane_cooldown_ms`

Type: bindable `u64`

Astra sender の cooldown（ミリ秒）。

省略した場合、現在のデフォルト値は `300` です。

## `[hellomoon_config]`

HelloMoon sender の設定です。

現在の実装上の注意:
- endpoints はコードに組み込まれています
- この section は主に API key と runtime チューニング値を提供します

### `api_key`

Type: `string`

組み込み HelloMoon sender URL に付加される API key。

### `enable_hellomoon`

Type: bindable `bool`

HelloMoon 送信を有効または無効にします。

### `hellomoon_min_tip`

Type: bindable `u64`

最小 HelloMoon tip（raw lamports）。

### `hellomoon_max_tip`

Type: bindable `u64`

最大 HelloMoon tip（raw lamports）。

### `hellomoon_min_prio`

Type: bindable `u64`

トランザクションごとの最小 HelloMoon priority fee（raw lamports）。

### `hellomoon_max_prio`

Type: bindable `u64`

トランザクションごとの最大 HelloMoon priority fee（raw lamports）。

### `hellomoon_cooldown_ms`

Type: bindable `u64`

HelloMoon sender の cooldown（ミリ秒）。

省略した場合、現在のデフォルト値は `300` です。

## 運用上の注意

### 1. `info_rpc` と `rpc_config.endpoint` は役割が異なります

- `info_rpc` はボットの主 read/information RPC です
- `rpc_config.endpoint` は transaction submission RPC fanout 用の endpoint 一覧です

これらを同じものとして扱わないでください。

### 2. 外部 example ファイルは任意ですが、パスは重要です

`mpconfig.toml` が `config/markets.toml`、`config/lut.txt`、`config/gas.json` を参照している場合、実行時にこれらのファイルが存在していなければなりません。

### 3. Placeholder ベースの設定には `misc` が必要です

bindable フィールドで `{placeholder}` 形式の値を使う場合、参照されるキーは `misc` JSON ドキュメント内に存在する必要があります。

### 4. 不正な `misc` 更新は高リスクです

不正な JSON や参照先の欠落値は、runtime 設定の再構築を壊す可能性があります。`gas.json` の編集は運用上センシティブな変更として扱ってください。

### 5. markets と LUT の更新は live execution に影響します

markets や LUT を再読み込みすると、ボットが構築・送信できる内容が変わります。これらのファイルは受動的な metadata ではなく、ライブなトレード入力として扱ってください。

### 6. 外部 URL をサポートしています

`markets`、`lut`、`misc` のソースは HTTP または HTTPS で配信できます。既存の自動化が中央の場所からボット設定ファイルを公開している場合に便利です。

### 7. Pause はトレードを止めますが、すべてのメンテナンスを止めるわけではありません

ボットを一時停止すると通常のトレード送信は止まりますが、独立したメンテナンスタスクは必要に応じて継続できます。

### 8. 手動 market mode でも LUT 更新は止まりません

手動 market mode では、設定されたソースからの `markets` 自動再読み込みは抑止されますが、LUT の再読み込みは継続されます。

## 推奨される初期パターン

クリーンな運用レイアウトのために:

1. `mpconfig.toml` は基本的に静的に保ちます。
2. 変化の速い runtime 値は `gas.json` に置きます。
3. pool universe の変更は `markets.toml` に置きます。
4. lookup table の変更は `lut.txt` に置きます。
5. live reload behavior が必要なら `use_external_data = true` を有効にします。

このやり方により、credentials、endpoints、runtime チューニングを分離でき、自動化しやすくなり、より安全に運用できます。
