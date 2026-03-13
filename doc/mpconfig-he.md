# מדריך `mpconfig.toml`

מסמך זה מסביר את קובץ התצורה הראשי של Money Printer ואת האופן שבו הבוט משתמש בו בזמן ריצה.

השתמשו בו יחד עם:
- [`../mpconfig.example.toml`](../mpconfig.example.toml)
- [`../config/README.md`](../config/README.md)

## מטרה

`mpconfig.toml` הוא קובץ התצורה הראשי של המפעיל. הוא מגדיר:
- מיקום הארנק
- נקודות קצה של information RPC
- ערוצי שליחת טרנזקציות
- פרטי גישה של sender'ים
- מקורות תצורה חיצוניים
- ערכים שניתנים לכוונון בזמן ריצה וקישורי placeholders

הקובץ נקרא פעם אחת בעת האתחול. הבוט אינו עוקב אחרי שינויים בו. אם ערכתם את `mpconfig.toml`, יש להפעיל מחדש את הבוט.

## איך הבוט מוצא את קובץ התצורה

Money Printer פותר את הנתיב לקובץ התצורה הראשי בסדר הבא:

1. משתנה הסביבה `MP_CONFIG`
2. `--config <path>` או `-c <path>`
3. `mpconfig.toml` ליד קובץ ההפעלה

חשוב:
- `MP_CONFIG` מקבל עדיפות על פני ארגומנטים של שורת הפקודה.
- אם לא סופק override, הבוט מצפה למצוא את `mpconfig.toml` באותה תיקייה שבה נמצא הבינארי.

## שדות סטטיים לעומת שדות שתלויים ב-runtime

הקוד מבדיל בין:
- startup-fixed fields: ערכים ליטרליים שנקראים באתחול ואינם נטענים מחדש ב-hot reload
- bindable fields: ערכים שניתן לכתוב אותם כליטרלים או להפנות אליהם מתוך ה-JSON של `misc` באמצעות placeholders כגון `{enable_cu_limit}`

### שדות שמקובעים בזמן האתחול

שדות אלה חייבים להכיל מחרוזות או מספרים ליטרליים בתוך `mpconfig.toml`. הם אינם יכולים להשתמש בתחביר `{placeholder}`:

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

שינוי של אחד מהשדות האלה דורש עריכה של `mpconfig.toml` והפעלה מחדש של התהליך.

### שדות bindable

הרבה ערכים תפעוליים ניתן לכתוב או:
- ישירות, לדוגמה `cu_limit = 350000`
- באמצעות הפניה, לדוגמה `cu_limit = "{enable_cu_limit}"`

כאשר משתמשים בתחביר placeholder, הערך נפתר מתוך מסמך ה-JSON שנטען מ-`external_config.misc`.

אם נעשה שימוש ב-placeholder וקובץ ה-JSON חסר, פגום, או שאינו מכיל את המפתח הנדרש, בניית התצורה תיכשל.

## קשירת placeholders

תחביר placeholder:

```toml
cu_limit = "{enable_cu_limit}"
```

JSON תואם:

```json
{
  "enable_cu_limit": 350000
}
```

הערות:
- שמות placeholders רגישים לרישיות
- placeholders עובדים רק בשדות שממומשים כ-bindable values
- הסוגים חייבים להתאים לשדה היעד
- פתרון placeholders מתרחש כאשר נבנית או נבנית מחדש תצורת ה-runtime מתוך `misc`

## תצורה חיצונית ו-hot reload

Money Printer תומך בשלושה מקורות חיצוניים:
- קובץ markets
- קובץ LUT
- קובץ JSON בשם misc

אלה מוגדרים תחת `[external_config]`.

### כאשר `use_external_data = true`

הבוט מבצע polling למקורות החיצוניים שהוגדרו ומטעין אותם מחדש בזמן ריצה.

ההתנהגות הנוכחית:
- נתמכים נתיבי קבצים מקומיים ו-URLs מהסוג `http://` / `https://`
- מרווח ה-polling נקבע על ידי `external_config.poll_interval_ms`
- שינוי מוחל רק לאחר שאותו תוכן נצפה פעמיים ברצף
  זה פועל כמו debounce קטן ועוזר להימנע מקריאה של כתיבה חלקית

התנהגות הטעינה מחדש לפי סוג קובץ:
- `markets`: יקום השווקים נטען מחדש ומסד הנתונים של ה-pools נבנה מחדש
- `lut`: ה-lookup tables נטענים מחדש ו-cache ה-LUT של הטרנזקציות מתרענן
- `misc`: ערכי ה-runtime נפתרים מחדש ומתפרסמים בלי להפעיל מחדש את הבוט

