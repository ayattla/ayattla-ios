# CONTINUE — نقطة الاستئناف (الفرع: main؛ العمل الجاري على claude/peaceful-bell-g613dx)

آخر تحديث: 2026-11-02 06:25 UTC بعد دمج PR #2

## 1. آخر حالة دقيقة

- المستودع: `ayattla/ayattla-ios`. فرع العمل: `claude/peaceful-bell-g613dx` (يُدمج فيه main بعد كل دمج PR).
- آخر PR: https://github.com/ayattla/ayattla-ios/pull/2 **مدموج** (squash `4f913b7`): شاشة الأدوات حسب `design/Tools.dc.html` (بحث، الصلاة القادمة مع زر القبلة، شبكتا «اليوم» و«العبادات والحساب»، كل الأدوات ١٤). CI: https://github.com/ayattla/ayattla-ios/actions/runs/41398983069 ناجح.
- قبله: https://github.com/ayattla/ayattla-ios/pull/1 **مدموج** (squash `3ee143c`): المواقيت، القبلة، الهجري بالاتجاهين، المناسبات، المدن الـ36، أرقام عربية هندية في كل التطبيق، لقطات CI.
- آخر CI ناجح للـ PR: https://github.com/ayattla/ayattla-ios/actions/runs/41398392011 — packages: AyatCalc 13، AyatContent 5، AyatTiming 5؛ app: 4 اختبارات + 7 لقطات.
- اللقطات على الفرع `ci-shots` (تُستبدل في كل تشغيل): home، tools، prayer، qibla، zakat، hijri، occasions. أُرسلت للمالك.
- لا خطأ حالي. عائق البيئة الوحيد: مضيف artifacts محجوب، والبديل الفرع `ci-shots`.

## 2. الخطوة التالية بالضبط

1. ابدأ من main دون فرض الدفع:
   ```
   git fetch origin && git checkout claude/peaceful-bell-g613dx && git merge origin/main
   ```
2. التالي: حزمة `AyatDesign` (نقل `Brand` و`card()` و`Num`)، ثم المساجد القريبة بـ MapKit `MKLocalSearch` (نصف القطر 1/3/5 كم كما في الموقع)، ثم الإعدادات (`design/Settings.dc.html`) والترحيب (`design/Onboarding.dc.html`).
3. لكل تغيير: push ← PR ← انتظر CI:
   ```
   gh run list -R ayattla/ayattla-ios -b claude/peaceful-bell-g613dx -L 3
   gh run view <RUN_ID> -R ayattla/ayattla-ios --log-failed | grep -E "error:|failed|XCTAssert" | head -50
   git fetch origin ci-shots && git worktree add -f ci-shots origin/ci-shots
   ```
   ثم دمج squash وتحديث هذا الملف.

## قرارات اتخذت دون سؤال المالك

- لم يُفتح PR لإصلاح البناء الأول لأنه نجح دون أخطاء.
- البناء والاختبار عبر GitHub Actions بديل عن Mac (بطلب المالك: «بعد نجاح البناء تابع المراحل»).
- الصلاة القادمة لا تشمل الشروق؛ بعد العشاء تكون فجر الغد.
- قضاء الصلوات والصيام والختمة مؤجلة: الجرد لا يبين كل سلوكها (قضاء: لا زر «قضيت»)، والختمة تحتاج أسماء السور من حزمة المحتوى.
- PHASE 1 أُغلقت اعتمادا على `docs/WEBSITE_TOOLS_WALKTHROUGH.md` (قرار المالك).
- تنبيه قبل الأذان لم ينفذ لأن اللوحة لا تحدد المدة؛ والخريطة بديلا عن البوصلة مؤجلة.
- لا يُكتب أي نص ديني؛ الشاشات المعتمدة على القرآن والأذكار والتسبيح تنتظر حزمة المحتوى من المصادر المعتمدة.

## نص المتابعة

انسخ ما بين الخطين في جلسة Claude جديدة مربوطة بالمستودع `ayattla/ayattla-ios`:

---
أكمل مشروع تطبيق «آيات تتلى» من نفس النقطة دون أن تسألني. اقرأ بالترتيب من الفرع `main` في المستودع `ayattla/ayattla-ios`: `CONTINUE.md` ثم `HANDOFF.md` ثم `NEXT_SESSION_PROMPT.md`، ثم نفذ «الخطوة التالية بالضبط» في `CONTINUE.md`. البناء كله على GitHub Actions (لا Mac): تابع بـ `gh run list` و`gh run view --log-failed`، واعمل على فرع مع Pull Request حتى تنجح مهمتا packages وapp ثم ادمجه. بعد كل مرحلة مهمة (نجاح بناء، إصلاح، دمج PR) حدّث `CONTINUE.md` (الحالة، الخطوة التالية بالأوامر، ونص المتابعة) وارفعه فورا إلى main. لا تتوقف لسؤالي إلا إذا كان القرار ماليا أو ماسا بالموقع المباشر أو بالنص الديني؛ غير ذلك اختر الأفضل واذكر اختيارك في `CONTINUE.md`. القواعد الملزمة: لا WebView، لا حذف أي أداة، لا محتوى ديني من الذاكرة، لا تشكيل في نصوص الواجهة، لا مفاتيح أو كلمات مرور في الملفات، لا تعديل على الموقع المباشر، اسم المصور لا يظهر. قبل نفاد الحصة أو السياق: ارفع كل شيء، حدّث `CONTINUE.md` و`HANDOFF.md`، واكتب لي بالعربية أين وصلت مع نص المتابعة كاملا.
---
