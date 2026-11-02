# CONTINUE — نقطة الاستئناف (الفرع: main)

آخر تحديث: 2026-11-02 19:25 UTC بعد دمج PR #5

## 0. قفل العمل الجاري (لتجنب التكرار بين الجلسات)

- PR #3 (`AyatDesign`، المساجد، الإعدادات، الترحيب) **مدموج** — القفل انتهى.
- PR #4 «تحسينات تصميم iOS من مراجعة المحاكي» **مدموج** (squash `be82665`) — القفل انتهى، وكل الملفات حرة.
- PR #5 (حزمة المحتوى، المصحف، الأذكار، المسبحة، الرئيسية، مكتبتي) **مدموج** — القفل انتهى.
- 2026-11-02 19:25 UTC — الختمة وبطاقة الآية وجدولة التنبيهات تملكها جلسة الفرع `claude/khatma-card-notify`. لا تكررها.
- انتبه: الفرع `ci-shots` مشترك بين كل التشغيلات، فآخر CI يكتب فوق لقطات غيره.

## 1. آخر حالة دقيقة

- آخر PR: https://github.com/ayattla/ayattla-ios/pull/5 **مدموج** (squash `646fc12`). CI ناجح: https://github.com/ayattla/ayattla-ios/actions/runs/41507535805
  - **مهمة `content` في `ci.yml`** (ubuntu، قبل app): تجلب `quran-uthmani` من AlQuran Cloud، و`osamayy/azkar-db`، و`/api/meta` و`/tools/tasbih` من الموقع (قراءة فقط)، والخطين Amiri Quran وAmiri، ثم تبني `content-v1.sqlite` وتفحص جمل `ContentStore.swift` عليه، وتقارنه بتنزيل Tanzil المباشر (`tools/compare_tanzil.py`). تمرر الحزمة artifact إلى مهمة app فتضمن في `app/Content` (مجلد مرجعي في `project.yml`، غير محفوظ في git).
  - الباني: يفصل البسملة عن الآية ١ في ١١٢ سورة (من نص ١:١ نفسه، ويقبل صيغة الشدة في ٩٥ و٩٧ فقط)، `name_plain` بلا تشكيل، جدول `reciter` (مجلدات EveryAyah)، `meta.tasbih_phrases`.
  - التطبيق: `ContentLibrary` (يتحقق من sha256 ويسجل الخطوط)، `QuranView` + `MushafReader` + `RecitationPlayer` (بث EveryAyah، لا تنزيل)، `AzkarView` + `AzkarSession` (تقدم يومي)، `TasbihView`، `HomeView`، `LibraryView` (المفضلة).
- الاختبارات: Python ٨+٢؛ packages: AyatCalc 13، AyatContent 8، AyatTiming 5، AyatDesign 3؛ app: ContentTests على الحزمة الحقيقية + QuranLogicTests + السابقة.
- اللقطات على `ci-shots` تشمل الآن: quran، reader، azkar، azkar-session، tasbih، library، home-feed (+ داكن).

### قرار ينتظر المالك (نص ديني)

- مقارنة النص بتنزيل Tanzil المباشر: الحروف متطابقة في ٦٢٣١ آية. **٥ فروق إملائية** بين نسخة AlQuran Cloud (المعتمدة في الموقع) وإصدار Tanzil الأحدث: «بعد ما» كلمة أو كلمتان في ٢:١٨١ و٨:٦ و١٣:٣٧، والألف في «يا صاحبي» في ١٢:٣٩ و١٢:٤١. أبقيت نسخة الموقع حتى يقرر المالك؛ القائمة في `KNOWN` داخل `tools/compare_tanzil.py`، وأي فرق جديد يوقف البناء.

### قبله

- آخر PR: https://github.com/ayattla/ayattla-ios/pull/3 **مدموج** (squash `0b27590`). CI ناجح: https://github.com/ayattla/ayattla-ios/actions/runs/41497219706
  - حزمة `app/Packages/AyatDesign` (Brand، `card()`، `Color.cardSurface`، Num مع `distance`) + اختباراتها، ومهمة لها في CI.
  - المساجد القريبة `MosquesView`: نصف القطر ١/٣/٥ كم، «حدد موقعي وابحث»، `MKLocalSearch` بـ«مسجد» و«mosque» مع إزالة التكرار والترتيب، خريطة وقائمة بالمسافة، الضغط يفتح الاتجاهات مشيا. لقطة CI أظهرت ٣٥ مسجدا ضمن ٣ كم في الرياض.
  - الإعدادات `SettingsView` (من زر الترس في الرئيسية): القارئ (٣٤، ★ ١١ للتظليل) والترجمة (١٢) من `Catalog.swift` المولد من `docs/site_snapshot_2026-11-02.json`، حجم الخط s/m/l، المظهر يطبق على التطبيق كله، التنبيهات الثلاثة تطلب الإذن وتحفظ فقط، المصادر والتراخيص، الخصوصية، الإصدار، حزمة المحتوى.
  - الترحيب `OnboardingView`: ٣ شاشات ← الموقع ← التنبيهات ← القارئ ← الرئيسية، مع «تخطي». يظهر عند أول تشغيل (`onboarding.done`).
- الاختبارات: packages AyatCalc 13، AyatContent 5، AyatTiming 5، AyatDesign 3؛ app 4 ملفات (Smoke، Format، Mosques 3، Settings 4).
- اللقطات على `ci-shots`: home، tools، prayer، qibla، zakat، hijri، occasions، mosques، settings، onboarding (`-screen home` يتجاوز الترحيب).
- قبله: PR #1 (المواقيت، القبلة، الهجري، المناسبات) وPR #2 (شاشة الأدوات) مدموجان.

