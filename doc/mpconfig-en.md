# `mpconfig.toml` Manual

This document explains the main Money Printer configuration file and how the bot uses it at runtime.

Use it together with:
- [`../mpconfig.example.toml`](../mpconfig.example.toml)
- [`../config/README.md`](../config/README.md)

## Purpose

`mpconfig.toml` is the main operator configuration file. It defines:
- wallet location
- information RPC endpoints
- transaction submission channels
- sender credentials
- external config sources
- runtime-tunable values and placeholder bindings

The file is read once at startup. It is not watched for changes. If you edit `mpconfig.toml`, restart the bot.

## How the Bot Finds the Config File

Money Printer resolves the main config path in this order:

1. `MP_CONFIG` environment variable
2. `--config <path>`, `-c <path>`, or `--config=<path>`
3. `mpconfig.toml` next to the executable

Important:
- `MP_CONFIG` takes precedence over command-line arguments.
- If no override is supplied, the bot expects `mpconfig.toml` in the same directory as the binary.

## Static Fields vs Runtime-Bound Fields

The code distinguishes between:
- startup-fixed fields: literal values read at startup and never hot-reloaded
- bindable fields: values that may be written literally or referenced from `misc` JSON via placeholders such as `{enable_cu_limit}`

### Startup-Fixed Fields

These must be literal strings or numbers in `mpconfig.toml`. They cannot use `{placeholder}` syntax:

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

Changing any of these requires editing `mpconfig.toml` and restarting the process.

### Bindable Fields

Many operational values can be written either:
- directly, for example `cu_limit = 350000`
- by reference, for example `cu_limit = "{enable_cu_limit}"`

When placeholder syntax is used, the value is resolved from the JSON document loaded from `external_config.misc`.

If a placeholder is used and the JSON file is missing, malformed, or does not contain the referenced key, configuration resolution fails.

## Placeholder Binding

Placeholder syntax is:

```toml
cu_limit = "{enable_cu_limit}"
```

Matching JSON:

```json
{
  "enable_cu_limit": 350000
}
```

Notes:
- placeholder names are case-sensitive
- placeholders only work in fields implemented as bindable values
- types must match the target field
- placeholder resolution happens when runtime config is built or re-built from `misc`

## External Config and Hot Reload

Money Printer supports three external sources:
- markets file
- LUT file
- misc JSON file

These are configured under `[external_config]`.

### When `use_external_data = true`

The bot polls configured external sources and reloads them at runtime.

Current behavior:
- local file paths and `http://` / `https://` URLs are supported
- the poll interval is `external_config.poll_interval_ms`
- a change is applied only after the same content is seen twice in a row
  this works like a small debounce and avoids partial writes

Reload behavior by file type:
- `markets`: pool universe is reloaded and the pool database is rebuilt
- `lut`: lookup tables are reloaded and the transaction LUT cache is refreshed
- `misc`: runtime values are re-resolved and published without restarting the bot

The main `mpconfig.toml` file is not reloaded.

### When `use_external_data = false`

The bot does not watch external files, but some paths may still be used as one-time startup sources.

Current startup behavior:
- `local_config.markets` and `local_config.lut` are preferred for one-time loading
- if `local_config` is absent, `external_config.markets` and `external_config.lut` may still be used as one-time startup inputs
- `external_config.misc` may still be read once at startup to resolve placeholders

This means `external_config.misc` is still relevant even in non-watched mode if your config uses `{placeholder}` values.

## General Value Conventions

- tip values are specified in raw lamports
- priority fee ranges are also specified in raw lamports per transaction
- internally, priority fees are converted into compute-budget price values
- cooldown values are in milliseconds
- endpoint lists are literal URLs

## Top-Level Fields

### `use_external_data`

Type: `bool`

Controls whether configured external sources are watched and reloaded at runtime.

Recommended:
- `true` if you want hot reload for market lists, LUTs, and runtime tuning values
- `false` if you want a static startup-only configuration

### `base_token`

Type: `string`

Base trading mint. In practice, the current code and example config are centered on WSOL.

Example:

```toml
base_token = "So11111111111111111111111111111111111111112"
```

### `info_rpc`

Type: `string`

Primary information RPC endpoint used for:
- reading accounts
- loading markets
- fetching recent blockhashes
- other non-send information queries

This should normally be your best read-oriented endpoint.

### `info_rpc_fallback`

Type: `string`, optional

Optional fallback for information RPC.

Current behavior:
- after 3 consecutive failures on the primary endpoint
- the bot switches to fallback for 30 seconds
- once the primary recovers, the bot switches back

