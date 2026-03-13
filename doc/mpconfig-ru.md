# Руководство по `mpconfig.toml`

В этом документе описан основной конфигурационный файл Money Printer и то, как бот использует его во время работы.

Используйте его вместе с:
- [`../mpconfig.example.toml`](../mpconfig.example.toml)
- [`../config/README.md`](../config/README.md)

## Назначение

`mpconfig.toml` — это основной конфигурационный файл оператора. Он определяет:
- расположение кошелька
- information RPC endpoints
- каналы отправки транзакций
- учетные данные sender'ов
- внешние источники конфигурации
- runtime-настраиваемые значения и привязки плейсхолдеров

Файл читается один раз при старте. За его изменениями бот не следит. Если вы изменили `mpconfig.toml`, перезапустите бот.

## Как Бот Находит Конфигурационный Файл

Money Printer определяет путь к основному конфигу в таком порядке:

1. переменная окружения `MP_CONFIG`
2. `--config <path>` или `-c <path>`
3. `mpconfig.toml` рядом с исполняемым файлом

Важно:
- `MP_CONFIG` имеет приоритет над аргументами командной строки.
- Если переопределение не задано, бот ожидает увидеть `mpconfig.toml` в той же директории, что и бинарник.

## Статические Поля И Поля, Привязанные К Runtime

Код различает:
- startup-fixed fields: литеральные значения, читаемые при старте и никогда не перезагружаемые через hot reload
- bindable fields: значения, которые можно указать литерально или сослаться на них из JSON-файла `misc` через плейсхолдеры вроде `{enable_cu_limit}`

### Поля, Фиксируемые При Старте

Эти поля должны содержать литеральные строки или числа в `mpconfig.toml`. Они не могут использовать синтаксис `{placeholder}`:

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

Любое изменение этих полей требует правки `mpconfig.toml` и перезапуска процесса.

### Bindable-Поля

Многие рабочие значения можно задавать либо:
- напрямую, например `cu_limit = 350000`
- по ссылке, например `cu_limit = "{enable_cu_limit}"`

Когда используется синтаксис плейсхолдера, значение разрешается из JSON-документа, загруженного из `external_config.misc`.

Если используется плейсхолдер, а JSON-файл отсутствует, поврежден или не содержит нужного ключа, построение конфигурации завершится ошибкой.

## Привязка Плейсхолдеров

Синтаксис плейсхолдера:

```toml
cu_limit = "{enable_cu_limit}"
```

Соответствующий JSON:

```json
{
  "enable_cu_limit": 350000
}
```

Примечания:
- имена плейсхолдеров чувствительны к регистру
- плейсхолдеры работают только в полях, реализованных как bindable values
- типы должны соответствовать целевому полю
- разрешение плейсхолдеров происходит при построении или повторном построении runtime-конфига из `misc`

## Внешний Конфиг И Hot Reload

Money Printer поддерживает три внешних источника:
- файл markets
- файл LUT
- JSON-файл misc

Они настраиваются в секции `[external_config]`.

### Когда `use_external_data = true`

Бот опрашивает настроенные внешние источники и перезагружает их во время работы.

Текущее поведение:
- поддерживаются локальные пути к файлам и URL вида `http://` / `https://`
- интервал опроса задается в `external_config.poll_interval_ms`
- изменение применяется только после того, как одинаковое содержимое было увидено два раза подряд
  это работает как небольшой debounce и помогает избежать чтения частично записанных файлов

Поведение перезагрузки по типу файла:
- `markets`: перечень рынков перезагружается, и база пулов строится заново
- `lut`: lookup tables перезагружаются, и LUT-кэш транзакций обновляется
- `misc`: runtime-значения заново разрешаются и публикуются без перезапуска бота

Основной файл `mpconfig.toml` не перезагружается.

### Когда `use_external_data = false`

Бот не следит за внешними файлами, но некоторые пути все равно могут использоваться как одноразовые источники на старте.

