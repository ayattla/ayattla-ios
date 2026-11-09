# نسخة خاصة من المستودع على خادمك

بعد إعدادها مرة واحدة، يحفظ GitHub نسخة كاملة من الشيفرة على خادمك تلقائيا بعد كل دمج، وكل جمعة، ومتى شئت يدويا. لا تكتب أنت أي أمر.

ما يُحفظ على الخادم:
- `~/backups/ayattla-ios.git`: المستودع كاملا بكل الفروع والتاريخ (يُنشأ تلقائيا أول مرة، ويُحدَّث بعد كل دمج).
- `~/backups/bundles/ayattla-ios-main-YYYY-MM-DD.bundle`: نسخة مؤرخة في ملف واحد، ويُحتفظ بآخر ٣٠ منها.

المساحة: نحو ٦٥ ميغابايت للمستودع، وأقل من ميغابايت لكل نسخة مؤرخة.

المجلد `~/backups` في المجلد الرئيسي لحسابك على الخادم، خارج `public_html`، فلا يمكن تنزيله من الإنترنت.

## الإعداد مرة واحدة

### ١. أنشئ المفتاح في لوحة الاستضافة (cPanel)

1. افتح cPanel ← **SSH Access** (الوصول عبر SSH) ← **Manage SSH Keys**.
   إن لم تجد SSH Access، فاطلب من دعم الاستضافة تفعيل SSH لحسابك.
2. اضغط **Generate a New Key**. الاسم: `github_backup`. اترك كلمة مرور المفتاح فارغة (GitHub لا يستطيع إدخالها). النوع: RSA بحجم 4096 إن خُيِّرت. ثم **Generate Key**.
3. ارجع إلى القائمة، وفي **Public Keys** اضغط **Manage** بجانب `github_backup` ثم **Authorize**.
4. في **Private Keys** اضغط **View/Download** بجانب `github_backup`، وانسخ النص كله من سطر `-----BEGIN` إلى سطر `-----END`.

### ٢. ضع المفتاح في GitHub (لا ترسله لأحد)

في المستودع على GitHub: **Settings ← Secrets and variables ← Actions ← New repository secret**، وأضف أربعة أسرار:

| الاسم | القيمة |
|---|---|
| `BACKUP_SSH_KEY` | النص الذي نسخته في الخطوة ١-٤ كاملا |
| `BACKUP_HOST` | اسم الخادم، مثل `ayattla.com` (أو ما يظهر في cPanel باسم Server/Shared IP) |
| `BACKUP_USER` | اسم مستخدم cPanel |
| `BACKUP_PORT` | منفذ SSH (يظهر في SSH Access أو لدى الدعم؛ كثيرا ما يكون 22 أو 21098 أو 2222) |

### ٣. التجربة

**Actions ← Server backup ← Run workflow**. إن ظهرت علامة خضراء فالنسخة على خادمك. ويمكنك رؤيتها في cPanel ← **File Manager** ← مجلد `backups`.

## الاستعادة على أي جهاز

نزّل أحدث ملف `.bundle` من مجلد `backups/bundles`، ثم:

```
git clone -b main ayattla-ios-main-YYYY-MM-DD.bundle ayattla-ios
```

## إن فشل

- `Permission denied`: المفتاح غير مفعّل (خطوة ١-٣)، أو اسم المستخدم خطأ.
- `Connection refused` أو انتهاء المهلة: المنفذ خطأ، أو SSH غير مفعّل لدى الاستضافة.
- `git is not installed`: الاستضافة بلا git؛ تُرفع النسخة المؤرخة فقط، وهي تكفي للاستعادة.

لإلغاء الوصول في أي وقت: احذف المفتاح `github_backup` من cPanel، أو احذف السر `BACKUP_SSH_KEY` من GitHub.
