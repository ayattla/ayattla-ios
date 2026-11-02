# APP_ARCHITECTURE — المرحلة الثانية: معمارية تطبيق «آيات تتلى»

الحالة: مسودة للاعتماد. مبنية على `WEBSITE_FEATURES_AUDIT.md` و`TECHNICAL_AUDIT.md`.
الحد الأدنى: iOS 17 / iPadOS 17 (SwiftData، Observation، TipKit). اللغة الأساسية العربية (RTL)، والإنجليزية لاحقا.

## 1. خريطة التطبيق والتنقل

iPhone: `TabView` بخمسة تبويبات. iPad: `NavigationSplitView` بشريط جانبي بنفس الأقسام، والمحررات بعمودين (معاينة + خيارات).

| التبويب | الشاشات | الأدوات من الموقع |
|---|---|---|
| **الرئيسية** | آية اليوم، متابعة القراءة، أزرار سريعة (مقطع، بطاقة، حالة، إهداء)، آخر المشاريع، المفضلة، المناسبة القادمة، الورد اليومي | ayah-of-the-day، occasions، favorites |
| **القرآن** | فهرس السور/الأجزاء/الصفحات ← قارئ المصحف (صفحات 604، أو آيات متتابعة) مع طبقات: تجويد، معاني الكلمات، تفسير/ترجمة؛ البحث؛ المواضيع؛ المشغل؛ الإذاعات؛ الرقية؛ الأسماء الحسنى | mushaf، tajweed، word-by-word، search، topics، listen، radio، ruqya، asma-ul-husna |
| **الاستوديو** | مشروع جديد: مقطع قرآني، بطاقة آية، حالة (آية/ذكر/حديث)، إهداء، بطاقة حديث، بطاقة اسم ← المحرر ← التصدير | maker، ayah-card، status-editor، hadith-card، templates |
| **مكتبتي** | المشاريع والمسودات، الصادرات، الآيات المحفوظة، التنزيلات (تلاوات وحزم محتوى)، خطط الحفظ والختم، التقدم | favorites، khatma، group-khatma، hifz-test، kids-juz-amma |
| **الأدوات** | الأذكار، الأدعية، المسبحة، مواقيت الصلاة، القبلة، الهجري، المناسبات، الزكاة، قضاء الصلوات، الصيام، المساجد القريبة، الأحاديث، التحقق من حديث، صفة الوضوء والصلاة | azkar، duas، tasbih، prayer-times، qibla، hijri، occasions، zakat، qada-salah، sawm-tracker، nearby-mosques، hadith، hadith-checker، prayer-guide |

الروابط العميقة: `ayattla://ayah/{s}/{a}`، `ayattla://studio/new?type=video&s=&a=&b=`، و Universal Links من `ayattla.com/tools/...` إلى الشاشة المقابلة.

## 2. الوحدات (Swift Packages داخل مشروع واحد)

| الحزمة | المسؤولية | تعتمد على |
|---|---|---|
| `AyatDesign` | الألوان، الخطوط، المسافات، المكونات (بطاقة، زر، شريط مقاس، شبكة خلفيات 5×2) | — |
| `AyatContent` | قراءة حزمة المحتوى SQLite (قرآن، تفسير، ترجمات، أذكار، أحاديث، مواضيع، أدعية) والتحقق من بصمتها | — |
| `AyatData` | نماذج SwiftData للمستخدم (مشاريع، مفضلة، تقدم، خطط، عدادات) والمزامنة الاختيارية بـ CloudKit | AyatContent |
| `AyatNetwork` | عميل API الخادم (OpenAPI)، التنزيل الخلفي، سياسة التخزين المؤقت (6 أيام لمحتوى Quran Foundation) | — |
| `AyatAudio` | المشغل (AVQueuePlayer)، التكرار، السرعة، Now Playing، تنزيل التلاوات | AyatNetwork |
| `AyatTiming` | توقيتات الكلمات: جلب، تحقق، تحويل إلى خط زمني؛ يرفض أي توقيت غير موثق | AyatNetwork |
| `AyatRender` | تخطيط النص العثماني بـ CoreText، قياس مستطيلات الكلمات، رسم البطاقات (PNG/JPG) | AyatDesign |
| `AyatVideo` | التركيب والتصدير (AVFoundation + Core Animation)، الاستئناف، تنظيف المؤقت | AyatRender، AyatTiming، AyatAudio |
| `AyatCalc` | مواقيت الصلاة، القبلة، الهجري، الزكاة، الختمة — بنفس معادلات الموقع ومع اختبارات مطابقة | — |
| `Features/*` | شاشة لكل أداة (SwiftUI + ViewModel بـ @Observable) | كل ما سبق |

## 3. نموذج البيانات

### محتوى ثابت (حزمة `content-vN.sqlite` تُشحن مع التطبيق ويُحدَّث إصدارها من الخادم)