הקובץ הראשי `mpconfig.toml` אינו נטען מחדש.

### כאשר `use_external_data = false`

הבוט אינו עוקב אחרי קבצים חיצוניים, אך חלק מהנתיבים עדיין יכולים לשמש כמקורות חד-פעמיים בזמן האתחול.

התנהגות האתחול הנוכחית:
- ל-`local_config.markets` ול-`local_config.lut` יש עדיפות לטעינה חד-פעמית באתחול
- אם `local_config` לא קיים, עדיין ניתן להשתמש ב-`external_config.markets` וב-`external_config.lut` כקלט חד-פעמי באתחול
- ייתכן ש-`external_config.misc` עדיין ייקרא פעם אחת באתחול כדי לפתור placeholders

המשמעות היא ש-`external_config.misc` עדיין רלוונטי גם במצב ללא מעקב, אם התצורה שלכם משתמשת בערכים מהצורה `{placeholder}`.

## מוסכמות כלליות לערכים

- ערכי tip מצוינים ב-raw lamports
- טווחי priority fee מצוינים גם הם ב-raw lamports לכל טרנזקציה
- פנימית, priority fees מומרים לערכי מחיר של compute-budget
- ערכי cooldown נמדדים במילישניות
- רשימות endpoint הן URLs ליטרליים

## שדות ברמת העליונה

### `use_external_data`

Type: `bool`

קובע האם לעקוב אחרי מקורות חיצוניים שהוגדרו ולטעון אותם מחדש בזמן ריצה.

מומלץ:
- `true` אם אתם רוצים hot reload עבור רשימות markets, LUT וערכי runtime
- `false` אם אתם רוצים תצורה סטטית שפועלת רק בזמן האתחול

### `base_token`

Type: `string`

ה-mint הבסיסי למסחר. בפועל, הקוד הנוכחי וקובץ הדוגמה ממוקדים ב-WSOL.

דוגמה:

```toml
base_token = "So11111111111111111111111111111111111111112"
```

### `info_rpc`

Type: `string`

נקודת ה-information RPC הראשית שמשמשת עבור:
- קריאת accounts
- טעינת markets
- שליפת recent blockhash
- בקשות מידע אחרות שאינן שליחה

בדרך כלל זה צריך להיות endpoint הקריאה הטוב ביותר שלכם.

### `info_rpc_fallback`

Type: `string`, optional

fallback אופציונלי עבור information RPC.

ההתנהגות הנוכחית:
- לאחר 3 כשלים רצופים ב-endpoint הראשי
- הבוט עובר ל-fallback למשך 30 שניות
- כאשר הראשי מתאושש, הבוט עובר אליו בחזרה

זה חל רק על information RPC path, ולא על fanout של שליחת טרנזקציות.

### `recent_block_hash_refresh_interval`

Type: `u64`, optional

הגדרה מתקדמת לקצב רענון ה-blockhash במילישניות.

אם השדה לא מוגדר, הקוד הנוכחי נופל חזרה ל-`400`.

### `enable_flash`

Type: bindable `bool`

קובע האם הבוט בונה הוראות מסחר עם flash loan.

הערך יכול להיות:
- ליטרלי בתוך `mpconfig.toml`
- קשור באמצעות placeholder מתוך `misc`

### `cu_limit`

Type: bindable `u64`

מגבלת compute units גלובלית שמשמשת בעת בניית טרנזקציות.

בדרך כלל מגדירים את הערך הזה דרך `misc`, כדי שניתן יהיה לשנות אותו בלי לערוך את קובץ התצורה הראשי.

## `[network]`

הסקציה הזו אופציונלית ואינה מופיעה בקובץ הדוגמה.

### `account_refresh_interval`

Type: `u64`

מרווח ה-polling במילישניות לריענון accounts בתוך ה-pool updater.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `2000`.

יש להקטין אותו רק אם התשתית שלכם באמת יכולה לעמוד בכך.

## `[key_pair]`

תצורת הארנק.

### `path_to_secret`

Type: `string`

נתיב מוחלט או יחסי לקובץ ה-Solana keypair שמשמש לחתימת טרנזקציות.

הפורמט המצופה:
- JSON array keypair file

בהפעלה הראשונה, קובץ ה-keypair יוצפן אוטומטית אם הוא עדיין לא מוצפן.

זהו ערך startup-fixed ואי אפשר לקשור אותו באמצעות placeholder.

