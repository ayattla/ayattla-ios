# FEATURE_PARITY_MATRIX — مطابقة الموقع ↔ تطبيق iOS

الحالة لكل صف: **التحليل** ✔ = موثق في `WEBSITE_FEATURES_AUDIT.md` وعناصر تحكمه في `WEBSITE_TOOLS_WALKTHROUGH.md`. **التصميم** ✔ = له لوحة في `design/`. **البرمجة** ✔ = مبني وناجح على CI (macOS، المحاكي). **الاختبار** = اختبارات وحدة على بيانات الموقع الذهبية ولقطة محاكي على الفرع `ci-shots`. تُحدّث الأعمدة في كل جلسة.

PHASE 1 مغلقة اعتمادا على `WEBSITE_TOOLS_WALKTHROUGH.md` (جرد عناصر التحكم في 30 أداة ومحرر الحالات من الصفحات الحية) بقرار المالك في 2 نوفمبر 2026. ما لم يُجرب يدويا من تركيبات الخيارات يُتحقق منه عند برمجة كل أداة بمقارنة سلوكها بالموقع.

| الأداة في الموقع | الوحدة في التطبيق | التقنية الأصلية المقترحة | الصعوبة | التحليل | التصميم | البرمجة | الاختبار |
|---|---|---|---|---|---|---|---|
| صانع المقاطع القرآنية | Studio › VideoComposer | AVFoundation (AVMutableComposition + AVVideoCompositionCoreAnimationTool) + CoreText للنص العثماني | عالية جدا | ✔ | ✔ `design/Studio.dc.html` | — | — |
| محرر حالات واتساب (صورة، فيديو بالتلاوة، نص متحرك) | Studio › StatusEditor | نفس محرك الفيديو + Canvas بـ CoreGraphics | عالية | ✔ | ✔ `design/Status.dc.html` | — | — |
| معرض الحالات الجاهزة | Studio › Templates | قوالب JSON محلية | منخفضة | ✔ | — | — | — |
| صفحات الآيات حسب الموضوع | Quran › Topics | — | منخفضة | ✔ | — | — | — |
| صفحات السور | Quran › SurahInfo | — | منخفضة | ✔ | — | — | — |
| صفحة لكل آية | Quran › AyahDetail | — | منخفضة | ✔ | — | — | — |
| صفحات القراء | Listen › Reciters | — | منخفضة | ✔ | — | — | — |
| صفحات المواسم (رمضان، العيد...) | Home › Seasonal | محتوى موسمي | منخفضة | ✔ | — | — | — |
| المدونة (WordPress) | (خارج نطاق v1) رابط خارجي أو قارئ مقالات أصلي عبر REST | WP REST API | تُقرر | ✔ | — | — | — |
| صانع بطاقات الآيات | Studio › CardDesigner | ImageRenderer / CoreGraphics، تصدير PNG | متوسطة | ✔ | ✔ `design/Card.dc.html` | — | — |
| المصحف المسموع والتحفيظ | Quran › Player | AVQueuePlayer + تنزيل خلفي URLSession | متوسطة | ✔ | — | — | — |
| البحث في القرآن | Quran › Search | فهرس نصي محلي (SQLite FTS5) | متوسطة | ✔ | — | — | — |
| آيات بالموضوع | Quran › Topics | بيانات محلية | منخفضة | ✔ | — | — | — |
| آياتي المحفوظة | Library › Favorites | SwiftData | منخفضة | ✔ | ✔ `design/Library.dc.html` | — | — |
| آية اليوم | Home + Widget | WidgetKit | منخفضة | ✔ | ✔ `design/Main.dc.html` | — | — |
| الأذكار | Tools › Azkar | JSON محلي + صوت حصن المسلم + إشعارات | منخفضة | ✔ | ✔ `design/Azkar.dc.html` | — | — |
| إذاعات القرآن | Listen › Radio | AVPlayer للبث + Now Playing | منخفضة | ✔ | — | — | — |
| مواقيت الصلاة | Tools › PrayerTimes | حساب فلكي محلي (Adhan-Swift أو تنفيذ مطابق) + CoreLocation | متوسطة | ✔ | ✔ `design/Prayer.dc.html` | ✔ PR #1 | ✔ وحدة + لقطة |
| اتجاه القبلة | Tools › Qibla | CoreLocation heading | منخفضة | ✔ | ✔ `design/Qibla.dc.html` | ✔ PR #1 | ✔ وحدة + لقطة |
| خطة ختم القرآن | Memorize › KhatmaPlan | بيانات صفحات محلية + إشعارات | منخفضة | ✔ | ✔ `design/Khatma.dc.html` | — | — |
| التاريخ الهجري | Tools › Hijri | Calendar(identifier: .islamicUmmAlQura) | منخفضة | ✔ | — | ✔ PR #2 | ✔ وحدة + لقطة |
| المناسبات الإسلامية | Tools › Occasions | Calendar islamicUmmAlQura | منخفضة | ✔ | — | ✔ PR #2 | ✔ وحدة + لقطة |
| حاسبة الزكاة | Tools › Zakat | منطق محلي | منخفضة | ✔ | ✔ `design/Zakat.dc.html` | ✔ | ✔ وحدة + لقطة |
| المسبحة الإلكترونية | Tools › Tasbih | SwiftData + Haptics | منخفضة | ✔ | ✔ `design/Tasbih.dc.html` | — | — |
| بطاقات الأحاديث الصحيحة | Studio › HadithCard | ImageRenderer + قاعدة أحاديث محلية | متوسطة | ✔ | — | — | — |
| المصحف الملون بالتجويد | Quran › Tajweed | AttributedString ملون من وسوم التجويد (تخزين ≤ أسبوع) | متوسطة | ✔ | — | — | — |
| معاني الكلمات | Quran › WordByWord | بيانات Quran.com مع سياسة تخزين | متوسطة | ✔ | — | — | — |
| اختبار الحفظ | Memorize › Test | منطق محلي | منخفضة | ✔ | — | — | — |
| أدعية من القرآن والسنة | Tools › Duas | بيانات محلية | منخفضة | ✔ | — | — | — |
| المصحف بالصفحات | Quran › Mushaf | صفحات 604 من نص محلي + CoreText | عالية | ✔ | ✔ `design/Quran.dc.html` | — | — |
| الرقية الشرعية | Quran › Ruqya | قائمة تشغيل متتابعة | منخفضة | ✔ | — | — | — |
| أسماء الله الحسنى | Studio › AsmaCards | ImageRenderer | منخفضة | ✔ | — | — | — |
| الأحاديث النبوية حسب الموضوع | Hadith › Browse | قاعدة أحاديث محلية من الخادم | متوسطة | ✔ | — | — | — |
| التحقق من حديث | Hadith › Checker | مطابقة نصية محلية | متوسطة | ✔ | — | — | — |
| صفة الوضوء والصلاة | Learn › PrayerGuide | محتوى محلي موثق | منخفضة | ✔ | — | — | — |
| تحفيظ الأطفال جزء عم | Learn › KidsJuzAmma | مشغل + نجوم + شهادة PDF/صورة | متوسطة | ✔ | — | — | — |
| الختمة الجماعية | Memorize › GroupKhatma | API الخادم الحالية `/api/khatma` (بعد توثيقها) | متوسطة | ✔ | — | — | — |
| متتبع قضاء الصلوات | Tools › QadaTracker | SwiftData | منخفضة | ✔ | — | — | — |
| متتبع الصيام | Tools › SawmTracker | SwiftData + تقويمان | منخفضة | ✔ | — | — | — |
| المساجد القريبة | Tools › NearbyMosques | MapKit (MKLocalSearch) أو API الخادم | منخفضة | ✔ | — | — | — |

## خصائص عرضية يجب أن تطابق في كل المحررات

| الخاصية | الموقع | التطبيق |
|---|---|---|
| المقاسات | 9:16، 4:5، 1:1، 16:9 بدقة 1080 | نفسها + معاينة حية |
| تظليل الكلمات | توقيتات Quran.com لـ 11 قارئا فقط | نفس القيد: لا تظليل بلا توقيت موثق |
| حجم الخط | 0.85 / 1.0 / 1.15 | نفسها |
| ألوان التظليل | ذهبي، أخضر، سماوي | نفسها |
| الإهداء | 5 قوالب + نص حر 70 حرفا + اسم 40 حرفا | نفسها |
| الخلفيات | Pixabay (صور/فيديو) + مدمجة + الجهاز | نفسها؛ مفتاح Pixabay عبر الخادم لا داخل التطبيق |
| اسم المصور | لا يظهر (قرار المالك) | لا يظهر؛ يبقى «من Pixabay» في نافذة البحث (شرط الواجهة) |
| التصدير | MP4 30fps، PNG/JPG | نفسها + الحفظ في الصور بإذن |