| الجدول | الحقول |
|---|---|
| `surah` | id، name_ar، name_en، ayah_count، revelation، page_start |
| `ayah` | surah، ayah، text_uthmani، text_clean (للبحث)، page، juz، hizb |
| `ayah_fts` | فهرس FTS5 على text_clean |
| `word` | surah، ayah، position، text_uthmani (مطابق لتقطيع Quran.com) |
| `translation` | edition، surah، ayah، text (فقط المرخصة) |
| `azkar_category` / `azkar` | id، title / id، category، text، note، count، reference، audio_id (حصن المسلم، 256) |
| `hadith` | id، text، narrator، source، grade، explanation، topic (صحيح وحسن فقط) |
| `topic` / `topic_ref` | id، name / topic، surah، from، to |
| `dua` | id، source(quran/sunnah)، ref، need |
| `asma` | n، name، meaning، source |
| `reciter` | id، name، everyayah_folder، qf_recitation_id (nullable)، highlight |
| `meta` | content_version، sha256، built_at، sources_json |

### بيانات المستخدم (SwiftData)

| الكيان | الحقول الرئيسية |
|---|---|
| `Project` | id، kind (video/card/status/dedication/hadithCard/asmaCard)، title، createdAt، updatedAt، settings (Codable)، thumbnail، exportURLs |
| `ProjectSettings` (Codable) | range (s,a,b)، reciterId، ratio، fontScale، highlight (on, color)، translation، template (id, name, text)، background (kind: builtin/pixabay/local, ref, dim, blur, slow, motion)، preset |
| `Favorite` | surah، ayah، createdAt، note |
| `ReadingPosition` | page أو (surah, ayah)، updatedAt |
| `AzkarProgress` | day، itemId، remaining |
| `TasbihCounter` | phrase، count، target |
| `KhatmaPlan` | days، start، fromPage، perPrayer، done[] |
| `MemorizationItem` | surah، ayah، status، lastTested، score |
| `QadaCounter` / `FastDay` | prayer، remaining / date، kind |
| `Download` | kind (reciterSurah/contentPack)، ref، bytes، state |

## 4. خدمات الخادم للتطبيق (واجهة موثقة وقابلة للاستبدال)

يُضاف على الخادم الحالي بادئة جديدة `/app/v1/` دون تغيير أي مسار قائم في الموقع. مصادقة بمفتاح تطبيق عام + حد معدل لكل جهاز، دون أسرار داخل التطبيق.

| المسار | الغرض |
|---|---|
| `GET /app/v1/content/manifest` | أحدث إصدار لحزمة المحتوى وحجمها وبصمتها |
| `GET /app/v1/content/pack/{version}` | تنزيل الحزمة |
| `GET /app/v1/timing/{qf_id}/{surah}` | توقيتات الكلمات وصوت السورة (يحترم شرط الأسبوع) |
| `GET /app/v1/media/search` و`/item` و`/raw` | وسيط Pixabay (المفتاح على الخادم) |
| `GET /app/v1/azkar/audio/{id}` | تسجيلات حصن المسلم |
| `POST/GET /app/v1/khatma...` | الختمة الجماعية |
| `GET /app/v1/radios` | قائمة الإذاعات |
| `GET /app/v1/mosques?lat&lon` | المساجد القريبة (أو MapKit على الجهاز) |

## 5. التخزين والعمل دون إنترنت

- يعمل دون إنترنت من أول تشغيل: المصحف، البحث، التفسير، الأذكار، الأدعية، الأحاديث، المسبحة، المواقيت، القبلة، الهجري، الزكاة، المتتبعات، البطاقات بالخلفيات المدمجة.
- يحتاج تنزيلا مسبقا: التلاوات (لكل قارئ وسورة مع عرض الحجم قبل التنزيل)، توقيتات الكلمات، صور Pixabay المختارة (مؤقتا داخل المشروع).
- الملفات: `Application Support/Content` (الحزم)، `Caches/Audio` (LRU بحد قابل للضبط)، `Documents/Projects/{id}` (أصول المشروع)، `tmp/Render` (يُنظف بعد كل تصدير وعند الإقلاع).

## 6. محرك الفيديو — العقد البرمجي

```
struct RenderRequest { project: ProjectSettings; size: CGSize; fps: Int = 30; codec: .h264/.hevc }
protocol VideoComposer {
  func preview(_ r: RenderRequest, at time: CMTime) async throws -> CGImage
  func export(_ r: RenderRequest, to url: URL, progress: (Double) -> Void) async throws
  func resume(jobId: UUID) async throws
}
```

المراحل: تجميع الصوت (آيات متتابعة + بسملة عند الحاجة) ← خط زمني للكلمات ← تخطيط الصفحات (كل شاشة تتسع لعدد آيات) ← طبقات CALayer للنص والتظليل والترجمة والإهداء والعلامة ← خلفية (صورة بحركة، أو فيديو بحلقة، أو مدمجة مرسومة) ← تصدير مع تقدم وإلغاء.

قبول الجودة: مطابقة بصرية لمخرجات الموقع (نفس الإعدادات)، انجراف التظليل أقل من 40ms، تصدير 60 ثانية 1080p في أقل من دقيقة على iPhone 13.

## 7. الاختبارات

- Unit: AyatCalc (مطابقة نتائج الموقع لمدن مرجعية)، AyatContent (بصمة الحزمة وعدد الآيات 6236)، AyatTiming.
- Snapshot: البطاقات بالمقاسات الأربعة والأوضاع الفاتح والداكن.
- UI Tests: إنشاء مقطع، بطاقة، حالة، والتصدير، والعمل دون إنترنت.
- يدوي على أجهزة حقيقية: iPhone SE، iPhone 15، iPad mini، iPad Pro.
