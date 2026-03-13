# دليل `mpconfig.toml`

تشرح هذه الوثيقة ملف الإعداد الرئيسي لـ Money Printer وكيف يستخدمه البوت أثناء التشغيل.

استخدمها مع:
- [`../mpconfig.example.toml`](../mpconfig.example.toml)
- [`../config/README.md`](../config/README.md)

## الغرض

يُعد `mpconfig.toml` ملف الإعداد الرئيسي للمشغّل. وهو يحدد:
- موقع المحفظة
- نقاط نهاية information RPC
- قنوات إرسال المعاملات
- بيانات اعتماد الـ sender
- مصادر الإعداد الخارجية
- القيم القابلة للضبط أثناء التشغيل وروابط الـ placeholders

يتم قراءة الملف مرة واحدة عند بدء التشغيل. لا تتم مراقبة تغييرات هذا الملف. إذا قمت بتعديل `mpconfig.toml`، فأعد تشغيل البوت.

## كيف يعثر البوت على ملف الإعداد

يقوم Money Printer بحل مسار ملف الإعداد الرئيسي بالترتيب التالي:

1. متغير البيئة `MP_CONFIG`
2. `--config <path>` أو `-c <path>`
3. `mpconfig.toml` بجوار الملف التنفيذي

مهم:
- يأخذ `MP_CONFIG` أولوية أعلى من معاملات سطر الأوامر.
- إذا لم يتم توفير override، فسيتوقع البوت وجود `mpconfig.toml` في نفس الدليل الذي يوجد فيه الملف الثنائي.

## الحقول الثابتة مقابل الحقول المرتبطة بالـ runtime

يميز الكود بين:
- startup-fixed fields: قيم حرفية تتم قراءتها عند بدء التشغيل ولا يعاد تحميلها عبر hot reload
- bindable fields: قيم يمكن كتابتها حرفيًا أو الإشارة إليها من ملف `misc` بصيغة JSON عبر placeholders مثل `{enable_cu_limit}`

### الحقول الثابتة عند بدء التشغيل

يجب أن تكون هذه الحقول سلاسل أو أرقامًا حرفية داخل `mpconfig.toml`. لا يمكنها استخدام صيغة `{placeholder}`:

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

يتطلب تغيير أي من هذه الحقول تعديل `mpconfig.toml` ثم إعادة تشغيل العملية.

### الحقول القابلة للربط

يمكن كتابة العديد من القيم التشغيلية إما:
- مباشرة، مثل `cu_limit = 350000`
- أو عن طريق الإشارة، مثل `cu_limit = "{enable_cu_limit}"`

عند استخدام صيغة placeholder، يتم حل القيمة من مستند JSON المحمّل من `external_config.misc`.

إذا تم استخدام placeholder وكان ملف JSON مفقودًا أو تالفًا أو لا يحتوي على المفتاح المشار إليه، فسيفشل حل الإعداد.

## ربط الـ placeholders

صيغة placeholder هي:

```toml
cu_limit = "{enable_cu_limit}"
```

ملف JSON المطابق:

```json
{
  "enable_cu_limit": 350000
}
```

ملاحظات:
- أسماء الـ placeholders حساسة لحالة الأحرف
- تعمل الـ placeholders فقط في الحقول المطبقة كـ bindable values
- يجب أن تتطابق الأنواع مع نوع الحقل الهدف
- يحدث حل الـ placeholders عند بناء إعداد الـ runtime أو إعادة بنائه من `misc`

## الإعداد الخارجي و hot reload

يدعم Money Printer ثلاثة مصادر خارجية:
- ملف markets
- ملف LUT
- ملف JSON باسم misc

يتم إعداد هذه المصادر تحت `[external_config]`.

### عندما تكون `use_external_data = true`

يقوم البوت بعمل polling للمصادر الخارجية المهيأة ويعيد تحميلها أثناء التشغيل.

