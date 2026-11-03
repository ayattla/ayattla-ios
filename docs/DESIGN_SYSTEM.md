# DESIGN_SYSTEM — نظام التصميم المركزي

المصدر: `styles/tokens.css` وثيم الصفحة الرئيسية في ayattla.com. التنفيذ: الحزمة `app/Packages/AyatDesign`. لا تكتب أي شاشة لونا أو خطا أو زاوية مباشرة؛ كلها من هنا. اللوحات المرجعية في `design/System.dc.html`.

## الألوان (`Brand.swift`)

| الرمز | الفاتح | الداكن | الاستخدام | متغير الموقع |
|---|---|---|---|---|
| `primary` | #102D27 | #1B4238 | التعبئة الزمردية، الأزرار الرئيسية | `--c-primary` |
| `primaryInk` | #14463A | #D9C28E | الروابط والنص الصغير الملون (تباين AA) | — |
| `g0` → `primary` → `deep` | #17392F → #102D27 → #0B211C | #143128 → #1B4238 → #0A1814 | التدرج الزمردي | `--gradient-brand` |
| `accent` | #C3A66B | #D9C28E | الذهبي، أزرار على الزمردي | `--c-gold` |
| `goldInk` | #7A5F28 | #D9C28E | نص ذهبي على العاجي | — |
| `goldSoft` | #F1E8D3 | #2A3A2C | خلفية أيقونات بطاقات الأدوات | — |
| `background` | #F6F2E9 | #0C1C18 | خلفية الشاشات (عاجي) | `--c-bg` |
| `surface` | #FFFFFF | #11261F | البطاقات | `--c-surface` |
| `surface2` | #EFE9DC | #173129 | سطح ثان | — |
| `ink` | #202823 | #F1ECE1 | النص | `--c-ink` |
| `muted` | #5C625D | #B9B3A5 | النص الثانوي | `--c-muted` |
| `tint` | #E4ECE6 | #1E3A30 | الرقائق والتحديد الخفيف | `--c-primary-soft` |
| `line` / `lineStrong` | #E3EBE5 / #CFDCD3 | #22392F / #2E4A3E | الحدود | `--c-line` |
| `onPrimary` | #F6F2E9 | — | النص على الزمردي | — |

## الخطوط

| الدور | الخط | الملاحظة |
|---|---|---|
| الواجهة | IBM Plex Sans Arabic (Regular، Medium، SemiBold، Bold) | `Font.ui(.style, weight)` يتبع Dynamic Type |
| المصحف | Amiri Quran | لا بديل؛ حجمه بمقياس المستخدم لا بـ Dynamic Type |
| الأذكار والحديث | Amiri | — |

نصوص الواجهة بلا تشكيل (قاعدة ملزمة). الأرقام هندية عربية عبر `Num`.

## الشكل

| الرمز | القيمة | متغير الموقع |
|---|---|---|
| `radiusCard` | 20 | `--r-card` |
| `radiusSmall` | 12 | `--r-sm` |
| ظل البطاقة | #102D27 بشفافية 7٪، نصف قطر 8، إزاحة 4 | `--sh-1` |
| إطار اللوحة الزمردية | خط ذهبي 1 بشفافية 45٪ بداخل 6 | `--frame` |
| أقل مساحة لمس | 44 | معيار Apple |

## المكونات (`Components.swift` و`Brand.swift`)

| الاسم في `MASTER_PROMPT` | في الكود |
|---|---|
| AppCard | `.card()` |
| لوحة البطل | `.emeraldPanel(radius:)` |
| خلفية الشاشة | `.brandScreen()` |
| SectionHeader | `SectionHeader(title, subtitle:, trailing:)` |
| PrimaryButton / SecondaryButton | `.buttonStyle(.brandPrimary)` / `.brandSecondary` / `.brandGold` |
| ToolCard | `ToolCard(title, subtitle:, symbol:)` |
| CategorySelector | `CategorySelector(items, selection:)` |
| EmptyState / LoadingState / ErrorState | بالأسماء نفسها |
| MiniAudioPlayer / AudioPlayer | `MiniPlayerBar` و`NowPlayingSheet` (التطبيق، `AudioCenter.swift`) و`PlayerBar` في المصحف |
| BottomNavigation | `RootView` و`BrandAppearance` (ألوان شريط التبويب والتنقل) |
| QuranCard / AzkarCard / HadithCard / ReciterCard / StatusTemplateCard | `ayahCard` في الرئيسية، `ZikrCard`، `HadithRow`، صفوف القراء، `CardCanvas` |

ما بقي من شاشات قديمة يستخدم أنماطا محلية يُنقل إلى هذه المكونات تدريجيا عند لمس كل شاشة، دون تغيير سلوكها.