## `[external_config]`

מקורות חיצוניים עבור markets, LUT וערכי runtime.

### `markets`

Type: `string`, optional

נתיב או URL אל קובץ ה-markets.

פורמט:
- TOML
- קבוצות תחת `[[group]]`
- כל קבוצה מכילה רשימת `markets = [ ... ]` של כתובות pools

### `lut`

Type: `string`, optional

נתיב או URL אל קובץ ה-lookup table.

פורמט:
- plain text
- כתובת LUT אחת בכל שורה

### `misc`

Type: `string`, optional

נתיב או URL אל קובץ JSON שמכיל ערכי runtime שניתנים לכוונון ושאליהם מפנים placeholders.

פורמט:
- JSON object

קובץ זה הוא מקור לערכים כגון:
- `enable_cu_limit`
- `enable_min_prio`
- `enable_jito`
- `helius_min_tip`
- ומפתחות runtime נוספים

### `poll_interval_ms`

Type: `u64`

מרווח ה-polling עבור מקורות חיצוניים שנמצאים תחת מעקב כאשר `use_external_data = true`.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `100`.

## `[local_config]`

סקציה מתקדמת ואופציונלית.

היא אינה מופיעה בקובץ הדוגמה, אך הקוד הנוכחי תומך בה.

מטרה:
- טעינה חד-פעמית באתחול של קבצי markets ו-LUT כאשר `use_external_data = false`

שדות:
- `markets`
- `lut`

הקדימות הנוכחית במצב ללא מעקב:
1. `local_config.*`
2. `external_config.*`

בניגוד ל-`[external_config]`, הסקציה הזו אינה כוללת `misc`.

## `[rpc_config]`

תצורת standard RPC send path.

השתמשו בסקציה הזו עבור RPC transaction fanout רגיל.

### `endpoint`

Type: `array<string>`

רשימת RPC endpoints שמשמשים לשליחת טרנזקציות.

בדרך כלל נדרש לפחות endpoint אחד אם אתם רוצים ש-RPC sending יהיה מופעל.

### `auth`

Type: `string`

authentication token אופציונלי שבו RPC sender משתמש אם הוא נדרש בתצורה שלכם.

אם ספק ה-RPC שלכם כבר מבצע authentication דרך ה-URL, אפשר להשאיר את השדה הזה ריק.

### `enabled`

Type: bindable `bool`

מפעיל או מכבה את RPC submission fanout.

### `priority_lamports_from`

Type: bindable `u64`

priority fee מינימלי לטרנזקציה, מבוטא ב-raw lamports.

### `priority_lamports_to`

Type: bindable `u64`

priority fee מקסימלי לטרנזקציה, מבוטא ב-raw lamports.

### `cool_down`

Type: bindable `u64`

Cooldown בין מחזורי שליחה ב-RPC, במילישניות.

### `retries`

Type: `u64`

ערך ה-maximum retries שמועבר אל `sendTransaction` הסטנדרטי של RPC.

זוהי הגדרה של RPC sender. היא אינה שולטת על relay senders כמו Jito או Flashblock.

### Networking Fields

אלה שדות מספריים ליטרליים:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

הם שולטים בהתנהגות של HTTP client עבור ה-RPC sender הסטנדרטי.

## `[jito_config]`

תצורה לשליחת טרנזקציות דרך Jito.

### `endpoint`

Type: `array<string>`

רשימת Jito transaction endpoints.

בניגוד ל-Helius, Astra, Flashblock, Temporal ו-HelloMoon, נקודות הקצה של Jito מוגדרות ישירות בתוך `mpconfig.toml`.

### `auth`

Type: `string`, optional

authentication token אופציונלי עבור Jito.

### `enabled`

Type: bindable `bool`

מפעיל או מכבה שליחה דרך Jito.

### `tip_lamports_from`

Type: bindable `u64`

Jito tip מינימלי ב-raw lamports.

### `tip_lamports_to`

Type: bindable `u64`

Jito tip מקסימלי ב-raw lamports.

### `jito_min_prio`

Type: bindable `u64`

priority fee מינימלי לכל טרנזקציה עבור נתיב Jito.

### `jito_max_prio`

Type: bindable `u64`

priority fee מקסימלי לכל טרנזקציה עבור נתיב Jito.

### `jito_cooldown_ms`

Type: bindable `u64`

Cooldown של Jito sender במילישניות.

### Networking Fields

ערכים מספריים ליטרליים:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

אלה הגדרות HTTP client ייעודיות ל-Jito.