Текущее стартовое поведение:
- `local_config.markets` и `local_config.lut` имеют приоритет для одноразовой загрузки при старте
- если `local_config` отсутствует, `external_config.markets` и `external_config.lut` все равно могут использоваться как одноразовые входы при старте
- `external_config.misc` все равно может быть прочитан один раз при старте для разрешения плейсхолдеров

Это означает, что `external_config.misc` остается важным даже в режиме без наблюдения, если ваш конфиг использует значения вида `{placeholder}`.

## Общие Соглашения О Значениях

- значения tip указываются в raw lamports
- диапазоны priority fee тоже задаются в raw lamports на транзакцию
- внутри priority fee преобразуется в значение цены compute-budget
- значения cooldown задаются в миллисекундах
- списки endpoint'ов — это литеральные URL

## Поля Верхнего Уровня

### `use_external_data`

Type: `bool`

Управляет тем, отслеживаются ли настроенные внешние источники и перезагружаются ли они во время работы.

Рекомендация:
- `true`, если вам нужен hot reload для списков markets, LUT и runtime-настроек
- `false`, если вам нужна статическая конфигурация, используемая только при старте

### `base_token`

Type: `string`

Базовый торговый mint. На практике текущий код и пример конфига ориентированы на WSOL.

Пример:

```toml
base_token = "So11111111111111111111111111111111111111112"
```

### `info_rpc`

Type: `string`

Основной information RPC endpoint, используемый для:
- чтения account'ов
- загрузки markets
- получения recent blockhash
- других информационных запросов, не связанных с отправкой транзакций

Обычно здесь должен стоять ваш лучший endpoint для чтения.

### `info_rpc_fallback`

Type: `string`, optional

Необязательный fallback для information RPC.

Текущее поведение:
- после 3 последовательных ошибок на основном endpoint'е
- бот переключается на fallback на 30 секунд
- когда основной endpoint восстанавливается, бот переключается обратно

Это относится только к information RPC path, а не к fanout-отправке транзакций.

### `recent_block_hash_refresh_interval`

Type: `u64`, optional

Продвинутая настройка интервала обновления blockhash в миллисекундах.

Если поле опущено, текущий код использует значение `400`.

### `enable_flash`

Type: bindable `bool`

Управляет тем, строит ли бот торговые инструкции с поддержкой flash loan.

Это значение может быть:
- литеральным в `mpconfig.toml`
- привязанным через плейсхолдер из `misc`

### `cu_limit`

Type: bindable `u64`

Глобальный лимит compute units, используемый при построении транзакций.

Обычно этим параметром управляют через `misc`, чтобы можно было менять его без правки основного конфига.

## `[network]`

Эта секция опциональна и отсутствует в example-конфиге.

### `account_refresh_interval`

Type: `u64`

Интервал опроса account'ов в миллисекундах для pool updater'а.

Если поле опущено, текущее значение по умолчанию — `2000`.

Уменьшайте его только в том случае, если ваша инфраструктура действительно это выдерживает.

## `[key_pair]`

Конфигурация кошелька.

### `path_to_secret`

Type: `string`

Абсолютный или относительный путь к файлу Solana keypair, используемому для подписи транзакций.

Ожидаемый формат:
- JSON array keypair file

Это startup-fixed значение и оно не может быть задано через плейсхолдер.

## `[external_config]`

Внешние источники для markets, LUT и runtime-настраиваемых значений.

### `markets`

Type: `string`, optional

Путь или URL к файлу markets.

Формат:
- TOML
- группы задаются через `[[group]]`
- каждая группа содержит список `markets = [ ... ]` с адресами пулов

### `lut`

Type: `string`, optional

Путь или URL к файлу lookup table.

Формат:
- plain text
- один адрес LUT на строку

### `misc`

Type: `string`, optional

Путь или URL к JSON-файлу, в котором хранятся runtime-настраиваемые значения, на которые ссылаются плейсхолдеры.

