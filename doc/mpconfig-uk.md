# Посібник з `mpconfig.toml`

У цьому документі пояснюється основний конфігураційний файл Money Printer і те, як бот використовує його під час роботи.

Використовуйте його разом із:
- [`../mpconfig.example.toml`](../mpconfig.example.toml)
- [`../config/README.md`](../config/README.md)

## Призначення

`mpconfig.toml` — це основний конфігураційний файл оператора. Він визначає:
- розташування гаманця
- information RPC endpoints
- канали відправлення транзакцій
- облікові дані sender'ів
- зовнішні джерела конфігурації
- значення, що налаштовуються під час роботи, і прив'язки placeholders

Файл читається один раз під час старту. Бот не відстежує його зміни. Якщо ви відредагували `mpconfig.toml`, перезапустіть бота.

## Як Бот Знаходить Конфігураційний Файл

Money Printer визначає шлях до основного конфігураційного файлу в такому порядку:

1. змінна середовища `MP_CONFIG`
2. `--config <path>` або `-c <path>`
3. `mpconfig.toml` поруч із виконуваним файлом

Важливо:
- `MP_CONFIG` має пріоритет над аргументами командного рядка.
- Якщо override не задано, бот очікує, що `mpconfig.toml` буде в тій самій директорії, що й бінарний файл.

## Статичні Поля Та Поля, Прив'язані До Runtime

Код розрізняє:
- startup-fixed fields: буквальні значення, які зчитуються під час старту і ніколи не перезавантажуються через hot reload
- bindable fields: значення, які можна задати буквально або послатися на них із JSON-файлу `misc` через placeholders на кшталт `{enable_cu_limit}`

### Поля, Фіксовані Під Час Старту

Ці поля мають бути буквальними рядками або числами в `mpconfig.toml`. Вони не можуть використовувати синтаксис `{placeholder}`:

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

Будь-яка зміна цих полів вимагає редагування `mpconfig.toml` і перезапуску процесу.

### Bindable-Поля

Багато робочих значень можна вказати або:
- напряму, наприклад `cu_limit = 350000`
- або через посилання, наприклад `cu_limit = "{enable_cu_limit}"`

Коли використовується синтаксис placeholder, значення розв'язується з JSON-документа, завантаженого з `external_config.misc`.

Якщо використовується placeholder, а JSON-файл відсутній, пошкоджений або не містить потрібного ключа, побудова конфігурації завершиться помилкою.

## Прив'язка Placeholders

Синтаксис placeholder:

```toml
cu_limit = "{enable_cu_limit}"
```

Відповідний JSON:

```json
{
  "enable_cu_limit": 350000
}
```

Примітки:
- імена placeholders чутливі до регістру
- placeholders працюють лише в полях, реалізованих як bindable values
- типи повинні відповідати цільовому полю
- розв'язання placeholders відбувається під час побудови або повторної побудови runtime-конфігурації з `misc`

## Зовнішня Конфігурація Та Hot Reload

Money Printer підтримує три зовнішні джерела:
- файл markets
- файл LUT
- JSON-файл misc

Вони налаштовуються в секції `[external_config]`.

### Коли `use_external_data = true`

Бот опитує налаштовані зовнішні джерела й перезавантажує їх під час роботи.

Поточна поведінка:
- підтримуються локальні шляхи до файлів і URL типу `http://` / `https://`
- інтервал опитування задається через `external_config.poll_interval_ms`
- зміна застосовується лише після того, як однаковий вміст був побачений двічі поспіль
  це працює як невеликий debounce і допомагає уникати читання частково записаних файлів

Поведінка перезавантаження за типом файлу:
- `markets`: перелік ринків перезавантажується, а база пулів перебудовується
- `lut`: lookup tables перезавантажуються, а LUT-кеш транзакцій оновлюється
- `misc`: runtime-значення повторно розв'язуються і публікуються без перезапуску бота

Основний файл `mpconfig.toml` не перезавантажується.

### Коли `use_external_data = false`

Бот не відстежує зовнішні файли, але деякі шляхи все одно можуть використовуватися як одноразові джерела під час старту.

