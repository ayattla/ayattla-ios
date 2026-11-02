# CONTINUE — نقطة الاستئناف (الفرع: main؛ العمل الجاري على claude/peaceful-bell-g613dx)

آخر تحديث: 2026-11-02 06:20 UTC

## 1. آخر حالة دقيقة

- المستودع: `ayattla/ayattla-ios`. فرع العمل: `claude/peaceful-bell-g613dx`.
- PR مفتوح: https://github.com/ayattla/ayattla-ios/pull/1 (شاشتا مواقيت الصلاة والقبلة، قائمة المدن الـ36، الصلاة القادمة، لقطات CI لكل شاشة على الفرع `ci-shots`).
- CI الـ PR: التشغيل 41397637081 قيد العمل — https://github.com/ayattla/ayattla-ios/actions/runs/41397637081
- آخر CI ناجح على main: https://github.com/ayattla/ayattla-ios/actions/runs/41396763300 (packages 16/16، app ناجح، لقطة الرئيسية أُرسلت للمالك).
- عائق بيئة: الجلسة لا تنزل artifacts (المضيف `productionresultssa2.blob.core.windows.net` محجوب). البديل: CI يرفع اللقطات إلى الفرع `ci-shots`.
- لا خطأ معروف حتى الآن (الشيفرة الجديدة لم تبن بعد وقت كتابة هذا).

## 2. الخطوة التالية بالضبط

1. تابع CI الـ PR وأصلح أي خطأ على نفس الفرع حتى تنجح packages وapp:
   ```
   gh run list -R ayattla/ayattla-ios -b claude/peaceful-bell-g613dx -L 3
   gh run view <RUN_ID> -R ayattla/ayattla-ios --log-failed | grep -E "error:|failed|XCTAssert" | head -50
   ```
2. افحص اللقطات وقارنها باللوحات `design/Prayer.dc.html` و`design/Qibla.dc.html`:
   ```
   git fetch origin ci-shots && git worktree add /tmp/shots origin/ci-shots && ls /tmp/shots
   ```
3. ادمج الـ PR بعد النجاح (squash)، ثم حدّث هذا الملف.
4. التالي حسب `docs/APP_ARCHITECTURE.md`: حزمة `AyatDesign` (ألوان ومكونات `design/System.dc.html`)، ثم المسبحة (`design/Tasbih.dc.html`، العبارات من حزمة المحتوى فقط)، ثم الختمة (`design/Khatma.dc.html`)، ثم الهجري بالتحويل في الاتجاهين.

## قرارات اتخذت دون سؤال المالك

- لم يُفتح PR لإصلاح البناء الأول لأنه نجح دون أخطاء.
- البناء والاختبار عبر GitHub Actions بديل عن Mac (بطلب المالك: «بعد نجاح البناء تابع المراحل»).
- الصلاة القادمة لا تشمل الشروق؛ بعد العشاء تكون فجر الغد.
- تنبيه قبل الأذان لم ينفذ لأن اللوحة لا تحدد المدة؛ والخريطة بديلا عن البوصلة مؤجلة.
- لا يُكتب أي نص ديني؛ الشاشات المعتمدة على القرآن والأذكار والتسبيح تنتظر حزمة المحتوى من المصادر المعتمدة.

## نص المتابعة

انسخ ما بين الخطين في جلسة Claude جديدة مربوطة بالمستودع `ayattla/ayattla-ios`:

---
أكمل مشروع تطبيق «آيات تتلى» من نفس النقطة دون أن تسألني. اقرأ بالترتيب من الفرع `main` في المستودع `ayattla/ayattla-ios`: `CONTINUE.md` ثم `HANDOFF.md` ثم `NEXT_SESSION_PROMPT.md`، ثم نفذ «الخطوة التالية بالضبط» في `CONTINUE.md`. البناء كله على GitHub Actions (لا Mac): تابع بـ `gh run list` و`gh run view --log-failed`، واعمل على فرع مع Pull Request حتى تنجح مهمتا packages وapp ثم ادمجه. بعد كل مرحلة مهمة (نجاح بناء، إصلاح، دمج PR) حدّث `CONTINUE.md` (الحالة، الخطوة التالية بالأوامر، ونص المتابعة) وارفعه فورا إلى main. لا تتوقف لسؤالي إلا إذا كان القرار ماليا أو ماسا بالموقع المباشر أو بالنص الديني؛ غير ذلك اختر الأفضل واذكر اختيارك في `CONTINUE.md`. القواعد الملزمة: لا WebView، لا حذف أي أداة، لا محتوى ديني من الذاكرة، لا تشكيل في نصوص الواجهة، لا مفاتيح أو كلمات مرور في الملفات، لا تعديل على الموقع المباشر، اسم المصور لا يظهر. قبل نفاد الحصة أو السياق: ارفع كل شيء، حدّث `CONTINUE.md` و`HANDOFF.md`، واكتب لي بالعربية أين وصلت مع نص المتابعة كاملا.
---
