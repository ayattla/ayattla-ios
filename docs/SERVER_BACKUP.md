# نسخة خاصة من المستودع على خادمك (Hostinger VPS)

الخادم هو من يسحب الشيفرة من GitHub كل يوم، فلا يوضع أي مفتاح سري في GitHub. المفتاح يُنشأ على الخادم ولا يغادره، ويُضاف نصفه العام فقط إلى GitHub بصلاحية قراءة.

ما يُحفظ على الخادم:
- `~/backups/ayattla-ios-app/ayattla-ios.git`: المستودع كاملا بكل الفروع والتاريخ (نحو ٦٢ ميغابايت).
- `~/backups/ayattla-ios-app/bundles/ayattla-ios-main-YYYY-MM-DD.bundle`: نسخة يومية من main في ملف واحد (أقل من ميغابايت)، ويُحتفظ بآخر ٣٠.
- `~/backups/ayattla-ios-app/backup.log`: سطر لكل نسخة ناجحة.

مجلد خاص بالتطبيق داخل `~/backups`، فلا يختلط بنسخ الموقع الموجودة هناك، وهو خارج مجلدات المواقع فلا يمكن تنزيله من الإنترنت. الإعداد الأول (الملفات مباشرة في `~/backups`) ينقل إليه تلقائيا عند تشغيل السطر مرة أخرى.

## الإعداد مرة واحدة

1. في hPanel: **VPS ← وحدة تحكم الويب** (Web Terminal). تفتح طرفية في تبويب جديد.
2. الصق هذا السطر واضغط Enter:

   ```
   curl -fsSL https://raw.githubusercontent.com/ayattla/ayattla-ios/main/tools/server/backup-setup.sh | sh
   ```

   يثبت git إن لم يكن موجودا، وينشئ المفتاح والمجلد، ويأخذ أول نسخة، ويجدول نسخة يومية الساعة 03:17 بتوقيت الخادم. وفي آخره يطبع سطرا يبدأ بـ `ssh-ed25519`.
3. **ما دام المستودع عاما فهذا يكفي.** قبل أن تجعله خاصا: في GitHub ← المستودع ← **Settings ← Deploy keys ← Add deploy key**، الاسم `server-backup`، والصق سطر `ssh-ed25519` (المفتاح العام، آمن للمشاركة)، **واترك Allow write access مطفأ**، ثم Add key.

يمكن تشغيل السطر في الخطوة ٢ مرة أخرى بأمان؛ لا يكرر شيئا.

## التحقق

في الطرفية: `tail -3 ~/backups/ayattla-ios-app/backup.log` يعرض تاريخ آخر النسخ.

## الاستعادة على أي جهاز

نزّل أحدث ملف `.bundle` من `~/backups/ayattla-ios-app/bundles` (من File Manager أو SFTP)، ثم:

```
git clone -b main ayattla-ios-main-YYYY-MM-DD.bundle ayattla-ios
```

## الإلغاء

احذف مفتاح النشر من GitHub، وفي الطرفية: `crontab -l | grep -v ayattla-ios-app/backup.sh | crontab -`.
