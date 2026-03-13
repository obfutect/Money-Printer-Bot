# `mpconfig.toml` 使用手册

本文档说明 Money Printer 的主配置文件，以及机器人在运行时如何使用它。

请结合以下文件一起使用：
- [`../mpconfig.example.toml`](../mpconfig.example.toml)
- [`../config/README.md`](../config/README.md)

## 用途

`mpconfig.toml` 是操作员使用的主配置文件。它定义了：
- 钱包位置
- information RPC 端点
- 交易提交通道
- sender 凭据
- 外部配置来源
- 可在运行时调节的值与 placeholder 绑定

该文件只会在启动时读取一次。机器人不会监控它的变更。如果你修改了 `mpconfig.toml`，请重启机器人。

## 机器人如何找到配置文件

Money Printer 按以下顺序解析主配置文件路径：

1. 环境变量 `MP_CONFIG`
2. `--config <path>` 或 `-c <path>`
3. 与可执行文件位于同一目录下的 `mpconfig.toml`

重要说明：
- `MP_CONFIG` 的优先级高于命令行参数。
- 如果没有提供 override，机器人会假定 `mpconfig.toml` 与二进制文件位于同一目录。

## 静态字段与运行时绑定字段

代码会区分：
- startup-fixed fields：在启动时读取的字面量值，不会通过 hot reload 重新加载
- bindable fields：既可以直接写字面量，也可以通过 `{enable_cu_limit}` 这样的 placeholder 从 `misc` JSON 中引用的值

### 启动时固定的字段

这些字段必须在 `mpconfig.toml` 中写成字面量字符串或数字，不能使用 `{placeholder}` 语法：

- `info_rpc`
- `info_rpc_fallback`
- `base_token`
- `key_pair.path_to_secret`
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

修改这些字段中的任意一个，都需要编辑 `mpconfig.toml` 并重启进程。

### 可绑定字段

许多运行参数可以这样写：
- 直接写字面量，例如 `cu_limit = 350000`
- 或者写引用，例如 `cu_limit = "{enable_cu_limit}"`

当使用 placeholder 语法时，该值会从 `external_config.misc` 加载的 JSON 文档中解析。

如果某个字段使用了 placeholder，而 JSON 文件缺失、格式错误，或者不包含被引用的键，则配置解析会失败。

## Placeholder 绑定

Placeholder 语法如下：

```toml
cu_limit = "{enable_cu_limit}"
```

对应的 JSON：

```json
{
  "enable_cu_limit": 350000
}
```

注意事项：
- placeholder 名称区分大小写
- placeholder 只适用于实现为 bindable value 的字段
- 类型必须与目标字段匹配
- placeholder 的解析发生在从 `misc` 构建或重新构建 runtime 配置时

## 外部配置与 Hot Reload

Money Printer 支持三种外部来源：
- markets 文件
- LUT 文件
- misc JSON 文件

它们通过 `[external_config]` 进行配置。

### 当 `use_external_data = true` 时

机器人会轮询已配置的外部来源，并在运行时重新加载它们。

当前行为：
- 支持本地文件路径以及 `http://` / `https://` URL
- 轮询间隔由 `external_config.poll_interval_ms` 控制
- 只有当同一份内容被连续观察到两次时，变更才会生效
  这相当于一个小型 debounce，可避免读取到部分写入的内容

按文件类型划分的重载行为：
- `markets`：重新加载市场集合，并重建 pool 数据库
- `lut`：重新加载 lookup table，并刷新交易 LUT 缓存
- `misc`：重新解析 runtime 值，并在无需重启机器人的情况下重新发布

主配置文件 `mpconfig.toml` 不会被重新加载。

### 当 `use_external_data = false` 时

机器人不会监控外部文件，但某些路径仍可能在启动时作为一次性来源使用。

当前启动行为：
- `local_config.markets` 和 `local_config.lut` 优先作为一次性启动加载来源
- 如果不存在 `local_config`，则 `external_config.markets` 和 `external_config.lut` 仍可作为一次性启动输入
- `external_config.misc` 仍可能在启动时读取一次，用于解析 placeholder

这意味着：如果你的配置使用了 `{placeholder}` 形式的值，那么即使在非监控模式下，`external_config.misc` 仍然是相关的。

## 值的一般约定

- tip 值使用 raw lamports 表示
- priority fee 范围同样使用每笔交易的 raw lamports 表示
- 在内部，priority fee 会被转换为 compute-budget price 值
- cooldown 值以毫秒为单位
- endpoint 列表必须是字面量 URL

## 顶层字段

### `use_external_data`

Type: `bool`