السلوك الحالي:
- يتم دعم مسارات الملفات المحلية وروابط `http://` و `https://`
- يكون interval الخاص بالـ polling هو `external_config.poll_interval_ms`
- لا يتم تطبيق التغيير إلا بعد رؤية نفس المحتوى مرتين متتاليتين
  يعمل ذلك كـ debounce صغير ويساعد على تجنب القراءة أثناء الكتابة الجزئية

سلوك إعادة التحميل حسب نوع الملف:
- `markets`: يتم إعادة تحميل universe الخاص بالأسواق وإعادة بناء قاعدة بيانات الـ pools
- `lut`: يتم إعادة تحميل lookup tables وتحديث LUT cache الخاص بالمعاملات
- `misc`: يتم حل قيم الـ runtime مرة أخرى ونشرها دون إعادة تشغيل البوت

لا تتم إعادة تحميل ملف `mpconfig.toml` الرئيسي.

### عندما تكون `use_external_data = false`

لا يراقب البوت الملفات الخارجية، لكن قد تظل بعض المسارات مستخدمة كمصادر لمرة واحدة أثناء بدء التشغيل.

سلوك بدء التشغيل الحالي:
- يتم تفضيل `local_config.markets` و `local_config.lut` للتحميل لمرة واحدة عند بدء التشغيل
- إذا لم يكن `local_config` موجودًا، فلا يزال من الممكن استخدام `external_config.markets` و `external_config.lut` كمدخلات لمرة واحدة عند بدء التشغيل
- قد يستمر قراءة `external_config.misc` مرة واحدة عند بدء التشغيل لحل الـ placeholders

وهذا يعني أن `external_config.misc` يبقى مهمًا حتى في الوضع غير المراقَب إذا كان إعدادك يستخدم قيمًا من الشكل `{placeholder}`.

## اتفاقيات القيم العامة

- يتم تحديد قيم tip بوحدة raw lamports
- يتم أيضًا تحديد نطاقات priority fee بوحدة raw lamports لكل معاملة
- داخليًا، يتم تحويل priority fees إلى قيم سعر compute-budget
- يتم تحديد قيم cooldown بالمللي ثانية
- قوائم الـ endpoints هي URLs حرفية

## الحقول ذات المستوى الأعلى

### `use_external_data`

Type: `bool`

يتحكم هذا الحقل فيما إذا كانت المصادر الخارجية المهيأة ستتم مراقبتها وإعادة تحميلها أثناء التشغيل.

موصى به:
- `true` إذا كنت تريد hot reload لقوائم markets و LUT وقيم الضبط أثناء التشغيل
- `false` إذا كنت تريد إعدادًا ثابتًا وقت البدء فقط

### `base_token`

Type: `string`

الـ mint الأساسي للتداول. عمليًا، يتمحور الكود الحالي وملف المثال حول WSOL.

مثال:

```toml
base_token = "So11111111111111111111111111111111111111112"
```

### `info_rpc`

Type: `string`

نقطة information RPC الأساسية المستخدمة من أجل:
- قراءة accounts
- تحميل markets
- جلب recent blockhash
- استعلامات المعلومات الأخرى غير المتعلقة بالإرسال

عادةً، ينبغي أن يكون هذا أفضل endpoint مخصص للقراءة لديك.

### `info_rpc_fallback`

Type: `string`, optional

fallback اختياري لـ information RPC.

السلوك الحالي:
- بعد 3 حالات فشل متتالية على الـ endpoint الأساسي
- يتحول البوت إلى fallback لمدة 30 ثانية
- بمجرد تعافي الأساسي، يعود البوت إليه

هذا خاص بمسار information RPC فقط، وليس fanout الخاص بإرسال المعاملات.

### `recent_block_hash_refresh_interval`

Type: `u64`, optional

إعداد متقدم لمعدل تحديث الـ blockhash بالمللي ثانية.

إذا تم حذف هذا الحقل، فسيعود الكود الحالي إلى القيمة `400`.

### `enable_flash`

Type: bindable `bool`

يتحكم فيما إذا كان البوت يبني تعليمات تداول مفعلة بـ flash-loan.

