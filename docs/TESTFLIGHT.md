# رفع نسخة إلى TestFlight

المسار `.github/workflows/testflight.yml` يبني نسخة Release من `main` مع حزمة المحتوى المعتمدة (من آخر بناء ناجح لـ «iOS CI» على main)، ويوقعها توقيعا تلقائيا، ويرفعها إلى TestFlight. لا يحتاج Mac.

## مرة واحدة (المالك)

1. اشترك في Apple Developer Program من developer.apple.com.
2. من **Membership** انسخ **Team ID** (عشرة أحرف).
3. في App Store Connect أنشئ التطبيق: **Apps ← +** ، الاسم «آيات تتلى»، معرف الحزمة `com.ayattla.AyatTutla`، اللغة الأساسية العربية.
4. من **Users and Access ← Integrations ← App Store Connect API** أنشئ مفتاحا بدور **App Manager**، ونزّل ملف `AuthKey_XXXX.p8` (يُنزّل مرة واحدة فقط)، وانسخ **Key ID** و**Issuer ID**.
5. في GitHub: **Settings ← Secrets and variables ← Actions ← New repository secret** وأضف:
   - `APPLE_TEAM_ID`
   - `ASC_KEY_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_P8` (محتوى ملف p8 كاملا، بما فيه سطرا BEGIN وEND)

لا تضع هذه القيم في أي ملف ولا في المحادثة.

## كل مرة

**Actions ← TestFlight ← Run workflow**. بعد ١٠ إلى ٣٠ دقيقة من نجاحه تظهر النسخة في App Store Connect ← TestFlight، فأضف المختبرين.

## إن فشل

- «Missing secrets»: سر ناقص من الخطوة ٥.
- خطأ توقيع أو «No profiles»: تأكد أن دور المفتاح App Manager وأن معرف الحزمة مسجل في الخطوة ٣. الودجت يسجل تلقائيا (`com.ayattla.AyatTutla.AyatWidget`).
- «No successful iOS CI run on main»: شغّل «iOS CI» على main أولا.