控制是否在运行时监控并重载已配置的外部来源。

推荐：
- `true`：如果你希望 markets 列表、LUT 和运行时调优值支持 hot reload
- `false`：如果你希望使用仅在启动时生效的静态配置

### `base_token`

Type: `string`

基础交易 mint。当前代码和示例配置实际上主要围绕 WSOL。

示例：

```toml
base_token = "So11111111111111111111111111111111111111112"
```

### `info_rpc`

Type: `string`

主 information RPC 端点，用于：
- 读取账户
- 加载 markets
- 获取 recent blockhash
- 其他非发送类信息查询

通常这里应该填写你最好的读请求端点。

### `info_rpc_fallback`

Type: `string`, optional

information RPC 的可选 fallback。

当前行为：
- 当主端点连续失败 3 次后
- 机器人会切换到 fallback 30 秒
- 一旦主端点恢复，机器人会切换回去

这只适用于 information RPC 路径，不适用于交易提交通道的 fanout。

### `recent_block_hash_refresh_interval`

Type: `u64`, optional

用于控制 blockhash 刷新节奏的高级设置，单位为毫秒。

如果省略，当前代码会回退到 `400`。

### `enable_flash`

Type: bindable `bool`

控制机器人是否构建启用 flash-loan 的交易指令。

它可以是：
- `mpconfig.toml` 中的字面量值
- 来自 `misc` 的 placeholder 绑定值

### `cu_limit`

Type: bindable `u64`

构建交易时使用的全局 compute unit 限制。

该设置通常通过 `misc` 来驱动，这样就能在不重写主配置文件的情况下修改它。

## `[network]`

该 section 是可选的，示例配置中没有它。

### `account_refresh_interval`

Type: `u64`

pool updater 刷新账户的轮询间隔，单位为毫秒。

如果省略，当前默认值为 `2000`。

只有在你的基础设施确实能够承受更高刷新频率时，才应使用更低的值。

## `[key_pair]`

钱包配置。

### `path_to_secret`

Type: `string`

用于签署交易的 Solana keypair 文件的绝对或相对路径。

期望格式：
- JSON array keypair file

该值属于 startup-fixed，不能使用 placeholder。

## `[external_config]`

markets、LUT 和运行时调优值的外部来源。

### `markets`

Type: `string`, optional

markets 文件的路径或 URL。

格式：
- TOML
- 通过 `[[group]]` 分组
- 每个分组包含一个 `markets = [ ... ]` 列表，内部是 pool 地址

### `lut`

Type: `string`, optional

lookup table 文件的路径或 URL。

格式：
- plain text
- 每行一个 LUT 地址

### `misc`

Type: `string`, optional

指向 JSON 文件的路径或 URL。该文件保存可在运行时调节、并由 placeholder 引用的值。

格式：
- JSON object

该文件是以下值的来源，例如：
- `enable_cu_limit`
- `enable_min_prio`
- `enable_jito`
- `helius_min_tip`
- 以及其他可在运行时调节的键

### `poll_interval_ms`

Type: `u64`

当 `use_external_data = true` 时，外部来源的轮询间隔。

如果省略，当前默认值为 `100`。

## `[local_config]`

高级可选 section。

该 section 在示例配置中不存在，但当前代码支持它。

用途：
- 当 `use_external_data = false` 时，在启动阶段一次性加载 markets 和 LUT 文件

字段：
- `markets`
- `lut`

在非监控模式下的当前优先级：
1. `local_config.*`
2. `external_config.*`

与 `[external_config]` 不同，该 section 不包含 `misc`。

## `[rpc_config]`

标准 RPC 发送路径配置。

该 section 用于普通 RPC transaction fanout。

### `endpoint`

Type: `array<string>`

用于提交交易的 RPC endpoint 列表。

如果你希望启用 RPC 发送，通常至少需要一个 endpoint。

### `auth`

Type: `string`

如果你的部署需要的话，RPC sender 使用的可选 authentication token。

如果你的提供商已经通过 URL 进行认证，那么可以将该字段留空。

### `enabled`

Type: bindable `bool`

启用或禁用 RPC submission fanout。

### `priority_lamports_from`

Type: bindable `u64`

每笔交易的最小 priority fee，以 raw lamports 表示。

### `priority_lamports_to`

Type: bindable `u64`

每笔交易的最大 priority fee，以 raw lamports 表示。

### `cool_down`

Type: bindable `u64`

RPC 提交周期之间的 cooldown，单位为毫秒。

### `retries`

Type: `u64`

传递给标准 RPC `sendTransaction` 的最大重试次数。

这是 RPC sender 的设置，不控制 Jito 或 Flashblock 之类的 relay sender。