يمكن أن تكون هذه القيمة:
- حرفية داخل `mpconfig.toml`
- أو مرتبطة عبر placeholder من `misc`

### `cu_limit`

Type: bindable `u64`

الحد العام لـ compute units المستخدم عند بناء المعاملات.

عادةً ما يتم ضبط هذا الإعداد عبر `misc` لكي يمكن تغييره دون إعادة كتابة ملف الإعداد الرئيسي.

## `[network]`

هذا القسم اختياري وغير موجود في ملف المثال.

### `account_refresh_interval`

Type: `u64`

فاصل polling بالمللي ثانية لتحديث accounts في الـ pool updater.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `2000`.

استخدم قيمًا أقل فقط إذا كانت بنيتك التحتية تستطيع تحمل ذلك.

## `[key_pair]`

إعداد المحفظة.

### `path_to_secret`

Type: `string`

مسار مطلق أو نسبي إلى ملف Solana keypair المستخدم لتوقيع المعاملات.

الصيغة المتوقعة:
- JSON array keypair file

هذه القيمة ثابتة عند بدء التشغيل ولا يمكن ربطها بـ placeholder.

## `[external_config]`

مصادر خارجية لـ markets و LUT والقيم القابلة للضبط أثناء التشغيل.

### `markets`

Type: `string`, optional

مسار أو URL إلى ملف markets.

الصيغة:
- TOML
- مجموعات تحت `[[group]]`
- تحتوي كل مجموعة على قائمة `markets = [ ... ]` من عناوين الـ pools

### `lut`

Type: `string`, optional

مسار أو URL إلى ملف lookup table.

الصيغة:
- plain text
- عنوان LUT واحد في كل سطر

### `misc`

Type: `string`, optional

مسار أو URL إلى ملف JSON يحتوي على القيم القابلة للضبط أثناء التشغيل والتي تشير إليها الـ placeholders.

الصيغة:
- JSON object

هذا الملف هو مصدر القيم مثل:
- `enable_cu_limit`
- `enable_min_prio`
- `enable_jito`
- `helius_min_tip`
- ومفاتيح runtime أخرى قابلة للضبط

### `poll_interval_ms`

Type: `u64`

فاصل polling للمصادر الخارجية التي تتم مراقبتها عندما تكون `use_external_data = true`.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `100`.

## `[local_config]`

قسم اختياري متقدم.

هذا القسم غير موجود في ملف المثال، لكن الكود الحالي يدعمه.

الغرض:
- تحميل ملفات markets و LUT مرة واحدة عند بدء التشغيل عندما تكون `use_external_data = false`

الحقول:
- `markets`
- `lut`

الأولوية الحالية في الوضع غير المراقَب:
1. `local_config.*`
2. `external_config.*`

وعلى خلاف `[external_config]`، لا يتضمن هذا القسم `misc`.

## `[rpc_config]`

إعداد standard RPC send path.

استخدم هذا القسم من أجل RPC transaction fanout العادي.

### `endpoint`

Type: `array<string>`

قائمة RPC endpoints المستخدمة لإرسال المعاملات.

عادةً ما تكون هناك حاجة إلى endpoint واحد على الأقل إذا كنت تريد تفعيل إرسال RPC.

### `auth`

Type: `string`

authentication token اختياري يستخدمه RPC sender إذا كان مطلوبًا في إعدادك.

إذا كان مزود RPC لديك يطبق authentication بالفعل عبر الـ URL، فيمكن ترك هذا الحقل فارغًا.

### `enabled`

Type: bindable `bool`

يُفعّل أو يُعطّل RPC submission fanout.

### `priority_lamports_from`

Type: bindable `u64`

الحد الأدنى لـ priority fee لكل معاملة، معبرًا عنه بوحدة raw lamports.

### `priority_lamports_to`

Type: bindable `u64`

الحد الأقصى لـ priority fee لكل معاملة، معبرًا عنه بوحدة raw lamports.

### `cool_down`

