# قواعد Cloudflare لتحمل ayattla.com (المجانية)

آخر تحديث: 10 نوفمبر 2026. **القاعدة منفذة ومتحقق منها (10 نوفمبر، بطلب المالك، من لوحة Cloudflare في متصفحه).** لا تعديل على الخادم نفسه. أي تغيير آخر في Cloudflare بموافقة المالك فقط.

## الوضع الحالي (قيس في 10 نوفمبر من متصفح المالك)

| الفحص | النتيجة |
|---|---|
| هل النطاق يمر عبر Cloudflare؟ | نعم (`server: cloudflare`، ترويسة `cf-ray` موجودة) |
| الضغط | يعمل (`content-encoding: br`) |
| `/api/radios` | الخادم يرسل `Cache-Control: public, max-age=3600`، لكن Cloudflare لا يخزنها (`cf-cache-status: DYNAMIC`) |
| `/api/hadith/browse` | الخادم يرسل `no-store`، وCloudflare لا يخزنها (`DYNAMIC`) |

### القواعد الموجودة في اللوحة (قرئت دون تعديل)

Cache Rules (٣ نشطة):

| الترتيب | الاسم | الأثر |
|---|---|---|
| ١ | Bypass dynamic (pub, api, media, wp-admin) | يمنع تخزين كل ما يبدأ بـ `/api/`؛ هذا سبب `DYNAMIC` |
| ٢ | Cache Quran pages 4h | يخزن صفحات `/ayah/` وما معها |
| ٣ | Cache share images 30d | يخزن صور `/og/` |

Rate limiting (١ من ١، الخانة المجانية مستعملة): `Limit API and login floods` على `/api/` و`/pub/login`: ٤٠ طلبا كل ١٠ ثوان لكل عنوان، ثم حظر ١٠ ثوان. **كافية كما هي؛ لا تغيير.** وحد التطبيق (٤ اتصالات لكل خادم) يبقي المستخدم العادي بعيدا عنها.

المعنى: Cloudflare أمام الموقع ويضغط الردود ويحد الطلبات، لكن القاعدة ١ تجعل كل طلب للواجهات يصل الخادم. المطلوب قاعدة واحدة فقط تستثني واجهتي القراءة العامتين.

## القاعدة المنفذة (الترتيب ٤): تخزين واجهتي القراءة (Caching ← Cache Rules ← Create rule)

- الاسم: `Cache app read APIs 2h`
- الشرط (Custom filter expression):
  ```
  (http.host eq "ayattla.com" and http.request.method eq "GET" and (http.request.uri.path eq "/api/radios" or http.request.uri.path eq "/api/hadith/browse"))
  ```
- Cache eligibility: **Eligible for cache**
- Edge TTL: **Ignore cache-control header and use this TTL** = ساعتان، وهو أقل مدة تسمح بها الخطة المجانية (التجاوز لازم لأن `/api/hadith/browse` ترسل `no-store`)
- Browser TTL: **Override origin** = ٥ دقائق
- Cache key: الإعداد الافتراضي (يشمل نص الاستعلام، فكل قسم وصفحة وبحث يخزن وحده)
- **الترتيب: الأخير (٤)، بعد قاعدة Bypass.** في قواعد التخزين تغلب آخر قاعدة مطابقة، فهذه تستثني المسارين فقط وتبقى بقية `/api/` بلا تخزين كما هي.

الأثر: ألف مستخدم يفتحون الصفحة نفسها خلال ساعتين = طلب واحد يصل الخادم. وعند تحديث الأحاديث يظهر الجديد خلال ساعتين على الأكثر (أو فورا بـ Caching ← Configuration ← Purge Everything).

لا تضف `/api/hadith/check` (POST وخاص بكل مستخدم) ولا `/api/media/` ولا `/pub/`.

## التحقق (أجري بعد التنفيذ مباشرة)

| الطلب | الأول | الثاني |
|---|---|---|
| `/api/hadith/browse` | MISS | HIT |
| `/api/hadith/browse?cat=&page=2&q=` | MISS | HIT (محتوى مختلف عن الصفحة الأولى، فكل صفحة تخزن وحدها) |
| `/api/radios` | HIT | HIT |
| الصفحة الرئيسية `/` | DYNAMIC | DYNAMIC (لم تتأثر) |

كل الردود 200.

## التراجع

عطّل القاعدة من مفتاحها في القائمة (لا يلزم حذفها)؛ الأثر فوري.

## بعدها

- `tools/server/inspect.sh`: نظرة للقراءة فقط على الخادم (الأنوية، الذاكرة، عدد عمال Uvicorn، إعدادات nginx) لتحديد هل يلزم تعديل في الخادم أصلا.
- `tools/loadtest/hadith-browse.js`: اختبار الحمل (k6) بـ ٥٠ ثم ١٠٠ ثم ٢٠٠ مستخدم، انظر الملاحظة في خطة التحمل §٤: حد الطلبات (٤٠ كل ١٠ ثوان لكل عنوان) يحظر اختبارا من عنوان واحد، والمساران صارا يخدمان من Cloudflare.