Формат:
- JSON object

Этот файл является источником значений вроде:
- `enable_cu_limit`
- `enable_min_prio`
- `enable_jito`
- `helius_min_tip`
- и других runtime-настраиваемых ключей

### `poll_interval_ms`

Type: `u64`

Интервал опроса для внешних источников, за которыми бот следит, когда `use_external_data = true`.

Если поле опущено, текущее значение по умолчанию — `100`.

## `[local_config]`

Продвинутая опциональная секция.

Она отсутствует в example-конфиге, но текущий код ее поддерживает.

Назначение:
- одноразовая стартовая загрузка файлов markets и LUT, когда `use_external_data = false`

Поля:
- `markets`
- `lut`

Текущий приоритет в режиме без наблюдения:
1. `local_config.*`
2. `external_config.*`

В отличие от `[external_config]`, эта секция не включает `misc`.

## `[rpc_config]`

Конфигурация стандартного RPC send path.

Используйте эту секцию для обычного RPC transaction fanout.

### `endpoint`

Type: `array<string>`

Список RPC endpoint'ов, используемых для отправки транзакций.

Обычно требуется хотя бы один endpoint, если вы хотите включить RPC-отправку.

### `auth`

Type: `string`

Необязательный authentication token, который использует RPC sender, если он нужен в вашей схеме.

Если ваш провайдер уже аутентифицирует запросы через URL, это поле можно оставить пустым.

### `enabled`

Type: bindable `bool`

Включает или отключает RPC submission fanout.

### `priority_lamports_from`

Type: bindable `u64`

Минимальный priority fee на транзакцию, выраженный в raw lamports.

### `priority_lamports_to`

Type: bindable `u64`

Максимальный priority fee на транзакцию, выраженный в raw lamports.

### `cool_down`

Type: bindable `u64`

Cooldown между циклами RPC-отправки, в миллисекундах.

### `retries`

Type: `u64`

Значение максимального числа повторов, передаваемое в стандартный RPC `sendTransaction`.

Это настройка RPC sender'а. Она не управляет relay sender'ами вроде Jito или Flashblock.

### Networking Fields

Это литеральные числовые поля:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

Они управляют поведением HTTP client'а для стандартного RPC sender'а.

## `[jito_config]`

Конфигурация отправки транзакций через Jito.

### `endpoint`

Type: `array<string>`

Список Jito transaction endpoint'ов.

В отличие от Helius, Astra, Flashblock, Temporal и HelloMoon, Jito endpoint'ы задаются прямо в `mpconfig.toml`.

### `auth`

Type: `string`, optional

Необязательный authentication token для Jito.

### `enabled`

Type: bindable `bool`

Включает или отключает отправку через Jito.

### `tip_lamports_from`

Type: bindable `u64`

Минимальный Jito tip в raw lamports.

### `tip_lamports_to`

Type: bindable `u64`

Максимальный Jito tip в raw lamports.

### `jito_min_prio`

Type: bindable `u64`

Минимальный per-transaction priority fee для пути Jito.

### `jito_max_prio`

Type: bindable `u64`

Максимальный per-transaction priority fee для пути Jito.

### `jito_cooldown_ms`

Type: bindable `u64`

Cooldown sender'а Jito в миллисекундах.

### Networking Fields

Литеральные числовые значения:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

Это Jito-specific настройки HTTP client'а.

## `[helius_config]`

Конфигурация Helius fast sender.

Текущие особенности реализации:
- endpoint'ы зашиты в код
- эта секция в основном задает API key и runtime-настраиваемые значения

### `api_key`

Type: `string`

API key, который добавляется к встроенным URL Helius sender'а.

### `enabled`

Type: bindable `bool`

Включает или отключает Helius fast sender.

### `helius_min_tip`

Type: bindable `u64`

Минимальный Helius tip в raw lamports.

### `helius_max_tip`