Type: bindable `u64`

الـ cooldown بين دورات إرسال RPC، بالمللي ثانية.

### `retries`

Type: `u64`

قيمة maximum retries التي تمرر إلى `sendTransaction` القياسي الخاص بـ RPC.

هذا إعداد خاص بـ RPC sender. وهو لا يتحكم في relay senders مثل Jito أو Flashblock.

### Networking Fields

هذه حقول رقمية حرفية:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

وهي تتحكم في سلوك HTTP client الخاص بـ RPC sender القياسي.

## `[jito_config]`

إعداد إرسال المعاملات عبر Jito.

### `endpoint`

Type: `array<string>`

قائمة Jito transaction endpoints.

وعلى خلاف Helius و Astra و Flashblock و Temporal و HelloMoon، يتم إعداد Jito endpoints مباشرة داخل `mpconfig.toml`.

### `auth`

Type: `string`, optional

authentication token اختياري لـ Jito.

### `enabled`

Type: bindable `bool`

يُفعّل أو يُعطّل الإرسال عبر Jito.

### `tip_lamports_from`

Type: bindable `u64`

الحد الأدنى لـ Jito tip بوحدة raw lamports.

### `tip_lamports_to`

Type: bindable `u64`

الحد الأقصى لـ Jito tip بوحدة raw lamports.

### `jito_min_prio`

Type: bindable `u64`

الحد الأدنى لـ priority fee لكل معاملة لمسار Jito.

### `jito_max_prio`

Type: bindable `u64`

الحد الأقصى لـ priority fee لكل معاملة لمسار Jito.

### `jito_cooldown_ms`

Type: bindable `u64`

الـ cooldown الخاص بـ Jito sender بالمللي ثانية.

### Networking Fields

قيم رقمية حرفية:
- `pool_max_idle_per_host`
- `pool_idle_timeout_ms`
- `tcp_keepalive_secs`
- `timeout_ms`
- `connect_timeout_ms`

هذه إعدادات HTTP client خاصة بـ Jito.

## `[helius_config]`

إعداد Helius fast sender.

ملاحظات التنفيذ الحالية:
- الـ endpoints مدمجة داخل الكود
- يوفّر هذا القسم أساسًا API key وقيم runtime قابلة للضبط

### `api_key`

Type: `string`

API key الذي يتم إلحاقه بروابط Helius sender المدمجة.

### `enabled`

Type: bindable `bool`

يُفعّل أو يُعطّل Helius fast sender.

### `helius_min_tip`

Type: bindable `u64`

الحد الأدنى لـ Helius tip بوحدة raw lamports.

### `helius_max_tip`

Type: bindable `u64`

الحد الأقصى لـ Helius tip بوحدة raw lamports.

### `helius_min_prio`

Type: bindable `u64`

الحد الأدنى لـ Helius priority fee بوحدة raw lamports لكل معاملة.

### `helius_max_prio`

Type: bindable `u64`

الحد الأقصى لـ Helius priority fee بوحدة raw lamports لكل معاملة.

### `helius_cooldown_ms`

Type: bindable `u64`

الـ cooldown الخاص بـ Helius sender بالمللي ثانية.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `250`.

## `[helius_swqos_config]`

إعداد Helius SWQoS sender.

ملاحظات التنفيذ الحالية:
- يستخدم نفس عائلة الـ endpoints المدمجة الخاصة بـ Helius
- يرث سلوك الـ API key من `[helius_config]`
- يضيف `swqos_only=true` في طبقة الـ sender

### `enabled`

Type: bindable `bool`

يُفعّل أو يُعطّل Helius SWQoS sender.

### `helius_swqos_min_tip`

Type: bindable `u64`

الحد الأدنى لـ SWQoS tip بوحدة raw lamports.

### `helius_swqos_max_tip`

Type: bindable `u64`

الحد الأقصى لـ SWQoS tip بوحدة raw lamports.

### `helius_swqos_min_prio`

Type: bindable `u64`