This is only for the information RPC path, not for transaction submission fanout.

### `recent_block_hash_refresh_interval`

Type: `u64`, optional

Advanced setting for blockhash refresh cadence in milliseconds.

If omitted, the current code falls back to `400`.

### `enable_flash`

Type: bindable `bool`

Controls whether the bot builds flash-loan-enabled trade instructions.

This can be:
- literal in `mpconfig.toml`
- placeholder-bound from `misc`

### `cu_limit`

Type: bindable `u64`

Global compute unit limit used when building transactions.

This setting is typically driven through `misc` so it can be changed without rewriting the main config.

## `[network]`

This section is optional and is not present in the example config.

### `account_refresh_interval`

Type: `u64`

Polling interval in milliseconds for account refreshes in the pool updater.

If omitted, the current default is `2000`.

Use lower values only if your infrastructure can support them.

## `[key_pair]`

Wallet configuration.

### `path_to_secret`

Type: `string`

Absolute or relative path to the Solana keypair file used for signing transactions.

Expected format:
- JSON array keypair file

On first run, the keypair file is encrypted automatically if it is not already encrypted.

This value is startup-fixed and cannot be placeholder-bound.

## `[server_config]`

Optional embedded web dashboard configuration.

This section controls the built-in browser UI and its listen port, but command-line flags can still override parts of it at startup.

### `server_enabled`

Type: `bool`, optional

Enables embedded server mode from configuration.

Current behavior:
- if `true`, the bot starts the embedded web dashboard without requiring `--server`
- if `false` or omitted, `--server` can still enable server mode from the command line

### `password`

Type: `string`, optional

Password for the browser dashboard.

This field is startup-fixed and must be a literal string.

Actual password priority at startup:
1. `BOT_PASSWD`
2. `--server-pass`
3. `server_config.password`
4. generated password printed at startup

### `port`

Type: `u16`, optional

Embedded server listen port.

Current behavior:
- default is `9090`
- `--port` overrides `server_config.port`

## `[auto_unwrap]`

Optional WSOL balance-protection section.

This section is relevant when `base_token` is WSOL.

### `enabled`

Type: bindable `bool`

Controls whether the bot is allowed to automatically unwrap WSOL when wallet SOL falls below the configured minimum.

### `minimum_balance`

Type: bindable `u64`, optional

Minimum wallet SOL balance, in raw lamports.

Current behavior:
- if this field is missing, no balance-based submission gating is applied
- if this field is present and `enabled = false`, normal submission is skipped while wallet SOL is below the threshold
- if this field is present and `enabled = true`, the bot may send a maintenance transaction to recover SOL from WSOL

Current auto-unwrap implementation:
- the maintenance path is independent from normal trading submission
- it builds one versioned transaction that closes the canonical WSOL ATA and recreates it in the same transaction
- retries continue until the transaction is accepted and the postcondition is confirmed
- if available WSOL is not enough to raise wallet SOL above the configured minimum, normal submission remains skipped while the balance stays below the threshold

## `[external_config]`

External sources for markets, LUTs, and runtime tuning values.

### `markets`

Type: `string`, optional

Path or URL to the markets file.

Format:
- TOML
- grouped under `[[group]]`
- each group contains a `markets = [ ... ]` list of pool addresses

### `lut`

Type: `string`, optional

Path or URL to the lookup table file.

Format:
- plain text
- one LUT address per line

### `misc`

Type: `string`, optional

Path or URL to the JSON file holding runtime-tunable values referenced by placeholders.

Format:
- JSON object

This file is the source of values like:
- `enable_cu_limit`
- `enable_min_prio`
- `enable_jito`
- `helius_min_tip`
- and other runtime-tunable keys

### `poll_interval_ms`

Type: `u64`

Polling interval for watched external sources when `use_external_data = true`.

If omitted, the current default is `100`.

## `[local_config]`

Advanced optional section.

This section is not present in the example config, but the current code supports it.

Purpose:
- one-time startup loading of markets and LUT files when `use_external_data = false`

Fields:
- `markets`
- `lut`

Current precedence in non-watched mode:
1. `local_config.*`
2. `external_config.*`

Unlike `[external_config]`, this section does not include `misc`.

## `[rpc_config]`

Standard RPC send path configuration.

Use this section for plain RPC transaction fanout.

### `endpoint`

Type: `array<string>`

List of RPC endpoints used for transaction submission.

At least one endpoint is normally required if you want RPC sending enabled.

### `auth`

Type: `string`

Optional authentication token used by the RPC sender if required by your setup.

If your provider already authenticates through the URL, this may be left empty.