Поточна стартова поведінка:
- `local_config.markets` і `local_config.lut` мають пріоритет для одноразового завантаження під час старту
- якщо `local_config` відсутній, `external_config.markets` і `external_config.lut` усе одно можуть використовуватися як одноразові вхідні джерела під час старту
- `external_config.misc` усе одно може бути прочитаний один раз під час старту для розв'язання placeholders

Це означає, що `external_config.misc` залишається важливим навіть у режимі без спостереження, якщо ваш конфіг використовує значення виду `{placeholder}`.

## Загальні Домовленості Про Значення

- значення tip задаються в raw lamports
- діапазони priority fee також задаються в raw lamports на транзакцію
- всередині priority fee перетворюється на значення compute-budget price
- значення cooldown задаються в мілісекундах
- списки endpoint'ів — це буквальні URL

## Поля Верхнього Рівня

### `use_external_data`

Type: `bool`

Керує тим, чи відстежуються налаштовані зовнішні джерела й чи перезавантажуються вони під час роботи.

Рекомендація:
- `true`, якщо вам потрібен hot reload для списків markets, LUT і runtime-налаштувань
- `false`, якщо вам потрібна статична конфігурація, яка діє лише під час старту

### `base_token`

Type: `string`

Базовий торговий mint. На практиці поточний код і приклад конфігурації орієнтовані на WSOL.

Приклад:

```toml
base_token = "So11111111111111111111111111111111111111112"
```

### `info_rpc`

Type: `string`

Основний information RPC endpoint, який використовується для:
- читання accounts
- завантаження markets
- отримання recent blockhash
- інших інформаційних запитів, не пов'язаних із відправленням

Зазвичай тут має бути ваш найкращий endpoint для читання.

### `info_rpc_fallback`

Type: `string`, optional

Необов'язковий fallback для information RPC.

Поточна поведінка:
- після 3 послідовних помилок на основному endpoint'і
- бот переключається на fallback на 30 секунд
- щойно основний endpoint відновлюється, бот переключається назад

Це стосується лише information RPC path, а не fanout-відправлення транзакцій.

### `recent_block_hash_refresh_interval`

Type: `u64`, optional

Розширене налаштування інтервалу оновлення blockhash у мілісекундах.

Якщо поле пропущене, поточний код використовує значення `400`.

### `enable_flash`

Type: bindable `bool`

Керує тим, чи будує бот торгові інструкції з увімкненим flash-loan.

Це значення може бути:
- буквальним у `mpconfig.toml`
- прив'язаним через placeholder із `misc`

### `cu_limit`

Type: bindable `u64`

Глобальний ліміт compute units, який використовується під час побудови транзакцій.

Зазвичай цим параметром керують через `misc`, щоб його можна було змінювати без редагування основного конфігу.

## `[network]`

Ця секція є опціональною та відсутня в example-конфігу.

### `account_refresh_interval`

Type: `u64`

Інтервал опитування в мілісекундах для оновлення accounts у pool updater'і.

Якщо поле пропущене, поточне значення за замовчуванням — `2000`.

Зменшуйте його лише тоді, коли ваша інфраструктура справді може це витримати.

## `[key_pair]`

Конфігурація гаманця.

### `path_to_secret`

Type: `string`

Абсолютний або відносний шлях до файлу Solana keypair, який використовується для підпису транзакцій.

Очікуваний формат:
- JSON array keypair file

Це startup-fixed значення і воно не може бути задане через placeholder.

## `[external_config]`

Зовнішні джерела для markets, LUT і runtime-значень, що налаштовуються.

### `markets`

Type: `string`, optional

Шлях або URL до файлу markets.

Формат:
- TOML
- групи задаються через `[[group]]`
- кожна група містить список `markets = [ ... ]` з адресами пулів

### `lut`

Type: `string`, optional

Шлях або URL до файлу lookup table.

Формат:
- plain text
- одна адреса LUT на рядок

### `misc`

Type: `string`, optional

Шлях або URL до JSON-файлу, який містить runtime-значення, на які посилаються placeholders.