## `[helius_config]`

תצורת Helius fast sender.

הערות יישום נוכחיות:
- ה-endpoints מובנים בתוך הקוד
- הסקציה הזאת מספקת בעיקר API key וערכי runtime

### `api_key`

Type: `string`

API key שמצורף ל-URLs המובנים של Helius sender.

### `enabled`

Type: bindable `bool`

מפעיל או מכבה את Helius fast sender.

### `helius_min_tip`

Type: bindable `u64`

Helius tip מינימלי ב-raw lamports.

### `helius_max_tip`

Type: bindable `u64`

Helius tip מקסימלי ב-raw lamports.

### `helius_min_prio`

Type: bindable `u64`

Helius priority fee מינימלי ב-raw lamports לכל טרנזקציה.

### `helius_max_prio`

Type: bindable `u64`

Helius priority fee מקסימלי ב-raw lamports לכל טרנזקציה.

### `helius_cooldown_ms`

Type: bindable `u64`

Cooldown של Helius sender במילישניות.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `250`.

## `[helius_swqos_config]`

תצורת Helius SWQoS sender.

הערות יישום נוכחיות:
- נעשה שימוש באותה משפחת endpoints מובנית כמו אצל Helius
- התנהגות ה-API key נלקחת מתוך `[helius_config]`
- ברמת ה-sender מתווסף `swqos_only=true`

### `enabled`

Type: bindable `bool`

מפעיל או מכבה את Helius SWQoS sender.

### `helius_swqos_min_tip`

Type: bindable `u64`

SWQoS tip מינימלי ב-raw lamports.

### `helius_swqos_max_tip`

Type: bindable `u64`

SWQoS tip מקסימלי ב-raw lamports.

### `helius_swqos_min_prio`

Type: bindable `u64`

SWQoS priority fee מינימלי ב-raw lamports לכל טרנזקציה.

### `helius_swqos_max_prio`

Type: bindable `u64`

SWQoS priority fee מקסימלי ב-raw lamports לכל טרנזקציה.

### `helius_swqos_cooldown_ms`

Type: bindable `u64`

Cooldown של SWQoS sender במילישניות.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `300`.

## `[temporal_config]`

תצורת Temporal / Nozomi sender.

הערות יישום נוכחיות:
- ה-endpoints מובנים בתוך הקוד
- הסקציה הזאת מספקת בעיקר `client_id` וערכי runtime

### `client_id`

Type: `string`

מזהה לקוח אופציונלי שמצורף ל-URLs המובנים של Temporal sender.

### `enabled`

Type: bindable `bool`

מפעיל או מכבה שליחה דרך Temporal.

### `temporal_min_tip`

Type: bindable `u64`

Temporal tip מינימלי ב-raw lamports.

### `temporal_max_tip`

Type: bindable `u64`

Temporal tip מקסימלי ב-raw lamports.

### `temporal_min_prio`

Type: bindable `u64`

Temporal priority fee מינימלי ב-raw lamports לכל טרנזקציה.

### `temporal_max_prio`

Type: bindable `u64`

Temporal priority fee מקסימלי ב-raw lamports לכל טרנזקציה.

### `temporal_cooldown_ms`

Type: bindable `u64`

Cooldown של Temporal sender במילישניות.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `300`.

## `[flashblock_config]`

תצורת Flashblock sender.

הערות יישום נוכחיות:
- ה-endpoints מובנים בתוך הקוד
- הסקציה הזאת מספקת בעיקר auth וערכי runtime

### `auth`

Type: `string`

Authorization token של Flashblock שנשלח בבקשת ה-HTTP.

### `enabled`

Type: bindable `bool`

מפעיל או מכבה שליחה דרך Flashblock.

### `flashblock_min_tip`

Type: bindable `u64`

Flashblock tip מינימלי ב-raw lamports.

### `flashblock_max_tip`

Type: bindable `u64`

Flashblock tip מקסימלי ב-raw lamports.

### `flashblock_min_prio`

Type: bindable `u64`

Flashblock priority fee מינימלי ב-raw lamports לכל טרנזקציה.

### `flashblock_max_prio`

Type: bindable `u64`

Flashblock priority fee מקסימלי ב-raw lamports לכל טרנזקציה.

### `flashblock_cooldown_ms`

Type: bindable `u64`

Cooldown של Flashblock sender במילישניות.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `320`.

## `[astra_config]`

תצורת Astra sender.

הערות יישום נוכחיות:
- ה-endpoints מובנים בתוך הקוד
- הסקציה הזאת מספקת בעיקר API key וערכי runtime