الحد الأدنى لـ SWQoS priority fee بوحدة raw lamports لكل معاملة.

### `helius_swqos_max_prio`

Type: bindable `u64`

الحد الأقصى لـ SWQoS priority fee بوحدة raw lamports لكل معاملة.

### `helius_swqos_cooldown_ms`

Type: bindable `u64`

الـ cooldown الخاص بـ SWQoS sender بالمللي ثانية.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `300`.

## `[temporal_config]`

إعداد Temporal / Nozomi sender.

ملاحظات التنفيذ الحالية:
- الـ endpoints مدمجة داخل الكود
- يوفّر هذا القسم أساسًا `client_id` وقيم runtime قابلة للضبط

### `client_id`

Type: `string`

معرّف عميل اختياري يتم إلحاقه بروابط Temporal sender المدمجة.

### `enabled`

Type: bindable `bool`

يُفعّل أو يُعطّل الإرسال عبر Temporal.

### `temporal_min_tip`

Type: bindable `u64`

الحد الأدنى لـ Temporal tip بوحدة raw lamports.

### `temporal_max_tip`

Type: bindable `u64`

الحد الأقصى لـ Temporal tip بوحدة raw lamports.

### `temporal_min_prio`

Type: bindable `u64`

الحد الأدنى لـ Temporal priority fee بوحدة raw lamports لكل معاملة.

### `temporal_max_prio`

Type: bindable `u64`

الحد الأقصى لـ Temporal priority fee بوحدة raw lamports لكل معاملة.

### `temporal_cooldown_ms`

Type: bindable `u64`

الـ cooldown الخاص بـ Temporal sender بالمللي ثانية.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `300`.

## `[flashblock_config]`

إعداد Flashblock sender.

ملاحظات التنفيذ الحالية:
- الـ endpoints مدمجة داخل الكود
- يوفّر هذا القسم أساسًا auth وقيم runtime قابلة للضبط

### `auth`

Type: `string`

رمز Authorization الخاص بـ Flashblock والذي يُرسل في طلب HTTP.

### `enabled`

Type: bindable `bool`

يُفعّل أو يُعطّل الإرسال عبر Flashblock.

### `flashblock_min_tip`

Type: bindable `u64`

الحد الأدنى لـ Flashblock tip بوحدة raw lamports.

### `flashblock_max_tip`

Type: bindable `u64`

الحد الأقصى لـ Flashblock tip بوحدة raw lamports.

### `flashblock_min_prio`

Type: bindable `u64`

الحد الأدنى لـ Flashblock priority fee بوحدة raw lamports لكل معاملة.

### `flashblock_max_prio`

Type: bindable `u64`

الحد الأقصى لـ Flashblock priority fee بوحدة raw lamports لكل معاملة.

### `flashblock_cooldown_ms`

Type: bindable `u64`

الـ cooldown الخاص بـ Flashblock sender بالمللي ثانية.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `320`.

## `[astra_config]`

إعداد Astra sender.

ملاحظات التنفيذ الحالية:
- الـ endpoints مدمجة داخل الكود
- يوفّر هذا القسم أساسًا API key وقيم runtime قابلة للضبط

### `api_key`

Type: `string`

API key المستخدم عند الإرسال إلى endpoints الخاصة بـ Astra.

### `enable_astra`

Type: bindable `bool`

يُفعّل أو يُعطّل الإرسال عبر Astra.

### `enable_astra_min_tip`

Type: bindable `u64`

الحد الأدنى لـ Astra tip بوحدة raw lamports.

### `enable_astra_max_tip`

Type: bindable `u64`

الحد الأقصى لـ Astra tip بوحدة raw lamports.

### `astra_min_prio`

Type: bindable `u64`

الحد الأدنى لـ Astra priority fee بوحدة raw lamports لكل معاملة.

### `astra_max_prio`

Type: bindable `u64`

الحد الأقصى لـ Astra priority fee بوحدة raw lamports لكل معاملة.

### `astralane_cooldown_ms`

Type: bindable `u64`