Type: bindable `u64`

Максимальный Helius tip в raw lamports.

### `helius_min_prio`

Type: bindable `u64`

Минимальный Helius priority fee в raw lamports на транзакцию.

### `helius_max_prio`

Type: bindable `u64`

Максимальный Helius priority fee в raw lamports на транзакцию.

### `helius_cooldown_ms`

Type: bindable `u64`

Cooldown Helius sender'а в миллисекундах.

Если поле опущено, текущее значение по умолчанию — `250`.

## `[helius_swqos_config]`

Конфигурация Helius SWQoS sender'а.

Текущие особенности реализации:
- используется то же семейство встроенных endpoint'ов, что и у Helius
- поведение API key наследуется из `[helius_config]`
- на уровне sender'а автоматически добавляется `swqos_only=true`

### `enabled`

Type: bindable `bool`

Включает или отключает Helius SWQoS sender.

### `helius_swqos_min_tip`

Type: bindable `u64`

Минимальный SWQoS tip в raw lamports.

### `helius_swqos_max_tip`

Type: bindable `u64`

Максимальный SWQoS tip в raw lamports.

### `helius_swqos_min_prio`

Type: bindable `u64`

Минимальный SWQoS priority fee в raw lamports на транзакцию.

### `helius_swqos_max_prio`

Type: bindable `u64`

Максимальный SWQoS priority fee в raw lamports на транзакцию.

### `helius_swqos_cooldown_ms`

Type: bindable `u64`

Cooldown SWQoS sender'а в миллисекундах.

Если поле опущено, текущее значение по умолчанию — `300`.

## `[temporal_config]`

Конфигурация Temporal / Nozomi sender'а.

Текущие особенности реализации:
- endpoint'ы зашиты в код
- эта секция в основном задает `client_id` и runtime-настраиваемые значения

### `client_id`

Type: `string`

Необязательный client identifier, добавляемый к встроенным URL Temporal sender'а.

### `enabled`

Type: bindable `bool`

Включает или отключает отправку через Temporal.

### `temporal_min_tip`

Type: bindable `u64`

Минимальный Temporal tip в raw lamports.

### `temporal_max_tip`

Type: bindable `u64`

Максимальный Temporal tip в raw lamports.

### `temporal_min_prio`

Type: bindable `u64`

Минимальный Temporal priority fee в raw lamports на транзакцию.

### `temporal_max_prio`

Type: bindable `u64`

Максимальный Temporal priority fee в raw lamports на транзакцию.

### `temporal_cooldown_ms`

Type: bindable `u64`

Cooldown Temporal sender'а в миллисекундах.

Если поле опущено, текущее значение по умолчанию — `300`.

## `[flashblock_config]`

Конфигурация Flashblock sender'а.

Текущие особенности реализации:
- endpoint'ы зашиты в код
- эта секция в основном задает auth и runtime-настраиваемые значения

### `auth`

Type: `string`

Authorization token Flashblock, отправляемый в HTTP-запросе.

### `enabled`

Type: bindable `bool`

Включает или отключает отправку через Flashblock.

### `flashblock_min_tip`

Type: bindable `u64`

Минимальный Flashblock tip в raw lamports.

### `flashblock_max_tip`

Type: bindable `u64`

Максимальный Flashblock tip в raw lamports.

### `flashblock_min_prio`

Type: bindable `u64`

Минимальный Flashblock priority fee в raw lamports на транзакцию.

### `flashblock_max_prio`

Type: bindable `u64`

Максимальный Flashblock priority fee в raw lamports на транзакцию.

### `flashblock_cooldown_ms`

Type: bindable `u64`

Cooldown Flashblock sender'а в миллисекундах.

Если поле опущено, текущее значение по умолчанию — `320`.

## `[astra_config]`

Конфигурация Astra sender'а.

Текущие особенности реализации:
- endpoint'ы зашиты в код
- эта секция в основном задает API key и runtime-настраиваемые значения