Формат:
- JSON object

Цей файл є джерелом значень на кшталт:
- `enable_cu_limit`
- `enable_min_prio`
- `enable_jito`
- `helius_min_tip`
- та інших ключів, які можна налаштовувати під час роботи

### `poll_interval_ms`

Type: `u64`

Інтервал опитування для зовнішніх джерел, за якими бот стежить, коли `use_external_data = true`.

Якщо поле пропущене, поточне значення за замовчуванням — `100`.

## `[local_config]`

Розширена опціональна секція.

Вона відсутня в example-конфігу, але поточний код її підтримує.

Призначення:
- одноразове стартове завантаження файлів markets і LUT, коли `use_external_data = false`

Поля:
- `markets`
- `lut`

Поточний пріоритет у режимі без спостереження:
1. `local_config.*`
2. `external_config.*`

На відміну від `[external_config]`, ця секція не містить `misc`.

## `[rpc_config]`

Конфігурація стандартного RPC send path.

Використовуйте цю секцію для звичайного RPC transaction fanout.

### `endpoint`

Type: `array<string>`

Список RPC endpoint'ів, які використовуються для відправлення транзакцій.

Зазвичай потрібен принаймні один endpoint, якщо ви хочете увімкнути RPC-відправлення.

### `auth`

Type: `string`

Необов'язковий authentication token, який використовує RPC sender, якщо він потрібен у вашій схемі.

Якщо ваш провайдер уже аутентифікує через URL, це поле можна залишити порожнім.

### `enabled`

Type: bindable `bool`

Увімкнення або вимкнення RPC submission fanout.

### `priority_lamports_from`

Type: bindable `u64`

Мінімальний priority fee на транзакцію, виражений у raw lamports.

### `priority_lamports_to`

Type: bindable `u64`

Максимальний priority fee на транзакцію, виражений у raw lamports.

### `cool_down`

Type: bindable `u64`

Cooldown між циклами RPC-відправлення, у мілісекундах.

### `retries`

Type: `u64`

Значення maximum retries, яке передається до стандартного RPC `sendTransaction`.

Це налаштування RPC sender'а. Воно не керує relay sender'ами на кшталт Jito або Flashblock.

### Networking Fields

Це буквальні числові поля:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

Вони керують поведінкою HTTP client'а для стандартного RPC sender'а.

## `[jito_config]`

Конфігурація відправлення транзакцій через Jito.

### `endpoint`

Type: `array<string>`

Список Jito transaction endpoint'ів.

На відміну від Helius, Astra, Flashblock, Temporal і HelloMoon, Jito endpoint'и задаються безпосередньо в `mpconfig.toml`.

### `auth`

Type: `string`, optional

Необов'язковий authentication token для Jito.

### `enabled`

Type: bindable `bool`

Увімкнення або вимкнення відправлення через Jito.

### `tip_lamports_from`

Type: bindable `u64`

Мінімальний Jito tip у raw lamports.

### `tip_lamports_to`

Type: bindable `u64`

Максимальний Jito tip у raw lamports.

### `jito_min_prio`

Type: bindable `u64`

Мінімальний per-transaction priority fee для шляху Jito.

### `jito_max_prio`

Type: bindable `u64`

Максимальний per-transaction priority fee для шляху Jito.

### `jito_cooldown_ms`

Type: bindable `u64`

Cooldown Jito sender'а в мілісекундах.

### Networking Fields

Буквальні числові значення:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

Це Jito-specific налаштування HTTP client'а.

## `[helius_config]`

Конфігурація Helius fast sender.

Поточні особливості реалізації:
- endpoint'и зашиті в код
- ця секція здебільшого задає API key і runtime-значення, що налаштовуються

### `api_key`

Type: `string`

API key, який додається до вбудованих URL Helius sender'а.

### `enabled`

Type: bindable `bool`

Увімкнення або вимкнення Helius fast sender.

### `helius_min_tip`

Type: bindable `u64`

Мінімальний Helius tip у raw lamports.

### `helius_max_tip`

Type: bindable `u64`