### `enabled`

Type: bindable `bool`

Enables or disables RPC submission fanout.

### `priority_lamports_from`

Type: bindable `u64`

Minimum per-transaction priority fee, expressed in raw lamports.

### `priority_lamports_to`

Type: bindable `u64`

Maximum per-transaction priority fee, expressed in raw lamports.

### `cool_down`

Type: bindable `u64`

Cooldown between RPC submission cycles, in milliseconds.

### `retries`

Type: `u64`

Maximum retries value passed to standard RPC `sendTransaction`.

This is an RPC-sender setting. It does not control relay senders such as Jito or Flashblock.

### Networking Fields

These fields are literal numeric values:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

They control the HTTP client behavior for the standard RPC sender.

## `[jito_config]`

Jito transaction submission configuration.

### `endpoint`

Type: `array<string>`

List of Jito transaction endpoints.

Unlike Helius, Astra, Flashblock, Temporal, and HelloMoon, Jito endpoints are configured directly in `mpconfig.toml`.

### `auth`

Type: `string`, optional

Optional Jito authentication token.

### `enabled`

Type: bindable `bool`

Enables or disables Jito sending.

### `tip_lamports_from`

Type: bindable `u64`

Minimum Jito tip in raw lamports.

### `tip_lamports_to`

Type: bindable `u64`

Maximum Jito tip in raw lamports.

### `jito_min_prio`

Type: bindable `u64`

Minimum per-transaction priority fee for the Jito path.

### `jito_max_prio`

Type: bindable `u64`

Maximum per-transaction priority fee for the Jito path.

### `jito_cooldown_ms`

Type: bindable `u64`

Jito sender cooldown in milliseconds.

### Networking Fields

Literal numeric values:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

These are Jito-specific HTTP client settings.

## `[helius_config]`

Helius fast sender configuration.

Current implementation notes:
- endpoints are built into the code
- this section mainly provides API key and runtime tuning values

### `api_key`

Type: `string`

API key appended to built-in Helius sender URLs.

### `enabled`

Type: bindable `bool`

Enables or disables Helius fast sender.

### `helius_min_tip`

Type: bindable `u64`

Minimum Helius tip in raw lamports.

### `helius_max_tip`

Type: bindable `u64`

Maximum Helius tip in raw lamports.

### `helius_min_prio`

Type: bindable `u64`

Minimum Helius priority fee in raw lamports per transaction.

### `helius_max_prio`

Type: bindable `u64`

Maximum Helius priority fee in raw lamports per transaction.

### `helius_cooldown_ms`

Type: bindable `u64`

Helius sender cooldown in milliseconds.

If omitted, the current default is `250`.

## `[helius_swqos_config]`

Helius SWQoS sender configuration.

Current implementation notes:
- uses the same built-in endpoint family as Helius
- inherits API key behavior from `[helius_config]`
- appends `swqos_only=true` in the sender layer

### `enabled`

Type: bindable `bool`

Enables or disables Helius SWQoS sender.

### `helius_swqos_min_tip`

Type: bindable `u64`

Minimum SWQoS tip in raw lamports.

### `helius_swqos_max_tip`

Type: bindable `u64`

Maximum SWQoS tip in raw lamports.

### `helius_swqos_min_prio`

Type: bindable `u64`

Minimum SWQoS priority fee in raw lamports per transaction.

### `helius_swqos_max_prio`

Type: bindable `u64`

Maximum SWQoS priority fee in raw lamports per transaction.

### `helius_swqos_cooldown_ms`

Type: bindable `u64`

SWQoS sender cooldown in milliseconds.

If omitted, the current default is `300`.

## `[temporal_config]`

Temporal / Nozomi sender configuration.

Current implementation notes:
- endpoints are built into the code
- this section mainly provides `client_id` and runtime tuning values

### `client_id`

Type: `string`

Optional client identifier appended to built-in Temporal sender URLs.

### `enabled`

Type: bindable `bool`

Enables or disables Temporal sending.

### `temporal_min_tip`

Type: bindable `u64`

Minimum Temporal tip in raw lamports.

### `temporal_max_tip`

Type: bindable `u64`

Maximum Temporal tip in raw lamports.

### `temporal_min_prio`

Type: bindable `u64`

Minimum Temporal priority fee in raw lamports per transaction.

### `temporal_max_prio`

Type: bindable `u64`

Maximum Temporal priority fee in raw lamports per transaction.

### `temporal_cooldown_ms`

Type: bindable `u64`

Temporal sender cooldown in milliseconds.

If omitted, the current default is `300`.

## `[flashblock_config]`