### Networking Fields

这些是字面量数值字段：
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

它们控制标准 RPC sender 的 HTTP client 行为。

## `[jito_config]`

Jito 交易提交配置。

### `endpoint`

Type: `array<string>`

Jito transaction endpoint 列表。

与 Helius、Astra、Flashblock、Temporal 和 HelloMoon 不同，Jito 的 endpoint 直接在 `mpconfig.toml` 中配置。

### `auth`

Type: `string`, optional

可选的 Jito authentication token。

### `enabled`

Type: bindable `bool`

启用或禁用 Jito 发送。

### `tip_lamports_from`

Type: bindable `u64`

最小 Jito tip，单位为 raw lamports。

### `tip_lamports_to`

Type: bindable `u64`

最大 Jito tip，单位为 raw lamports。

### `jito_min_prio`

Type: bindable `u64`

Jito 路径下每笔交易的最小 priority fee。

### `jito_max_prio`

Type: bindable `u64`

Jito 路径下每笔交易的最大 priority fee。

### `jito_cooldown_ms`

Type: bindable `u64`

Jito sender 的 cooldown，单位为毫秒。

### Networking Fields

字面量数值：
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

这些是 Jito 专用的 HTTP client 设置。

## `[helius_config]`

Helius fast sender 配置。

当前实现说明：
- endpoint 内建在代码中
- 该 section 主要提供 API key 和运行时调优值

### `api_key`

Type: `string`

追加到内建 Helius sender URL 的 API key。

### `enabled`

Type: bindable `bool`

启用或禁用 Helius fast sender。

### `helius_min_tip`

Type: bindable `u64`

最小 Helius tip，单位为 raw lamports。

### `helius_max_tip`

Type: bindable `u64`

最大 Helius tip，单位为 raw lamports。

### `helius_min_prio`

Type: bindable `u64`

每笔交易的最小 Helius priority fee，单位为 raw lamports。

### `helius_max_prio`

Type: bindable `u64`

每笔交易的最大 Helius priority fee，单位为 raw lamports。

### `helius_cooldown_ms`

Type: bindable `u64`

Helius sender 的 cooldown，单位为毫秒。

如果省略，当前默认值为 `250`。

## `[helius_swqos_config]`

Helius SWQoS sender 配置。

当前实现说明：
- 使用与 Helius 相同的一组内建 endpoint
- API key 行为继承自 `[helius_config]`
- sender 层会自动附加 `swqos_only=true`

### `enabled`

Type: bindable `bool`

启用或禁用 Helius SWQoS sender。

### `helius_swqos_min_tip`

Type: bindable `u64`

最小 SWQoS tip，单位为 raw lamports。

### `helius_swqos_max_tip`

Type: bindable `u64`

最大 SWQoS tip，单位为 raw lamports。

### `helius_swqos_min_prio`

Type: bindable `u64`

每笔交易的最小 SWQoS priority fee，单位为 raw lamports。

### `helius_swqos_max_prio`

Type: bindable `u64`

每笔交易的最大 SWQoS priority fee，单位为 raw lamports。

### `helius_swqos_cooldown_ms`

Type: bindable `u64`

SWQoS sender 的 cooldown，单位为毫秒。

如果省略，当前默认值为 `300`。

## `[temporal_config]`

Temporal / Nozomi sender 配置。

当前实现说明：
- endpoint 内建在代码中
- 该 section 主要提供 `client_id` 和运行时调优值

### `client_id`

Type: `string`

附加到内建 Temporal sender URL 的可选 client identifier。

### `enabled`

Type: bindable `bool`

启用或禁用 Temporal 发送。

### `temporal_min_tip`

Type: bindable `u64`

最小 Temporal tip，单位为 raw lamports。

### `temporal_max_tip`

Type: bindable `u64`

最大 Temporal tip，单位为 raw lamports。

### `temporal_min_prio`

Type: bindable `u64`

每笔交易的最小 Temporal priority fee，单位为 raw lamports。

### `temporal_max_prio`

Type: bindable `u64`

每笔交易的最大 Temporal priority fee，单位为 raw lamports。

### `temporal_cooldown_ms`

Type: bindable `u64`

Temporal sender 的 cooldown，单位为毫秒。

如果省略，当前默认值为 `300`。

## `[flashblock_config]`

Flashblock sender 配置。

当前实现说明：
- endpoint 内建在代码中
- 该 section 主要提供 auth 和运行时调优值

### `auth`

Type: `string`

在 HTTP 请求中发送的 Flashblock Authorization token。

### `enabled`

Type: bindable `bool`