### `api_key`

Type: `string`

API key, используемый при отправке в endpoint'ы Astra.

### `enable_astra`

Type: bindable `bool`

Включает или отключает отправку через Astra.

### `enable_astra_min_tip`

Type: bindable `u64`

Минимальный Astra tip в raw lamports.

### `enable_astra_max_tip`

Type: bindable `u64`

Максимальный Astra tip в raw lamports.

### `astra_min_prio`

Type: bindable `u64`

Минимальный Astra priority fee в raw lamports на транзакцию.

### `astra_max_prio`

Type: bindable `u64`

Максимальный Astra priority fee в raw lamports на транзакцию.

### `astralane_cooldown_ms`

Type: bindable `u64`

Cooldown Astra sender'а в миллисекундах.

Если поле опущено, текущее значение по умолчанию — `300`.

## `[hellomoon_config]`

Конфигурация HelloMoon sender'а.

Текущие особенности реализации:
- endpoint'ы зашиты в код
- эта секция в основном задает API key и runtime-настраиваемые значения

### `api_key`

Type: `string`

API key, добавляемый к встроенным URL HelloMoon sender'а.

### `enable_hellomoon`

Type: bindable `bool`

Включает или отключает отправку через HelloMoon.

### `hellomoon_min_tip`

Type: bindable `u64`

Минимальный HelloMoon tip в raw lamports.

### `hellomoon_max_tip`

Type: bindable `u64`

Максимальный HelloMoon tip в raw lamports.

### `hellomoon_min_prio`

Type: bindable `u64`

Минимальный HelloMoon priority fee в raw lamports на транзакцию.

### `hellomoon_max_prio`

Type: bindable `u64`

Максимальный HelloMoon priority fee в raw lamports на транзакцию.

### `hellomoon_cooldown_ms`

Type: bindable `u64`

Cooldown HelloMoon sender'а в миллисекундах.

Если поле опущено, текущее значение по умолчанию — `300`.

## Операционные Примечания

### 1. `info_rpc` и `rpc_config.endpoint` выполняют разные роли

- `info_rpc` — это основной read/information RPC для бота
- `rpc_config.endpoint` — это список endpoint'ов для transaction submission RPC fanout

Не считайте их взаимозаменяемыми.

### 2. Пример внешних файлов опционален, но пути важны

Если `mpconfig.toml` указывает на `config/markets.toml`, `config/lut.txt` и `config/gas.json`, эти файлы должны существовать во время работы.

### 3. Конфиги на плейсхолдерах требуют `misc`

Если вы используете значения вида `{placeholder}` в любых bindable-полях, соответствующий ключ должен существовать в JSON-документе `misc`.

### 4. Некорректные обновления `misc` опасны

Некорректный JSON или отсутствие нужных значений может сломать повторное построение runtime-конфига. Относитесь к правкам `gas.json` как к операционно чувствительным изменениям.

### 5. Обновления markets и LUT влияют на live execution

Перезагрузка markets или LUT меняет то, что бот может строить и отправлять. Относитесь к этим файлам как к живым торговым входам, а не как к пассивным метаданным.

### 6. Поддерживаются внешние URL

Источники `markets`, `lut` и `misc` могут обслуживаться по HTTP или HTTPS. Это удобно, если ваша существующая автоматизация уже публикует конфиги бота из центральной точки.

## Рекомендуемый Стартовый Шаблон

Для чистой операционной раскладки:

1. Держите `mpconfig.toml` в основном статичным.
2. Быстро меняющиеся runtime-значения выносите в `gas.json`.
3. Изменения universe пулов выносите в `markets.toml`.
4. Изменения lookup table выносите в `lut.txt`.
5. Включайте `use_external_data = true`, если вам нужно live reload behavior.

Такой подход разделяет credentials, endpoint'ы и runtime-настройки способом, который проще автоматизировать и безопаснее эксплуатировать.