Flashblock sender configuration.

Current implementation notes:
- endpoints are built into the code
- this section mainly provides auth and runtime tuning values

### `auth`

Type: `string`

Flashblock authorization token sent in the HTTP request.

### `enabled`

Type: bindable `bool`

Enables or disables Flashblock sending.

### `flashblock_min_tip`

Type: bindable `u64`

Minimum Flashblock tip in raw lamports.

### `flashblock_max_tip`

Type: bindable `u64`

Maximum Flashblock tip in raw lamports.

### `flashblock_min_prio`

Type: bindable `u64`

Minimum Flashblock priority fee in raw lamports per transaction.

### `flashblock_max_prio`

Type: bindable `u64`

Maximum Flashblock priority fee in raw lamports per transaction.

### `flashblock_cooldown_ms`

Type: bindable `u64`

Flashblock sender cooldown in milliseconds.

If omitted, the current default is `320`.

## `[astra_config]`

Astra sender configuration.

Current implementation notes:
- endpoints are built into the code
- this section mainly provides API key and runtime tuning values

### `api_key`

Type: `string`

API key used when submitting to Astra endpoints.

### `enable_astra`

Type: bindable `bool`

Enables or disables Astra sending.

### `enable_astra_min_tip`

Type: bindable `u64`

Minimum Astra tip in raw lamports.

### `enable_astra_max_tip`

Type: bindable `u64`

Maximum Astra tip in raw lamports.

### `astra_min_prio`

Type: bindable `u64`

Minimum Astra priority fee in raw lamports per transaction.

### `astra_max_prio`

Type: bindable `u64`

Maximum Astra priority fee in raw lamports per transaction.

### `astralane_cooldown_ms`

Type: bindable `u64`

Astra sender cooldown in milliseconds.

If omitted, the current default is `300`.

## `[hellomoon_config]`

HelloMoon sender configuration.

Current implementation notes:
- endpoints are built into the code
- this section mainly provides API key and runtime tuning values

### `api_key`

Type: `string`

API key appended to built-in HelloMoon sender URLs.

### `enable_hellomoon`

Type: bindable `bool`

Enables or disables HelloMoon sending.

### `hellomoon_min_tip`

Type: bindable `u64`

Minimum HelloMoon tip in raw lamports.

### `hellomoon_max_tip`

Type: bindable `u64`

Maximum HelloMoon tip in raw lamports.

### `hellomoon_min_prio`

Type: bindable `u64`

Minimum HelloMoon priority fee in raw lamports per transaction.

### `hellomoon_max_prio`

Type: bindable `u64`

Maximum HelloMoon priority fee in raw lamports per transaction.

### `hellomoon_cooldown_ms`

Type: bindable `u64`

HelloMoon sender cooldown in milliseconds.

If omitted, the current default is `300`.

## Operational Notes

### 1. `info_rpc` and `rpc_config.endpoint` have different roles

- `info_rpc` is the bot's main read/information RPC
- `rpc_config.endpoint` is the transaction submission RPC fanout list

Do not assume they are interchangeable.

### 2. The example external files are optional, but the paths matter

If `mpconfig.toml` points to `config/markets.toml`, `config/lut.txt`, and `config/gas.json`, those files must exist at runtime.

### 3. Placeholder-driven configs require `misc`

If you use `{placeholder}` values anywhere in bindable fields, the referenced key must exist in the `misc` JSON document.

### 4. Bad `misc` updates are high risk

Malformed JSON or missing referenced values can break runtime config rebuilds. Treat `gas.json` edits as operationally sensitive.

### 5. Market and LUT updates affect live execution

Reloading markets or LUTs changes what the bot can build and send. Treat these files as live trading inputs, not passive metadata.

### 6. External URLs are supported

Markets, LUTs, and misc sources may be served over HTTP or HTTPS. This is useful if your existing automation already publishes bot config files from a central location.

### 7. Pause affects trading, not all maintenance

Pausing the bot stops normal trade submission, but independent maintenance tasks can still continue when needed.

### 8. Manual market mode does not stop LUT updates

Manual market mode suppresses automatic `markets` reload from the configured source, but LUT reloads still continue.

## Recommended Starting Pattern

For a clean operational layout:

1. Keep `mpconfig.toml` mostly static.
2. Put fast-changing runtime values in `gas.json`.
3. Put pool universe changes in `markets.toml`.
4. Put lookup table changes in `lut.txt`.
5. Enable `use_external_data = true` if you want live reload behavior.

This keeps credentials, endpoints, and runtime tuning separated in a way that is easier to automate and safer to operate.