启用或禁用 Flashblock 发送。

### `flashblock_min_tip`

Type: bindable `u64`

最小 Flashblock tip，单位为 raw lamports。

### `flashblock_max_tip`

Type: bindable `u64`

最大 Flashblock tip，单位为 raw lamports。

### `flashblock_min_prio`

Type: bindable `u64`

每笔交易的最小 Flashblock priority fee，单位为 raw lamports。

### `flashblock_max_prio`

Type: bindable `u64`

每笔交易的最大 Flashblock priority fee，单位为 raw lamports。

### `flashblock_cooldown_ms`

Type: bindable `u64`

Flashblock sender 的 cooldown，单位为毫秒。

如果省略，当前默认值为 `320`。

## `[astra_config]`

Astra sender 配置。

当前实现说明：
- endpoint 内建在代码中
- 该 section 主要提供 API key 和运行时调优值

### `api_key`

Type: `string`

提交到 Astra endpoint 时使用的 API key。

### `enable_astra`

Type: bindable `bool`

启用或禁用 Astra 发送。

### `enable_astra_min_tip`

Type: bindable `u64`

最小 Astra tip，单位为 raw lamports。

### `enable_astra_max_tip`

Type: bindable `u64`

最大 Astra tip，单位为 raw lamports。

### `astra_min_prio`

Type: bindable `u64`

每笔交易的最小 Astra priority fee，单位为 raw lamports。

### `astra_max_prio`

Type: bindable `u64`

每笔交易的最大 Astra priority fee，单位为 raw lamports。

### `astralane_cooldown_ms`

Type: bindable `u64`

Astra sender 的 cooldown，单位为毫秒。

如果省略，当前默认值为 `300`。

## `[hellomoon_config]`

HelloMoon sender 配置。

当前实现说明：
- endpoint 内建在代码中
- 该 section 主要提供 API key 和运行时调优值

### `api_key`

Type: `string`

追加到内建 HelloMoon sender URL 的 API key。

### `enable_hellomoon`

Type: bindable `bool`

启用或禁用 HelloMoon 发送。

### `hellomoon_min_tip`

Type: bindable `u64`

最小 HelloMoon tip，单位为 raw lamports。

### `hellomoon_max_tip`

Type: bindable `u64`

最大 HelloMoon tip，单位为 raw lamports。

### `hellomoon_min_prio`

Type: bindable `u64`

每笔交易的最小 HelloMoon priority fee，单位为 raw lamports。

### `hellomoon_max_prio`

Type: bindable `u64`

每笔交易的最大 HelloMoon priority fee，单位为 raw lamports。

### `hellomoon_cooldown_ms`

Type: bindable `u64`

HelloMoon sender 的 cooldown，单位为毫秒。

如果省略，当前默认值为 `300`。

## 运维说明

### 1. `info_rpc` 与 `rpc_config.endpoint` 的职责不同

- `info_rpc` 是机器人的主 read/information RPC
- `rpc_config.endpoint` 是 transaction submission RPC fanout 使用的 endpoint 列表

不要假设它们可以互相替代。

### 2. 外部示例文件是可选的，但路径很重要

如果 `mpconfig.toml` 指向 `config/markets.toml`、`config/lut.txt` 和 `config/gas.json`，那么这些文件在运行时必须存在。

### 3. 基于 placeholder 的配置需要 `misc`

如果你在任何 bindable 字段中使用了 `{placeholder}` 形式的值，那么被引用的键必须存在于 `misc` JSON 文档中。

### 4. 错误的 `misc` 更新风险很高

格式错误的 JSON 或缺失的引用值可能会破坏 runtime 配置的重新构建。请将对 `gas.json` 的修改视为运维敏感操作。

### 5. markets 和 LUT 的更新会影响 live execution

重新加载 markets 或 LUT 会改变机器人能够构建和发送的内容。请将这些文件视为实时交易输入，而不是被动元数据。

### 6. 支持外部 URL

`markets`、`lut` 和 `misc` 来源可以通过 HTTP 或 HTTPS 提供。如果你现有的自动化系统已经从中心位置发布机器人配置文件，这会很有用。

## 推荐的起步方式

为了获得更清晰的运维布局：

1. 让 `mpconfig.toml` 保持基本静态。
2. 将变化快的 runtime 值放入 `gas.json`。
3. 将 pool universe 的变化放入 `markets.toml`。
4. 将 lookup table 的变化放入 `lut.txt`。
5. 如果你需要 live reload behavior，请启用 `use_external_data = true`。

这样可以把 credentials、endpoint 和 runtime 调优拆分开，更易于自动化，也更安全。