Максимальний Helius tip у raw lamports.

### `helius_min_prio`

Type: bindable `u64`

Мінімальний Helius priority fee в raw lamports на транзакцію.

### `helius_max_prio`

Type: bindable `u64`

Максимальний Helius priority fee в raw lamports на транзакцію.

### `helius_cooldown_ms`

Type: bindable `u64`

Cooldown Helius sender'а в мілісекундах.

Якщо поле пропущене, поточне значення за замовчуванням — `250`.

## `[helius_swqos_config]`

Конфігурація Helius SWQoS sender'а.

Поточні особливості реалізації:
- використовується та сама сім'я вбудованих endpoint'ів, що й у Helius
- поведінка API key успадковується з `[helius_config]`
- на рівні sender'а автоматично додається `swqos_only=true`

### `enabled`

Type: bindable `bool`

Увімкнення або вимкнення Helius SWQoS sender.

### `helius_swqos_min_tip`

Type: bindable `u64`

Мінімальний SWQoS tip у raw lamports.

### `helius_swqos_max_tip`

Type: bindable `u64`

Максимальний SWQoS tip у raw lamports.

### `helius_swqos_min_prio`

Type: bindable `u64`

Мінімальний SWQoS priority fee в raw lamports на транзакцію.

### `helius_swqos_max_prio`

Type: bindable `u64`

Максимальний SWQoS priority fee в raw lamports на транзакцію.

### `helius_swqos_cooldown_ms`

Type: bindable `u64`

Cooldown SWQoS sender'а в мілісекундах.

Якщо поле пропущене, поточне значення за замовчуванням — `300`.

## `[temporal_config]`

Конфігурація Temporal / Nozomi sender'а.

Поточні особливості реалізації:
- endpoint'и зашиті в код
- ця секція здебільшого задає `client_id` і runtime-значення, що налаштовуються

### `client_id`

Type: `string`

Необов'язковий client identifier, який додається до вбудованих URL Temporal sender'а.

### `enabled`

Type: bindable `bool`

Увімкнення або вимкнення відправлення через Temporal.

### `temporal_min_tip`

Type: bindable `u64`

Мінімальний Temporal tip у raw lamports.

### `temporal_max_tip`

Type: bindable `u64`

Максимальний Temporal tip у raw lamports.

### `temporal_min_prio`

Type: bindable `u64`

Мінімальний Temporal priority fee в raw lamports на транзакцію.

### `temporal_max_prio`

Type: bindable `u64`

Максимальний Temporal priority fee в raw lamports на транзакцію.

### `temporal_cooldown_ms`

Type: bindable `u64`

Cooldown Temporal sender'а в мілісекундах.

Якщо поле пропущене, поточне значення за замовчуванням — `300`.

## `[flashblock_config]`

Конфігурація Flashblock sender'а.

Поточні особливості реалізації:
- endpoint'и зашиті в код
- ця секція здебільшого задає auth і runtime-значення, що налаштовуються

### `auth`

Type: `string`

Authorization token Flashblock, який передається в HTTP-запиті.

### `enabled`

Type: bindable `bool`

Увімкнення або вимкнення відправлення через Flashblock.

### `flashblock_min_tip`

Type: bindable `u64`

Мінімальний Flashblock tip у raw lamports.

### `flashblock_max_tip`

Type: bindable `u64`

Максимальний Flashblock tip у raw lamports.

### `flashblock_min_prio`

Type: bindable `u64`

Мінімальний Flashblock priority fee в raw lamports на транзакцію.

### `flashblock_max_prio`

Type: bindable `u64`

Максимальний Flashblock priority fee в raw lamports на транзакцію.

### `flashblock_cooldown_ms`

Type: bindable `u64`

Cooldown Flashblock sender'а в мілісекундах.

Якщо поле пропущене, поточне значення за замовчуванням — `320`.

## `[astra_config]`

Конфігурація Astra sender'а.

Поточні особливості реалізації:
- endpoint'и зашиті в код
- ця секція здебільшого задає API key і runtime-значення, що налаштовуються