الـ cooldown الخاص بـ Astra sender بالمللي ثانية.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `300`.

## `[hellomoon_config]`

إعداد HelloMoon sender.

ملاحظات التنفيذ الحالية:
- الـ endpoints مدمجة داخل الكود
- يوفّر هذا القسم أساسًا API key وقيم runtime قابلة للضبط

### `api_key`

Type: `string`

API key الذي يتم إلحاقه بروابط HelloMoon sender المدمجة.

### `enable_hellomoon`

Type: bindable `bool`

يُفعّل أو يُعطّل الإرسال عبر HelloMoon.

### `hellomoon_min_tip`

Type: bindable `u64`

الحد الأدنى لـ HelloMoon tip بوحدة raw lamports.

### `hellomoon_max_tip`

Type: bindable `u64`

الحد الأقصى لـ HelloMoon tip بوحدة raw lamports.

### `hellomoon_min_prio`

Type: bindable `u64`

الحد الأدنى لـ HelloMoon priority fee بوحدة raw lamports لكل معاملة.

### `hellomoon_max_prio`

Type: bindable `u64`

الحد الأقصى لـ HelloMoon priority fee بوحدة raw lamports لكل معاملة.

### `hellomoon_cooldown_ms`

Type: bindable `u64`

الـ cooldown الخاص بـ HelloMoon sender بالمللي ثانية.

إذا تم حذف هذا الحقل، فقيمته الافتراضية الحالية هي `300`.

## ملاحظات تشغيلية

### 1. يلعب `info_rpc` و `rpc_config.endpoint` دورين مختلفين

- `info_rpc` هو read/information RPC الرئيسي للبوت
- `rpc_config.endpoint` هي قائمة endpoints الخاصة بـ transaction submission RPC fanout

لا تفترض أنهما قابلان للاستبدال.

### 2. ملفات الأمثلة الخارجية اختيارية، لكن المسارات مهمة

إذا كان `mpconfig.toml` يشير إلى `config/markets.toml` و `config/lut.txt` و `config/gas.json`، فيجب أن تكون هذه الملفات موجودة أثناء التشغيل.

### 3. الإعدادات المعتمدة على placeholders تتطلب `misc`

إذا كنت تستخدم قيمًا من الشكل `{placeholder}` في أي من الحقول القابلة للربط، فيجب أن يكون المفتاح المشار إليه موجودًا في مستند JSON الخاص بـ `misc`.

### 4. تحديثات `misc` السيئة عالية الخطورة

يمكن أن يؤدي JSON غير صالح أو القيم المرجعية المفقودة إلى كسر إعادة بناء إعداد الـ runtime. تعامل مع تعديلات `gas.json` على أنها حساسة تشغيليًا.

### 5. تؤثر تحديثات markets و LUT على live execution

تؤدي إعادة تحميل markets أو LUT إلى تغيير ما يمكن للبوت بناؤه وإرساله. تعامل مع هذه الملفات على أنها مدخلات تداول حية وليست metadata سلبية.

### 6. الروابط الخارجية مدعومة

يمكن تقديم مصادر `markets` و `lut` و `misc` عبر HTTP أو HTTPS. يكون هذا مفيدًا إذا كانت الأتمتة الموجودة لديك تنشر بالفعل ملفات إعداد البوت من نقطة مركزية.

## نمط البداية الموصى به

من أجل تخطيط تشغيلي نظيف:

1. أبقِ `mpconfig.toml` ثابتًا إلى حد كبير.
2. ضع قيم الـ runtime سريعة التغير داخل `gas.json`.
3. ضع تغييرات universe الخاص بالـ pools داخل `markets.toml`.
4. ضع تغييرات lookup table داخل `lut.txt`.
5. فعّل `use_external_data = true` إذا كنت تريد live reload behavior.

بهذه الطريقة يتم فصل credentials والـ endpoints وضبط الـ runtime بطريقة يسهل أتمتتها وتكون أكثر أمانًا من الناحية التشغيلية.
