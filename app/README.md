# مشروع التطبيق — بداية PHASE 4

**تنبيه:** هذه الشيفرة كتبت في جلسة Linux بلا Xcode ولا Swift، فلم تبن ولم تختبر بعد. أول خطوة على Mac هي البناء وإصلاح أي خطأ ترجمة.

## على جهاز Mac

```
brew install xcodegen
cd app
for p in AyatCalc AyatContent AyatTiming; do (cd Packages/$p && swift test); done
xcodegen                                  # ينشئ AyatTutla.xcodeproj
open AyatTutla.xcodeproj                  # ضع فريق التطوير بدل TODO_TEAM_ID
```

## ما الموجود

- `Packages/AyatCalc`: مواقيت الصلاة، القبلة، الهجري (أم القرى)، الزكاة. منقولة سطرا بسطر من شيفرة الموقع.
  - اختباراتها تقارن بـ `Tests/AyatCalcTests/Golden`، وهي نتائج قرئت من الموقع الحي في 2 نوفمبر 2026: 216 وقت صلاة لـ36 مدينة، و9 نقاط قبلة، و10 تواريخ هجرية، و7 حالات زكاة.
  - تحقق مؤقت على Linux: نسخة Python مطابقة لمنطق Swift حققت 241 فحصا دون خطأ. ويبقى البناء الحقيقي على Mac.
- `Packages/AyatContent`: قراءة حزمة المحتوى عبر SQLite (السور، الآيات، الصفحات، البحث، الترجمات، الأذكار، والتحقق من البصمة).
  - جمل SQL التسع فيها شغلت فعلا على حزمة اختبار، بالأداة `tools/check_content_sql.py`.
  - يجب التأكد على iOS من أن SQLite المدمج يدعم FTS5.
- `Packages/AyatTiming`: الخط الزمني للكلمات: رفض التوقيتات غير الصحيحة، ومعرفة الكلمة المظللة عند كل لحظة، والإزاحة عند إضافة البسملة.
  - نسخة Python مطابقة (`tools/check_timeline.py`) نجحت في 13 فحصا من 13.
- `App/`: هيكل SwiftUI: خمسة تبويبات على iPhone، وNavigationSplitView على iPad، وألوان الهوية، وشاشتا الزكاة والهجري.
- `project.yml`: مواصفات XcodeGen مع أذونات الموقع والصور والكاميرا بنصوص عربية.

## التالي حسب `docs/APP_ARCHITECTURE.md`

بناء الحزمة الحقيقية بـ `tools/build_content_pack.py` على جهاز يصل إلى المصادر، ثم AyatAudio، ثم AyatRender وAyatVideo، ثم بقية الشاشات حسب لوحة التصميم.