### `api_key`

Type: `string`

API key, який використовується під час відправлення до endpoint'ів Astra.

### `enable_astra`

Type: bindable `bool`

Увімкнення або вимкнення відправлення через Astra.

### `enable_astra_min_tip`

Type: bindable `u64`

Мінімальний Astra tip у raw lamports.

### `enable_astra_max_tip`

Type: bindable `u64`

Максимальний Astra tip у raw lamports.

### `astra_min_prio`

Type: bindable `u64`

Мінімальний Astra priority fee в raw lamports на транзакцію.

### `astra_max_prio`

Type: bindable `u64`

Максимальний Astra priority fee в raw lamports на транзакцію.

### `astralane_cooldown_ms`

Type: bindable `u64`

Cooldown Astra sender'а в мілісекундах.

Якщо поле пропущене, поточне значення за замовчуванням — `300`.

## `[hellomoon_config]`

Конфігурація HelloMoon sender'а.

Поточні особливості реалізації:
- endpoint'и зашиті в код
- ця секція здебільшого задає API key і runtime-значення, що налаштовуються

### `api_key`

Type: `string`

API key, який додається до вбудованих URL HelloMoon sender'а.

### `enable_hellomoon`

Type: bindable `bool`

Увімкнення або вимкнення відправлення через HelloMoon.

### `hellomoon_min_tip`

Type: bindable `u64`

Мінімальний HelloMoon tip у raw lamports.

### `hellomoon_max_tip`

Type: bindable `u64`

Максимальний HelloMoon tip у raw lamports.

### `hellomoon_min_prio`

Type: bindable `u64`

Мінімальний HelloMoon priority fee в raw lamports на транзакцію.

### `hellomoon_max_prio`

Type: bindable `u64`

Максимальний HelloMoon priority fee в raw lamports на транзакцію.

### `hellomoon_cooldown_ms`

Type: bindable `u64`

Cooldown HelloMoon sender'а в мілісекундах.

Якщо поле пропущене, поточне значення за замовчуванням — `300`.

## Операційні Примітки

### 1. `info_rpc` і `rpc_config.endpoint` виконують різні ролі

- `info_rpc` — це основний read/information RPC для бота
- `rpc_config.endpoint` — це список endpoint'ів для transaction submission RPC fanout

Не вважайте їх взаємозамінними.

### 2. Приклади зовнішніх файлів є опціональними, але шляхи важливі

Якщо `mpconfig.toml` вказує на `config/markets.toml`, `config/lut.txt` і `config/gas.json`, ці файли повинні існувати під час роботи.

### 3. Конфіги на placeholders вимагають `misc`

Якщо ви використовуєте значення виду `{placeholder}` у будь-яких bindable-полях, відповідний ключ має існувати в JSON-документі `misc`.

### 4. Некоректні оновлення `misc` є високоризиковими

Некоректний JSON або відсутні значення, на які є посилання, можуть зламати повторну побудову runtime-конфігурації. Ставтеся до змін у `gas.json` як до операційно чутливих.

### 5. Оновлення markets і LUT впливають на live execution

Перезавантаження markets або LUT змінює те, що бот може будувати та відправляти. Ставтеся до цих файлів як до живих торгових входів, а не як до пасивних metadata.

### 6. Підтримуються зовнішні URL

Джерела `markets`, `lut` і `misc` можуть обслуговуватися через HTTP або HTTPS. Це зручно, якщо ваша наявна автоматизація вже публікує файли конфігурації бота з центральної точки.

## Рекомендований Стартовий Шаблон

Для чистої операційної розкладки:

1. Тримайте `mpconfig.toml` переважно статичним.
2. Швидкозмінні runtime-значення виносьте в `gas.json`.
3. Зміни у universe пулів виносьте в `markets.toml`.
4. Зміни в lookup table виносьте в `lut.txt`.
5. Вмикайте `use_external_data = true`, якщо вам потрібен live reload behavior.

Такий підхід розділяє credentials, endpoint'и й runtime-налаштування способом, який простіше автоматизувати та безпечніше експлуатувати.