### `api_key`

Type: `string`

API key שמשמש בעת שליחה אל נקודות הקצה של Astra.

### `enable_astra`

Type: bindable `bool`

מפעיל או מכבה שליחה דרך Astra.

### `enable_astra_min_tip`

Type: bindable `u64`

Astra tip מינימלי ב-raw lamports.

### `enable_astra_max_tip`

Type: bindable `u64`

Astra tip מקסימלי ב-raw lamports.

### `astra_min_prio`

Type: bindable `u64`

Astra priority fee מינימלי ב-raw lamports לכל טרנזקציה.

### `astra_max_prio`

Type: bindable `u64`

Astra priority fee מקסימלי ב-raw lamports לכל טרנזקציה.

### `astralane_cooldown_ms`

Type: bindable `u64`

Cooldown של Astra sender במילישניות.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `300`.

## `[hellomoon_config]`

תצורת HelloMoon sender.

הערות יישום נוכחיות:
- ה-endpoints מובנים בתוך הקוד
- הסקציה הזאת מספקת בעיקר API key וערכי runtime

### `api_key`

Type: `string`

API key שמצורף ל-URLs המובנים של HelloMoon sender.

### `enable_hellomoon`

Type: bindable `bool`

מפעיל או מכבה שליחה דרך HelloMoon.

### `hellomoon_min_tip`

Type: bindable `u64`

HelloMoon tip מינימלי ב-raw lamports.

### `hellomoon_max_tip`

Type: bindable `u64`

HelloMoon tip מקסימלי ב-raw lamports.

### `hellomoon_min_prio`

Type: bindable `u64`

HelloMoon priority fee מינימלי ב-raw lamports לכל טרנזקציה.

### `hellomoon_max_prio`

Type: bindable `u64`

HelloMoon priority fee מקסימלי ב-raw lamports לכל טרנזקציה.

### `hellomoon_cooldown_ms`

Type: bindable `u64`

Cooldown של HelloMoon sender במילישניות.

אם השדה לא מוגדר, ערך ברירת המחדל הנוכחי הוא `300`.

## הערות תפעוליות

### 1. `info_rpc` ו-`rpc_config.endpoint` ממלאים תפקידים שונים

- `info_rpc` הוא ה-read/information RPC הראשי של הבוט
- `rpc_config.endpoint` הוא רשימת ה-endpoints עבור transaction submission RPC fanout

אל תניחו שהם ניתנים להחלפה.

### 2. קובצי הדוגמה החיצוניים הם אופציונליים, אבל הנתיבים חשובים

אם `mpconfig.toml` מצביע אל `config/markets.toml`, `config/lut.txt` ו-`config/gas.json`, הקבצים האלה חייבים להתקיים בזמן הריצה.

### 3. תצורות מבוססות placeholders דורשות `misc`

אם אתם משתמשים בערכים מהצורה `{placeholder}` בכל שדה bindable, המפתח המתאים חייב להתקיים במסמך ה-JSON של `misc`.

### 4. עדכוני `misc` שגויים הם בסיכון גבוה

JSON פגום או ערכים חסרים עלולים לשבור את הבנייה מחדש של תצורת ה-runtime. התייחסו לעריכות של `gas.json` כאל שינויים רגישים תפעולית.

### 5. עדכוני markets ו-LUT משפיעים על live execution

טעינה מחדש של markets או LUT משנה את מה שהבוט מסוגל לבנות ולשלוח. התייחסו לקבצים האלה כאל קלטי מסחר חיים, ולא כאל מטא-דאטה פסיבי.

### 6. נתמכים גם URLs חיצוניים

ניתן להגיש את מקורות `markets`, `lut` ו-`misc` דרך HTTP או HTTPS. זה שימושי אם האוטומציה הקיימת שלכם כבר מפרסמת קובצי תצורה של בוטים מנקודה מרכזית.

## דפוס התחלתי מומלץ

לפריסה תפעולית נקייה:

1. שמרו על `mpconfig.toml` כקובץ סטטי ברובו.
2. שימו ערכי runtime שמשתנים מהר בתוך `gas.json`.
3. שימו שינויים ביקום ה-pools בתוך `markets.toml`.
4. שימו שינויים ב-lookup tables בתוך `lut.txt`.
5. הפעילו `use_external_data = true` אם אתם רוצים live reload behavior.

כך מופרדים credentials, endpoints ו-runtime tuning בצורה שקל יותר לאוטומט וגם בטוח יותר לתפעול.
