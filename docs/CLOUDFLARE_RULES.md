# قواعد Cloudflare لتحمل ayattla.com (المجانية)

آخر تحديث: 10 نوفمبر 2026. تُنفذ بموافقة المالك فقط، من لوحة Cloudflare. لا تعديل على الخادم نفسه.

## الوضع الحالي (قيس في 10 نوفمبر من متصفح المالك)

| الفحص | النتيجة |
|---|---|
| هل النطاق يمر عبر Cloudflare؟ | نعم (`server: cloudflare`، ترويسة `cf-ray` موجودة) |
| الضغط | يعمل (`content-encoding: br`) |
| `/api/radios` | الخادم يرسل `Cache-Control: public, max-age=3600`، لكن Cloudflare لا يخزنها (`cf-cache-status: DYNAMIC`) |
| `/api/hadith/browse` | الخادم يرسل `no-store`، وCloudflare لا يخزنها (`DYNAMIC`) |

المعنى: Cloudflare أمام الموقع ويضغط الردود، لكن كل طلب للواجهات ما زال يصل الخادم، لأن Cloudflare لا يخزن JSON إلا بقاعدة صريحة. القاعدتان التاليتان تغلقان هذه الفجوة دون لمس الخادم.

## القاعدة ١: تخزين واجهات القراءة (Caching ← Cache Rules ← Create rule)

- الاسم: `app-read-apis`
- الشرط (Custom filter expression):
  ```
  (http.host eq "ayattla.com" and http.request.method eq "GET" and (http.request.uri.path eq "/api/radios" or http.request.uri.path eq "/api/hadith/browse"))
  ```
- Cache eligibility: **Eligible for cache**
- Edge TTL: **Ignore cache-control header and use this TTL** = ساعتان، وهو أقل مدة تسمح بها الخطة المجانية (التجاوز لازم لأن `/api/hadith/browse` ترسل `no-store`)
- Browser TTL: **Override origin** = ٥ دقائق
- Cache key: اترك الإعداد الافتراضي (يشمل نص الاستعلام، فكل قسم وصفحة وبحث يخزن وحده)

الأثر: ألف مستخدم يفتحون الصفحة نفسها خلال ساعتين = طلب واحد يصل الخادم. وعند تحديث الأحاديث يظهر الجديد خلال ساعتين على الأكثر (أو فورا بـ Caching ← Configuration ← Purge Everything).

لا تضف `/api/hadith/check` (POST وخاص بكل مستخدم) ولا `/api/media/` في هذه القاعدة.

## القاعدة ٢: حد الطلبات لفاحص الحديث (Security ← WAF ← Rate limiting rules)

الخطة المجانية تسمح بقاعدة واحدة، بفترة ١٠ ثوان.

- الاسم: `hadith-check-limit`
- الشرط: `(http.request.uri.path eq "/api/hadith/check")`
- العد حسب: IP
- الحد: ٥ طلبات كل ١٠ ثوان
- الإجراء: Block لمدة ١٠ ثوان

الأثر: المستخدم العادي لا يبلغ الحد أبدا؛ سكربت يغرق أثقل مسار يوقف عند Cloudflare قبل الخادم. التطبيق يتعامل مع 429 بإعادة محاولة واحدة ثم رسالة.

## التحقق بعد التنفيذ

افتح `https://ayattla.com/api/hadith/browse` مرتين؛ في المرة الثانية يجب أن تكون الترويسة `cf-cache-status: HIT`. ثم افتح الموقع وأداة الحديث وتأكد أنهما كما كانا.

## التراجع

عطّل القاعدة من مفتاحها في القائمة (لا يلزم حذفها)؛ الأثر فوري.

## بعدها

- `tools/server/inspect.sh`: نظرة للقراءة فقط على الخادم (الأنوية، الذاكرة، عدد عمال Uvicorn، إعدادات nginx) لتحديد هل يلزم تعديل في الخادم أصلا.
- `tools/loadtest/hadith-browse.js`: اختبار الحمل (k6) بـ ٥٠ ثم ١٠٠ ثم ٢٠٠ مستخدم، قبل القاعدتين وبعدهما.
