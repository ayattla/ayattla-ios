# TECHNICAL_AUDIT — البنية التقنية للموقع وما يُنقل إلى iOS

تاريخ اللقطة: 2 نوفمبر 2026.

## 1. بنية الموقع الحالية

| الطبقة | التقنية | الملفات الرئيسية |
|---|---|---|
| الخادم | Python 3.12 + FastAPI + Uvicorn على Hostinger VPS (Ubuntu) خلف Nginx وCloudflare | `app.py` (المحرك والواجهات)، `media_broker.py`، `new_tools_api.py`، `tools_extra_api.py`، `status_pages.py`، `azkar_audio.py`، `hadith_search.py` |
| الصفحات | HTML ثابت يولده `build_site.py` + `partials.py` + `cssprune` | `tool_pages.py`، `new_tools.py`، `tools_extra.py`، `status_editor.py` |
| محرك المقاطع | Pillow (رسم إطارات النص بخط Amiri Quran) + FFmpeg (تركيب الخلفية والصوت والتظليل) بطابور مهام | `app.py: build()`, `render_still()`, `make_bg()`, `loops.py` |
| الصوت | EveryAyah (آية بآية) + Quran.com (صوت السورة + توقيتات الكلمات للتظليل) | `qc_timing()` |
| الخلفيات الحية | Pixabay (Pexels معطل) عبر وسيط على الخادم، المفتاح في `/etc/ayattla/media.env` | `media_broker.py` |
| المدونة | WordPress منفصل في `/blog/` بقالب فرعي `ayattla-blog` | `blog/theme/ayattla-blog/` |
| النشر الآلي | وحدة `publisher` (تيليجرام، يوتيوب، إنستغرام، فيسبوك، ثريدز، بلوسكاي، X، تيك توك، سناب، بنترست) | `publisher/` |
| التخزين | ملفات على القرص `data/cache` + SQLite (`khatma.db`) + localStorage في المتصفح | — |

## 2. ما يمكن إعادة استخدامه

1. **بيانات المحتوى المعتمدة** (نص قرآني، تفسير، أذكار، أحاديث، مراجع المواضيع، الأدعية، الرقية، الأسماء الحسنى): تُصدَّر من الخادم إلى حزمة محتوى JSON/SQLite موقعة بإصدار، يحملها التطبيق ويخزنها محليا (Offline-First).
2. **توقيتات الكلمات:** مصدرها Quran.com، وشروطها تمنع التخزين أكثر من أسبوع. يجب طلب إذن مزامنة رسمي من Quran Foundation قبل تضمينها في التطبيق، وإلا تُجلب عند الطلب وتُحذف بعد 6 أيام.
3. **منطق الحسابات** (مواقيت الصلاة بالزوايا لكل مدينة، القبلة، الزكاة، الختمة): يعاد تنفيذه في Swift بنفس المعادلات مع اختبارات مطابقة لنتائج الموقع.
4. **قواعد الرسم:** أحجام الخط والمقاسات والهوامش في `render_still()` و`Frame` هي المرجع لمطابقة مخرجات التطبيق.
5. **واجهات الخادم القابلة للاستخدام مباشرة** (بعد توثيقها وحمايتها بحد معدل): `/api/media/search|item|raw` (لإخفاء مفتاح Pixabay)، `/api/khatma*` (الختمة الجماعية)، `/api/azkar/audio/{i}.mp3`، `/api/hadith/*`، `/api/mosques`.

## 3. ما لا يُنقل كما هو

- **العرض على الخادم:** الموقع يصنع الفيديو على الخادم. التطبيق يجب أن يصنعه على الجهاز (AVFoundation) حتى يعمل دون إنترنت ولا يحمّل الخادم. هذا أكبر عمل هندسي في المشروع.
- **Canvas + MediaRecorder** في محرر الحالات: يُستبدل بمحرك الفيديو نفسه.
- **WebView:** ممنوع بنص المتطلبات.

## 4. محرك الفيديو في التطبيق (التصميم المقترح)

1. **مصدر النص:** نص عثماني محلي + خريطة كلمات (رقم الكلمة ↔ نصها) مطابقة لتقطيع Quran.com.
2. **التخطيط:** CoreText بخط قرآني مرخص (KFGQPC Uthmanic Hafs أو Amiri Quran، OFL)، مع التفاف أسطر من اليمين وقياس مستطيل كل كلمة لحساب التظليل.
3. **التوقيت:** مصفوفة (start, end) لكل كلمة من Quran.com؛ لا تقدير زمني. القراء بلا توقيت يُنتجون مقطعا بلا تظليل، كما في الموقع.
4. **التركيب:** `AVMutableComposition` (صوت مدمج للآيات + خلفية فيديو بحلقة أو صورة بحركة Ken Burns) + `AVVideoCompositionCoreAnimationTool` لطبقات النص والتظليل كـ `CALayer` بحركات `CAKeyframeAnimation` مضبوطة على الزمن.
5. **التصدير:** `AVAssetExportSession` بإعداد HEVC/H.264 1080p 30fps، مع تقدم، وإلغاء، واستئناف بعد الإغلاق عبر حفظ حالة المشروع، وملفات مؤقتة في `tmp/` تُنظف.
6. **الاختبار:** مقارنة إطارات مختارة مع مخرجات الموقع لنفس الإعدادات، وقياس الانجراف الزمني للتظليل (< 40ms).

## 5. التحديات والمخاطر

| التحدي | الأثر | الحل المقترح |
|---|---|---|
| البناء يتطلب macOS وXcode | لا يمكن بناء التطبيق أو اختباره من بيئة Linux السحابية | ربط جلسة Claude بجهاز Mac عبر تطبيق Claude لسطح المكتب، أو مطوّر يشغل Xcode |
| حساب Apple Developer (99$ سنويا) | مطلوب لـ TestFlight والنشر | قرار وتكلفة على المالك |
| حقوق توقيتات Quran.com وتسجيلات EveryAyah | التضمين في تطبيق يحتاج إذنا | مراسلة Quran Foundation وEveryAyah، وتوثيق الردود في CONTENT_AND_LICENSES.md |
| مفتاح Pixabay | لا يوضع في التطبيق | المرور عبر وسيط الخادم الحالي |
| أداء التصدير على الأجهزة القديمة | حرارة وبطء | دقة 720p اختيارية، وتصدير في الخلفية بـ BGProcessingTask |
| النص القرآني بالرسم الصحيح في CoreText | أخطاء تشكيل وربط | خط KFGQPC الرسمي + اختبارات بصرية لعينات معروفة |
| حجم المحتوى دون إنترنت | التلاوات كبيرة | تنزيل حسب القارئ والسورة مع عرض الحجم قبل التنزيل |

## 6. هيكل المشروع المقترح (Xcode)

```
AyatTutla/
  App/            (AyatTutlaApp, AppState, Navigation: TabView على iPhone و NavigationSplitView على iPad)
  DesignSystem/   (Colors من tokens الموقع، Typography، Components)
  Core/           (Models SwiftData، ContentStore، Networking، Downloads، Settings)
  Engines/
    Quran/        (Text, Pages, Search FTS5, Tajweed parser)
    Audio/        (Player, Downloader, NowPlaying)
    Video/        (Layout CoreText, Timeline, Composer, Exporter)
    Card/         (Renderer)
  Features/       (Home, Quran, Studio, Library, Tools — وحدة لكل أداة في المصفوفة)
  Widgets/        (آية اليوم، الأذكار)
  Resources/      (Fonts مرخصة، ContentPack.sqlite)
  Tests/          (Unit + Snapshot + UI)
```