## 2. الخطوة التالية بالضبط

1. ابدأ من main بفرع جديد (الفرع `claude/peaceful-bell-g613dx` قديم):
   ```
   git fetch origin && git checkout -b claude/<اسم> origin/main
   ```
2. التالي بالترتيب:
   - الختمة حسب `design/Khatma.dc.html` و`/tools/khatma` (عدد الأيام، تاريخ البدء، أبدأ من صفحة، توزيع الورد على الصلوات) — الصفحات من الحزمة.
   - بطاقة الآية (صورة) حسب `design/Card.dc.html`: المقاسات الأربعة، حجم الخط، خلفيات مرسومة، حفظ ومشاركة (`ImageRenderer`).
   - جدولة التنبيهات (`notify.*`): الأذكار بعد الفجر وبعد العصر من مواقيت المدينة، آية اليوم، ورد الختمة.
   - ثم الاستوديو (محرك الفيديو AVFoundation) — أكبر عمل باق.
3. لكل تغيير: push ← PR ← انتظر CI:
   ```
   gh api "repos/ayattla/ayattla-ios/actions/runs?branch=<الفرع>&per_page=1" --jq '.workflow_runs[0].id'
   gh run view <RUN_ID> -R ayattla/ayattla-ios --log-failed | grep -E "error:|failed|XCTAssert" | head -50
   git fetch origin +ci-shots:refs/remotes/origin/ci-shots && git worktree add --detach shots origin/ci-shots
   ```
   ثم دمج squash: `gh api -X PUT repos/ayattla/ayattla-ios/pulls/<N>/merge -f merge_method=squash` (GraphQL محجوب، استخدم REST)، وحدّث هذا الملف.

## قرارات اتخذت دون سؤال المالك

- لم يُفتح PR لإصلاح البناء الأول لأنه نجح دون أخطاء.
- البناء والاختبار عبر GitHub Actions بديل عن Mac (بطلب المالك: «بعد نجاح البناء تابع المراحل»).
- الصلاة القادمة لا تشمل الشروق؛ بعد العشاء تكون فجر الغد.
- قضاء الصلوات والصيام والختمة مؤجلة: الجرد لا يبين كل سلوكها (قضاء: لا زر «قضيت»)، والختمة تحتاج أسماء السور من حزمة المحتوى.
- PHASE 1 أُغلقت اعتمادا على `docs/WEBSITE_TOOLS_WALKTHROUGH.md` (قرار المالك).
- تنبيه قبل الأذان لم ينفذ لأن اللوحة لا تحدد المدة؛ والخريطة بديلا عن البوصلة مؤجلة.
- المساجد: بحث MapKit على الجهاز بدل `/app/v1/mosques` لأنه لا يحتاج خادما؛ استعلامان (عربي وإنجليزي) لأن الخرائط تفهرس الاسمين منفصلين.
- الإعدادات: الإصدار وحزمة المحتوى في صفين منفصلين بدل «[رقم الإصدار] · محتوى [الإصدار]» في اللوحة، لأن خلط الأرقام بالنص العربي في سطر واحد عكس ترتيبها.
- الإعدادات: التنبيهات تحفظ الاختيار وتطلب الإذن فقط؛ الجدولة مؤجلة لأن اللوحة لا تحدد المواعيد ونصوصها تعتمد على حزمة المحتوى.
- الترحيب: اللوحة تعطي نص الشاشة الأولى فقط؛ نصا الشاشتين الثانية والثالثة (المواقيت والقبلة؛ دون إنترنت) كتبتهما من وصف التطبيق، وليس فيهما نص ديني. الشعار مؤقت برمز SF حتى يضاف شعار مجلد brand.
- لا يُكتب أي نص ديني؛ الشاشات المعتمدة على القرآن والأذكار والتسبيح تنتظر حزمة المحتوى من المصادر المعتمدة.

## نص المتابعة

انسخ ما بين الخطين في جلسة Claude جديدة مربوطة بالمستودع `ayattla/ayattla-ios`:

---
أكمل مشروع تطبيق «آيات تتلى» من نفس النقطة دون أن تسألني. اقرأ بالترتيب من الفرع `main` في المستودع `ayattla/ayattla-ios`: `CONTINUE.md` ثم `HANDOFF.md` ثم `NEXT_SESSION_PROMPT.md`، ثم نفذ «الخطوة التالية بالضبط» في `CONTINUE.md`. البناء كله على GitHub Actions (لا Mac): تابع بـ `gh run list` و`gh run view --log-failed`، واعمل على فرع مع Pull Request حتى تنجح مهمتا packages وapp ثم ادمجه. بعد كل مرحلة مهمة (نجاح بناء، إصلاح، دمج PR) حدّث `CONTINUE.md` (الحالة، الخطوة التالية بالأوامر، ونص المتابعة) وارفعه فورا إلى main. لا تتوقف لسؤالي إلا إذا كان القرار ماليا أو ماسا بالموقع المباشر أو بالنص الديني؛ غير ذلك اختر الأفضل واذكر اختيارك في `CONTINUE.md`. القواعد الملزمة: لا WebView، لا حذف أي أداة، لا محتوى ديني من الذاكرة، لا تشكيل في نصوص الواجهة، لا مفاتيح أو كلمات مرور في الملفات، لا تعديل على الموقع المباشر، اسم المصور لا يظهر. قبل نفاد الحصة أو السياق: ارفع كل شيء، حدّث `CONTINUE.md` و`HANDOFF.md`، واكتب لي بالعربية أين وصلت مع نص المتابعة كاملا.
---
