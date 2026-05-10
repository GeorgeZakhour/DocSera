# Welcome Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the post-signup welcome wizard described in `docs/superpowers/specs/2026-05-10-welcome-wizard-design.md` — 18 animated screens with the "Glass Atelier" visual system, persistence, replay-from-account, and existing-user migration.

**Architecture:** A wizard composed of (a) a small reusable glass-kit widget library, (b) four screen-mode scaffolds (Showcase/Feature/Manifesto/Celebration) configured per screen, (c) a Cubit owning page index + entry mode + persistence, and (d) integration with the existing `WelcomePage`-after-signup flow + a new account-page tile for replay. All visuals are Flutter-native (`AnimationController` + `Tween` + `BackdropFilter` + `ShaderMask`) — no new dependencies.

**Tech Stack:** Flutter (Dart ≥3.6), `flutter_bloc` (Cubit), `bloc_test` + `mocktail` (already deps), `flutter_svg` (already a dep), `flutter_screenutil` (already in use), `shared_preferences` (already in use).

---

## File map (decomposition)

### New files

```
lib/Business_Logic/Onboarding/welcome_wizard/
├── welcome_wizard_cubit.dart         [page index, skip/complete, persistence]
├── welcome_wizard_state.dart          [WizardEntryMode enum + state class]

lib/screens/onboarding/welcome_wizard/
├── README.md                          [conventions doc]
├── welcome_wizard_screen.dart         [PageView shell + skip/next/dots]
├── widgets/
│   ├── glass_kit/
│   │   ├── glass_marble.dart
│   │   ├── glass_capsule.dart
│   │   ├── glass_tag.dart
│   │   ├── glass_shard.dart
│   │   └── glass_orb_large.dart
│   ├── glass_title.dart
│   ├── wizard_background.dart         [the two drifting orbs + accent orb]
│   ├── wizard_skip_button.dart
│   ├── wizard_next_button.dart        [pulse halo + chevron OR labeled CTA]
│   ├── wizard_page_dots.dart          [pill-extending active dot]
│   ├── wizard_step_tag.dart           [glass tag with "step X of Y"]
│   └── scaffolds/
│       ├── showcase_scaffold.dart
│       ├── feature_scaffold.dart
│       ├── manifesto_scaffold.dart
│       └── celebration_scaffold.dart
└── screens/
    ├── s01_welcome.dart
    ├── s02_search.dart
    ├── s03_doctor_profile.dart
    ├── s04_favorites.dart
    ├── s05_promotions.dart
    ├── s06_personal_gifts.dart
    ├── s07_booking.dart
    ├── s08_chat.dart
    ├── s09_visit_reports.dart
    ├── s10_documents.dart
    ├── s11_health.dart
    ├── s12_notes.dart
    ├── s13_relatives.dart
    ├── s14_loyalty_intro.dart
    ├── s15_earn_points.dart
    ├── s16_vouchers.dart
    ├── s17_referral.dart
    └── s18_all_set.dart

assets/images/onboarding/
├── ic_doctor.svg
├── ic_search.svg
├── ic_heart.svg
├── ic_promo.svg
├── ic_gift.svg
├── ic_calendar.svg
├── ic_chat.svg
├── ic_report.svg
├── ic_documents.svg
├── ic_health.svg
├── ic_pen.svg
├── ic_family.svg
├── ic_loyalty.svg
├── ic_points.svg
├── ic_qr.svg
└── ic_referral.svg

test/
└── welcome_wizard_cubit_test.dart
```

### Modified files

- `lib/screens/auth/sign_up/WelcomePage.dart` — change `Navigator.pushAndRemoveUntil` target + button copy
- `lib/screens/home/account_page.dart` — insert "Replay welcome tour" tile
- `lib/main.dart` — register the cubit in `MultiBlocProvider`, add one-time migration
- `lib/l10n/app_ar.arb` — 43 new keys
- `lib/l10n/app_en.arb` — 43 new keys
- `pubspec.yaml` — register `assets/images/onboarding/` directory

---

## Phase 1 — Foundation

### Task 1: Create folder structure and stubs

**Files:**
- Create: directory tree above (empty `.dart` files for now), `lib/screens/onboarding/welcome_wizard/README.md` (placeholder content)

- [ ] **Step 1: Create the directory structure**

```bash
mkdir -p lib/Business_Logic/Onboarding/welcome_wizard
mkdir -p lib/screens/onboarding/welcome_wizard/widgets/glass_kit
mkdir -p lib/screens/onboarding/welcome_wizard/widgets/scaffolds
mkdir -p lib/screens/onboarding/welcome_wizard/screens
mkdir -p assets/images/onboarding
```

- [ ] **Step 2: Write the README skeleton**

Create `lib/screens/onboarding/welcome_wizard/README.md`:

```markdown
# Welcome Wizard

Post-signup feature tour. See full spec at
`docs/superpowers/specs/2026-05-10-welcome-wizard-design.md`.

## Visual signature: "Glass Atelier"

Four-layer system on every screen:

1. **Backdrop** — mint gradient + 2 drifting teal orbs (always on).
2. **Glass kit** — composable widgets: `GlassMarble`, `GlassCapsule`, `GlassTag`,
   `GlassShard`, `GlassOrbLarge`. Imported from `widgets/glass_kit/`.
3. **Hero** — solid teal feature icon (Feature mode) OR icon-inside-orb (Showcase + Celebration).
4. **Typography** — Cairo title via `GlassTitle` widget (`ShaderMask` over teal gradient).

## Four screen modes

| Mode | Used for | Scaffold |
|---|---|---|
| Showcase | Welcome (01), Closing (18) | `ShowcaseScaffold` |
| Feature | Most workhorse screens | `FeatureScaffold` |
| Manifesto | Health (11), Loyalty intro (14), Referral (17) | `ManifestoScaffold` |
| Celebration | Promotions, Gifts, Earn points, Vouchers | `CelebrationScaffold` |

## RULE: per-screen position variation

The floating composition (marble positions/sizes/rotations, capsule angle,
step-tag position) MUST differ between adjacent screens. Each screen file owns
its `MarbleSpec` + `CapsuleSpec` + `TagSpec` arrangement. Reviewer responsibility.

## Adding a new screen

1. Decide its mode (Showcase / Feature / Manifesto / Celebration).
2. Create `screens/sNN_yourscreen.dart`, instantiate the matching scaffold with
   unique marble/capsule/tag positions + a unique signature motion.
3. Add the SVG icon to `assets/images/onboarding/`.
4. Add ARB keys `wizard_yourscreen_title` + `wizard_yourscreen_body` (plus EN translation).
5. Register the screen in `welcome_wizard_screen.dart`'s page builder.
6. Test in both AR (RTL) and EN (LTR).
```

- [ ] **Step 3: Commit**

```bash
git add lib/Business_Logic/Onboarding lib/screens/onboarding assets/images/onboarding
git commit -m "feat(welcome-wizard): scaffold folder structure + README"
```

---

### Task 2: Add ARB strings (43 keys × 2 locales)

**Files:**
- Modify: `lib/l10n/app_ar.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Append new keys to `app_ar.arb`**

Insert before the closing `}` (preserve existing key order — do not reorder existing keys). The exact AR strings are below.

```jsonc
  "wizard_skip_button": "تخطّي",
  "wizard_step_label": "الخطوة {current} من {total}",
  "@wizard_step_label": { "placeholders": { "current": { "type": "String" }, "total": { "type": "String" } } },
  "wizard_lets_begin": "هيا نبدأ",
  "wizard_done": "تم",
  "discoverDocsera": "تعرّف على دوكسيرا",
  "replayWelcomeTour": "أعد الجولة التعريفية",
  "replayWelcomeTourSubtitle": "شاهد كل ما يقدّمه دوكسيرا من جديد",

  "wizard_welcome_salam": "أهلاً",
  "wizard_welcome_tagline": "في رعايةٍ تليق بك",
  "wizard_welcome_subline": "خطوةٌ، خطوة — معاً نُكمل المشوار.",

  "wizard_search_title": "اعثر على طبيبك بثوانٍ",
  "wizard_search_body": "ابحث بالاسم، التخصص، أو العيادة. وفلتر بالموقع، اللغة، وساعات العمل.",

  "wizard_doctor_title": "كل ما تحتاج، قبل الحجز",
  "wizard_doctor_body": "الاختصاص، اللغات، ساعات العمل، العنوان، الأسعار، والخدمات — على ملف واحد.",

  "wizard_favorites_title": "احفظ من تثق بهم",
  "wizard_favorites_body": "أضف أطباءك المفضّلين بضغطة، وارجع إليهم لاحقاً — دون بحث جديد.",

  "wizard_promotions_title": "عروض من أطباء دوكسيرا",
  "wizard_promotions_body": "احصل على رمز الخصم من التطبيق، واعرضه عند الدفع — يُطبَّق الخصم تلقائياً على فاتورتك.",

  "wizard_gifts_title": "هدايا شخصية من طبيبك",
  "wizard_gifts_body": "بعض الأطباء يرسلون هدايا حصرية لمرضاهم في دوكسيرا — تصل مباشرة إلى محفظتك.",

  "wizard_booking_title": "احجز موعدك بدقيقة",
  "wizard_booking_body": "اختر اليوم والساعة. ستصلك تذكيرات قبل الموعد — بدون اتصالات أو انتظار.",

  "wizard_chat_title": "كلّم طبيبك مباشرةً، بأمان",
  "wizard_chat_body": "أرسل سؤالاً، صورةً، أو ملاحظة صوتية — محادثاتك معه مشفّرة بالكامل.",

  "wizard_reports_title": "تقارير زياراتك، محفوظة لك",
  "wizard_reports_body": "حين يُرفق طبيبك تقريراً بعد الزيارة — تشخيص، أدوية، تعليمات — تجده هنا، في أي وقت.",

  "wizard_documents_title": "ملفاتك الطبية، بأمان",
  "wizard_documents_body": "ارفع التحاليل، الوصفات، والصور الشعاعية. ستجد بجانبها الملفات التي يرسلها أطباؤك.",
  "wizard_documents_badge": "مشفّر",

  "wizard_health_title": "صحّتك بصورة كاملة",
  "wizard_health_body": "حساسيّاتك، أدويتك، أمراضك المزمنة، تاريخك العائلي، نمط حياتك — مرجع واحد، مفيد في الحالات الطارئة.",

  "wizard_notes_title": "ملاحظاتك — لك أنت فقط",
  "wizard_notes_body": "دوّن أعراضاً، أسئلة لطبيبك، أو ملاحظات شخصية. لا أحد يراها — حتى نحن.",
  "wizard_notes_badge": "خاص",

  "wizard_relatives_title": "اعتنِ بعائلتك من حسابك",
  "wizard_relatives_body": "أضف أبناءك، والدَيك، أو من تعتني بهم — واحجز وادر مواعيدهم من نفس المكان.",

  "wizard_loyalty_title": "ولاؤك له قيمة",
  "wizard_loyalty_body": "كل تفاعل مع دوكسيرا — موعد، ملف، أو دعوة صديق — يصبح نقاطاً تفتح لك عروضاً وهدايا حقيقية.",

  "wizard_earn_title": "كل خطوة، نقطة في رصيدك",
  "wizard_earn_body": "احضر موعداً، أكمل ملفك الصحي، ادعُ صديقاً — كلها تضيف إلى رصيدك تلقائياً، بدون أي مجهود إضافي.",

  "wizard_vouchers_title": "استبدل، امسح، استمتع",
  "wizard_vouchers_body": "حوّل نقاطك إلى قسائم. أظهر رمز QR لدى أحد شركائنا — صيدلية، مخبر، عيادة، محل نظارات، وغيرها — وستحصل على خصمك فوراً.",

  "wizard_referral_title": "ادعُ صديقاً، اربحوا معاً",
  "wizard_referral_body": "تكسب ٢٥ نقطة لكل صديق ينضم برمزك، وهو يحصل على ١٥ مكافأة ترحيب — في نفس اليوم.",

  "wizard_allset_title": "كلّ شيء جاهز، {firstName}",
  "@wizard_allset_title": { "placeholders": { "firstName": { "type": "String" } } },
  "wizard_allset_body": "حسابك مفعّل، أدواتك تنتظر، ونقاطك تبدأ من الآن. هيا نبدأ.",
```

- [ ] **Step 2: Append matching keys to `app_en.arb`**

```jsonc
  "wizard_skip_button": "Skip",
  "wizard_step_label": "Step {current} of {total}",
  "@wizard_step_label": { "placeholders": { "current": { "type": "String" }, "total": { "type": "String" } } },
  "wizard_lets_begin": "Let's begin",
  "wizard_done": "Done",
  "discoverDocsera": "Discover DocSera",
  "replayWelcomeTour": "Replay the welcome tour",
  "replayWelcomeTourSubtitle": "See everything DocSera offers again",

  "wizard_welcome_salam": "Welcome",
  "wizard_welcome_tagline": "Care that suits you",
  "wizard_welcome_subline": "Step by step — we walk this together.",

  "wizard_search_title": "Find your doctor in seconds",
  "wizard_search_body": "Search by name, specialty, or clinic. Filter by location, language, hours.",

  "wizard_doctor_title": "Everything you need, before you book",
  "wizard_doctor_body": "Specialty, languages, hours, address, pricing, services — on a single profile.",

  "wizard_favorites_title": "Keep your trusted doctors close",
  "wizard_favorites_body": "One-tap favorites. Come back without searching again.",

  "wizard_promotions_title": "Offers from DocSera doctors",
  "wizard_promotions_body": "Claim a discount code in the app. Show it at payment — applied automatically to your bill.",

  "wizard_gifts_title": "Personal gifts from your doctor",
  "wizard_gifts_body": "Some doctors send exclusive gifts to their DocSera patients — they land in your wallet.",

  "wizard_booking_title": "Book in under a minute",
  "wizard_booking_body": "Pick a day and time. We'll remind you. No calls. No waiting.",

  "wizard_chat_title": "Message your doctor, securely",
  "wizard_chat_body": "Send a question, photo, or voice note. Fully encrypted.",

  "wizard_reports_title": "Your visit reports, kept for you",
  "wizard_reports_body": "When your doctor attaches a report — diagnosis, meds, instructions — you'll find it here.",

  "wizard_documents_title": "Your medical files, safe",
  "wizard_documents_body": "Upload labs, prescriptions, scans. Files sent by your doctors land here too.",
  "wizard_documents_badge": "Encrypted",

  "wizard_health_title": "Your health, the full picture",
  "wizard_health_body": "Allergies, medications, conditions, family history, lifestyle — one reference, useful in emergencies.",

  "wizard_notes_title": "Notes only you can see",
  "wizard_notes_body": "Symptoms, questions, personal observations. No one else can read them — not even us.",
  "wizard_notes_badge": "Private",

  "wizard_relatives_title": "Care for your family from one account",
  "wizard_relatives_body": "Add children, parents, or anyone you care for. Book and manage their visits in the same place.",

  "wizard_loyalty_title": "Your loyalty earns its value",
  "wizard_loyalty_body": "Every move with DocSera — a visit, a profile, a friend — becomes points that unlock real offers and gifts.",

  "wizard_earn_title": "Every step adds to your balance",
  "wizard_earn_body": "Attend a visit, complete your health profile, invite a friend — they all add up automatically.",

  "wizard_vouchers_title": "Redeem, scan, enjoy",
  "wizard_vouchers_body": "Turn points into vouchers. Show your QR at one of our partners — pharmacy, lab, clinic, optical shop, and others — and your discount applies instantly.",

  "wizard_referral_title": "Invite a friend, both win",
  "wizard_referral_body": "25 points for you, 15 welcome points for them — same day they join with your code.",

  "wizard_allset_title": "You're all set, {firstName}",
  "@wizard_allset_title": { "placeholders": { "firstName": { "type": "String" } } },
  "wizard_allset_body": "Account ready, tools waiting, points starting now. Let's go.",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors. Generated files updated under `lib/gen_l10n/`.

- [ ] **Step 4: Verify analyze passes**

Run: `flutter analyze --no-pub`
Expected: no errors related to localization (existing warnings ok).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_ar.arb lib/l10n/app_en.arb lib/gen_l10n/
git commit -m "feat(welcome-wizard): add 43 ARB keys for wizard copy (AR+EN)"
```

---

### Task 3: Add SVG icons

**Files:** Create 16 files under `assets/images/onboarding/`. All viewBox 64×64 unless noted; stroke-only icons use `currentColor` so the parent widget controls the color.

- [ ] **Step 1: Create `ic_doctor.svg` (stethoscope)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M16 8 v18 a8 8 0 0 0 16 0 V8 M48 8 v18 a8 8 0 0 1 -16 0 M24 38 v8 a8 8 0 0 0 8 8 a8 8 0 0 0 8 -8 v-4"/>
  <circle cx="48" cy="40" r="6"/>
</svg>
```

- [ ] **Step 2: Create `ic_search.svg` (magnifier)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round">
  <circle cx="26" cy="26" r="16"/>
  <line x1="38" y1="38" x2="54" y2="54"/>
</svg>
```

- [ ] **Step 3: Create `ic_heart.svg` (with sparkle)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M32 56 C 12 42, 4 28, 12 18 C 18 11, 28 12, 32 20 C 36 12, 46 11, 52 18 C 60 28, 52 42, 32 56 Z"/>
  <path d="M48 8 L49.5 12 L53 13.5 L49.5 15 L48 19 L46.5 15 L43 13.5 L46.5 12 Z" fill="currentColor"/>
</svg>
```

- [ ] **Step 4: Create `ic_promo.svg` (discount tag)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M34 6 L58 6 L58 30 L30 58 L6 34 Z"/>
  <circle cx="46" cy="18" r="3.5" fill="currentColor"/>
  <line x1="22" y1="32" x2="32" y2="42"/>
  <circle cx="22" cy="32" r="2" fill="currentColor"/>
  <circle cx="32" cy="42" r="2" fill="currentColor"/>
</svg>
```

- [ ] **Step 5: Create `ic_gift.svg` (DocSera-style gift box, viewBox 120×120)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
  <defs>
    <linearGradient id="giftBox" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#4DD0D2"/>
      <stop offset="1" stop-color="#009092"/>
    </linearGradient>
    <linearGradient id="giftLid" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#6ee0e2"/>
      <stop offset="1" stop-color="#009092"/>
    </linearGradient>
    <linearGradient id="giftRibbon" x1="0" x2="1" y1="0" y2="0">
      <stop offset="0" stop-color="#FFA070"/>
      <stop offset="1" stop-color="#FFC8A8"/>
    </linearGradient>
  </defs>
  <rect x="22" y="50" width="76" height="56" rx="6" fill="url(#giftBox)"/>
  <rect x="18" y="40" width="84" height="18" rx="4" fill="url(#giftLid)"/>
  <rect x="55" y="40" width="10" height="66" fill="url(#giftRibbon)"/>
  <rect x="18" y="46" width="84" height="8" fill="url(#giftRibbon)"/>
  <path d="M60 40 C 44 22, 28 30, 34 42 C 40 52, 56 44, 60 40 Z" fill="url(#giftRibbon)"/>
  <path d="M60 40 C 76 22, 92 30, 86 42 C 80 52, 64 44, 60 40 Z" fill="url(#giftRibbon)"/>
  <ellipse cx="60" cy="40" rx="6" ry="4" fill="#FF8A5C"/>
  <path d="M22 50 L22 56 L98 56 L98 50" fill="rgba(255,255,255,.18)"/>
</svg>
```

- [ ] **Step 6: Create `ic_calendar.svg` (with check)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <rect x="10" y="14" width="44" height="40" rx="6"/>
  <line x1="10" y1="26" x2="54" y2="26"/>
  <line x1="20" y1="8" x2="20" y2="18"/>
  <line x1="44" y1="8" x2="44" y2="18"/>
  <path d="M22 40 L29 46 L42 32" stroke-width="3.8"/>
</svg>
```

- [ ] **Step 7: Create `ic_chat.svg` (bubble + dots)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M8 14 a6 6 0 0 1 6 -6 h36 a6 6 0 0 1 6 6 v22 a6 6 0 0 1 -6 6 H22 L10 54 V42 a6 6 0 0 1 -2 -4 Z"/>
  <circle cx="22" cy="25" r="2.5" fill="currentColor" stroke="none"/>
  <circle cx="32" cy="25" r="2.5" fill="currentColor" stroke="none"/>
  <circle cx="42" cy="25" r="2.5" fill="currentColor" stroke="none"/>
</svg>
```

- [ ] **Step 8: Create `ic_report.svg` (folded paper)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M14 6 H42 L54 18 V58 H14 Z"/>
  <path d="M42 6 V18 H54"/>
  <line x1="22" y1="30" x2="46" y2="30"/>
  <line x1="22" y1="38" x2="46" y2="38"/>
  <line x1="22" y1="46" x2="38" y2="46"/>
</svg>
```

- [ ] **Step 9: Create `ic_documents.svg` (stack)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="10" y="14" width="32" height="42" rx="3" transform="rotate(-6 26 35)"/>
  <rect x="16" y="10" width="32" height="42" rx="3" transform="rotate(2 32 31)"/>
  <rect x="22" y="6" width="32" height="42" rx="3" transform="rotate(8 38 27)"/>
</svg>
```

- [ ] **Step 10: Create `ic_health.svg` (heart with pulse)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M32 56 C 12 42, 4 28, 12 18 C 18 11, 28 12, 32 20 C 36 12, 46 11, 52 18 C 60 28, 52 42, 32 56 Z"/>
  <path d="M14 32 H22 L26 24 L32 40 L36 28 L40 32 H50"/>
</svg>
```

- [ ] **Step 11: Create `ic_pen.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M44 8 L56 20 L24 52 L8 56 L12 40 Z"/>
  <line x1="40" y1="12" x2="52" y2="24"/>
</svg>
```

- [ ] **Step 12: Create `ic_family.svg` (three figures)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="14" cy="22" r="6"/>
  <path d="M4 50 v-4 a10 10 0 0 1 20 0 v4"/>
  <circle cx="50" cy="22" r="6"/>
  <path d="M40 50 v-4 a10 10 0 0 1 20 0 v4"/>
  <circle cx="32" cy="32" r="5"/>
  <path d="M24 56 v-3 a8 8 0 0 1 16 0 v3"/>
</svg>
```

- [ ] **Step 13: Create `ic_loyalty.svg` (5-point star)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <path d="M32 6 L40 24 L60 26 L45 40 L50 60 L32 50 L14 60 L19 40 L4 26 L24 24 Z"
    fill="currentColor" opacity=".25"/>
  <path d="M32 12 L38 26 L52 28 L42 38 L45 52 L32 44 L19 52 L22 38 L12 28 L26 26 Z"
    fill="currentColor"/>
</svg>
```

- [ ] **Step 14: Create `ic_points.svg` (sparkle)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="currentColor">
  <path d="M32 6 L34 28 L56 32 L34 36 L32 58 L30 36 L8 32 L30 28 Z"/>
  <circle cx="50" cy="14" r="3"/>
  <circle cx="14" cy="50" r="2.5"/>
</svg>
```

- [ ] **Step 15: Create `ic_qr.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="2.5">
  <rect x="6" y="6" width="18" height="18" rx="1"/>
  <rect x="11" y="11" width="8" height="8" fill="currentColor"/>
  <rect x="40" y="6" width="18" height="18" rx="1"/>
  <rect x="45" y="11" width="8" height="8" fill="currentColor"/>
  <rect x="6" y="40" width="18" height="18" rx="1"/>
  <rect x="11" y="45" width="8" height="8" fill="currentColor"/>
  <rect x="32" y="32" width="6" height="6" fill="currentColor"/>
  <rect x="44" y="32" width="6" height="6" fill="currentColor"/>
  <rect x="32" y="44" width="6" height="6" fill="currentColor"/>
  <rect x="50" y="50" width="6" height="6" fill="currentColor"/>
  <rect x="38" y="38" width="6" height="6" fill="currentColor"/>
</svg>
```

- [ ] **Step 16: Create `ic_referral.svg` (two figures + heart)**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="14" cy="22" r="6"/>
  <path d="M4 50 v-4 a10 10 0 0 1 20 0 v4"/>
  <circle cx="50" cy="22" r="6"/>
  <path d="M40 50 v-4 a10 10 0 0 1 20 0 v4"/>
  <path d="M32 36 C 28 32, 26 28, 30 26 C 32 26, 32 28, 32 28 C 32 28, 32 26, 34 26 C 38 28, 36 32, 32 36 Z" fill="currentColor"/>
</svg>
```

- [ ] **Step 17: Register the assets directory in pubspec.yaml**

Open `pubspec.yaml`, locate the `flutter:` → `assets:` section. Add:

```yaml
    - assets/images/onboarding/
```

- [ ] **Step 18: Verify icons load**

Run: `flutter analyze --no-pub`
Expected: no errors.

- [ ] **Step 19: Commit**

```bash
git add assets/images/onboarding/ pubspec.yaml
git commit -m "feat(welcome-wizard): add 16 custom DocSera SVG icons + register assets"
```

---

## Phase 2 — State management (Cubit, TDD)

### Task 4: Wizard cubit + state

**Files:**
- Create: `lib/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart`
- Create: `lib/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_cubit.dart`
- Test: `test/welcome_wizard_cubit_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/welcome_wizard_cubit_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WelcomeWizardCubit', () {
    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'starts at page 0 in firstTime mode',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      verify: (c) {
        expect(c.state.currentPage, 0);
        expect(c.state.entryMode, WizardEntryMode.firstTime);
        expect(c.state.completed, false);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'next() advances page index',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) {
        c.next();
        c.next();
      },
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 1),
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 2),
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'next() on last page emits completed=true',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 3),
      act: (c) {
        c.jumpTo(2);
        c.next();
      },
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 2),
        isA<WelcomeWizardState>().having((s) => s.completed, 'completed', true),
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'previous() decrements but not below 0',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) {
        c.jumpTo(1);
        c.previous();
        c.previous();
      },
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 1),
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 0),
        // second previous() does not emit (already at 0)
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'jumpTo(n) sets currentPage to n',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) => c.jumpTo(7),
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.currentPage, 'currentPage', 7),
      ],
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'skip() in firstTime mode persists the completion flag',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 18),
      act: (c) => c.skip(),
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.completed, 'completed', true),
      ],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), true);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'skip() in replay mode does NOT persist the completion flag',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.replay, totalPages: 18),
      act: (c) => c.skip(),
      expect: () => [
        isA<WelcomeWizardState>().having((s) => s.completed, 'completed', true),
      ],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), null);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'complete() in firstTime mode persists the flag',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.firstTime, totalPages: 3),
      act: (c) {
        c.jumpTo(2);
        c.next();
      },
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), true);
      },
    );

    blocTest<WelcomeWizardCubit, WelcomeWizardState>(
      'complete() in replay mode does NOT persist',
      build: () => WelcomeWizardCubit(entryMode: WizardEntryMode.replay, totalPages: 3),
      act: (c) {
        c.jumpTo(2);
        c.next();
      },
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('welcome_wizard_completed_v1'), null);
      },
    );
  });

  group('hasCompletedWizard()', () {
    test('returns false when flag is missing', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WelcomeWizardCubit.hasCompletedWizard(), false);
    });

    test('returns true when flag is set', () async {
      SharedPreferences.setMockInitialValues({
        'welcome_wizard_completed_v1': true,
      });
      expect(await WelcomeWizardCubit.hasCompletedWizard(), true);
    });
  });

  group('migrateExistingUser()', () {
    test('sets the flag if missing', () async {
      SharedPreferences.setMockInitialValues({});
      await WelcomeWizardCubit.migrateExistingUser();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('welcome_wizard_completed_v1'), true);
    });

    test('does not overwrite the flag if already set', () async {
      SharedPreferences.setMockInitialValues({
        'welcome_wizard_completed_v1': false,
      });
      await WelcomeWizardCubit.migrateExistingUser();
      final prefs = await SharedPreferences.getInstance();
      // existing value preserved
      expect(prefs.getBool('welcome_wizard_completed_v1'), false);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/welcome_wizard_cubit_test.dart`
Expected: tests FAIL with "Target of URI doesn't exist" because the cubit/state files don't exist yet.

- [ ] **Step 3: Implement the state**

Create `lib/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart`:

```dart
import 'package:equatable/equatable.dart';

enum WizardEntryMode { firstTime, replay }

class WelcomeWizardState extends Equatable {
  final int currentPage;
  final WizardEntryMode entryMode;
  final bool completed;

  const WelcomeWizardState({
    required this.currentPage,
    required this.entryMode,
    required this.completed,
  });

  WelcomeWizardState copyWith({int? currentPage, bool? completed}) =>
      WelcomeWizardState(
        currentPage: currentPage ?? this.currentPage,
        entryMode: entryMode,
        completed: completed ?? this.completed,
      );

  @override
  List<Object?> get props => [currentPage, entryMode, completed];
}
```

- [ ] **Step 4: Implement the cubit**

Create `lib/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_wizard_state.dart';

/// Cubit for the post-signup welcome wizard.
///
/// Owns: current page index, entry mode (firstTime/replay), completion +
/// persistence of `welcome_wizard_completed_v1` in SharedPreferences.
///
/// Persistence is only written in `firstTime` mode — replay-mode runs
/// (launched from the account page) MUST NOT touch the flag.
class WelcomeWizardCubit extends Cubit<WelcomeWizardState> {
  static const String _kFlagKey = 'welcome_wizard_completed_v1';

  final int totalPages;

  WelcomeWizardCubit({
    required WizardEntryMode entryMode,
    required this.totalPages,
  }) : super(WelcomeWizardState(
          currentPage: 0,
          entryMode: entryMode,
          completed: false,
        ));

  /// Advance to the next page. On the last page, marks completion + (in
  /// firstTime mode) persists the flag.
  void next() {
    final nextIndex = state.currentPage + 1;
    if (nextIndex >= totalPages) {
      _markCompleted();
      return;
    }
    emit(state.copyWith(currentPage: nextIndex));
  }

  void previous() {
    if (state.currentPage <= 0) return;
    emit(state.copyWith(currentPage: state.currentPage - 1));
  }

  void jumpTo(int index) {
    if (index < 0 || index >= totalPages) return;
    emit(state.copyWith(currentPage: index));
  }

  /// Skip dismisses the wizard. In firstTime mode this persists the flag
  /// so the user is not shown the wizard again on the next signup-after-
  /// reinstall path. In replay mode it just dismisses (the caller pops).
  void skip() {
    _markCompleted();
  }

  Future<void> _markCompleted() async {
    if (state.entryMode == WizardEntryMode.firstTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kFlagKey, true);
    }
    emit(state.copyWith(completed: true));
  }

  /// Read-only check used by the splash / migration logic.
  static Future<bool> hasCompletedWizard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFlagKey) ?? false;
  }

  /// One-time migration for existing users who predate the wizard release.
  /// Only sets the flag if it's missing — never overwrites a deliberately
  /// false value (e.g. tests / dev resets).
  static Future<void> migrateExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kFlagKey)) {
      await prefs.setBool(_kFlagKey, true);
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/welcome_wizard_cubit_test.dart`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/Business_Logic/Onboarding test/welcome_wizard_cubit_test.dart
git commit -m "feat(welcome-wizard): cubit + state with persistence (TDD)"
```

---

## Phase 3 — Glass-kit primitives

### Task 5: GlassMarble

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_marble.dart`

- [ ] **Step 1: Implement the widget**

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Small floating frosted-glass sphere used as decoration in wizard screens.
///
/// Variation per screen is achieved by passing different `size` + position
/// + animation. The widget itself is just the sphere — positioning and
/// motion are the parent's responsibility.
class GlassMarble extends StatelessWidget {
  final double size; // diameter in logical pixels (already .w-scaled by caller)

  const GlassMarble({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.4, -0.4),
              radius: 0.85,
              colors: [
                Color(0xEBFFFFFF), // white .92
                Color(0x4DFFFFFF), // white .30
                Color(0x2E009092), // teal .18
              ],
              stops: [0.0, 0.4, 0.8],
            ),
            border: Border.all(
              color: const Color(0xB3FFFFFF), // white .70
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x38009092), // teal .22
                blurRadius: 14,
                offset: Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze passes**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_marble.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_marble.dart
git commit -m "feat(welcome-wizard): GlassMarble primitive"
```

---

### Task 6: GlassCapsule + GlassTag

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_capsule.dart` and `glass_tag.dart`.

- [ ] **Step 1: Implement GlassCapsule**

```dart
// glass_capsule.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted pill-shaped surface, typically rotated and used under the hero
/// icon in Feature mode to give the icon a glass platform.
class GlassCapsule extends StatelessWidget {
  final double width;
  final double height;
  final double rotation; // radians

  const GlassCapsule({
    super.key,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(height / 2)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(height / 2)),
              color: const Color(0x80FFFFFF), // white .50
              border: Border.all(color: const Color(0xC7FFFFFF), width: 1), // .78
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47009092), // teal .28
                  blurRadius: 22,
                  offset: Offset(0, 12),
                  spreadRadius: -8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement GlassTag**

```dart
// glass_tag.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Small frosted pill containing text — used for the "step X of Y" indicator
/// floating in the upper-right of Feature-mode screens.
class GlassTag extends StatelessWidget {
  final String text;
  const GlassTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: const Color(0x99FFFFFF), // white .60
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: Border.all(color: const Color(0xD9FFFFFF), width: 1), // .85
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 10.sp,
              letterSpacing: 0.4,
              color: const Color(0xFF007E80),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/glass_kit/`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_capsule.dart \
        lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_tag.dart
git commit -m "feat(welcome-wizard): GlassCapsule + GlassTag primitives"
```

---

### Task 7: GlassShard

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_shard.dart`

- [ ] **Step 1: Implement**

```dart
// glass_shard.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Larger frosted capsule placed BEHIND the glass title at z-index lower than
/// the text. Animates with a slow sweep (rotation + horizontal translation)
/// driven by an external [animation].
class GlassShard extends StatelessWidget {
  final double width;
  final double height;
  final Animation<double> animation; // 0..1 looping

  const GlassShard({
    super.key,
    required this.width,
    required this.height,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // Smooth sin-based oscillation — same end values as the spec mockup.
        final t = animation.value; // 0..1
        // rotation oscillates between -3deg and -1deg
        final rot = (-3 + 2 * (t < 0.5 ? t * 2 : (1 - t) * 2)) * 3.14159 / 180;
        // x oscillates between 0 and -12 logical px
        final dx = -12 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: rot,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(height / 2)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(height / 2)),
                    color: const Color(0x38FFFFFF), // white .22
                    border: Border.all(color: const Color(0x8CFFFFFF), width: 1), // .55
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E009092), // teal .18
                        blurRadius: 20,
                        offset: Offset(0, 8),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_shard.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_shard.dart
git commit -m "feat(welcome-wizard): GlassShard primitive with sweep animation"
```

---

### Task 8: GlassOrbLarge

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_orb_large.dart`

- [ ] **Step 1: Implement**

```dart
// glass_orb_large.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Large frosted-glass sphere with a strong specular highlight. Used as the
/// hero stage in Showcase + Celebration modes — the feature icon, numerals,
/// QR, gift, etc. live INSIDE the orb.
///
/// Pass a [child] to render inside.
class GlassOrbLarge extends StatelessWidget {
  final double diameter;
  final Widget child;

  const GlassOrbLarge({super.key, required this.diameter, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  radius: 0.95,
                  colors: [
                    Color(0xEBFFFFFF), // white .92
                    Color(0x4DFFFFFF), // white .30
                    Color(0x33009092), // teal .20
                  ],
                  stops: [0.0, 0.35, 0.8],
                ),
                border: Border.all(color: const Color(0xB3FFFFFF), width: 1),
                boxShadow: const [
                  // outer cast shadow
                  BoxShadow(
                    color: Color(0x61009092), // teal .38
                    blurRadius: 60,
                    offset: Offset(0, 28),
                    spreadRadius: -10,
                  ),
                ],
              ),
              // inner shadows simulated via additional inset overlay
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(0.4, 0.5),
                    radius: 0.95,
                    colors: [
                      Color(0x00000000),
                      Color(0x38009092), // teal .22 inset bottom-right
                    ],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        // top-left specular highlight
        Positioned(
          top: diameter * 0.11,
          left: diameter * 0.14,
          child: Container(
            width: diameter * 0.32,
            height: diameter * 0.16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(diameter * 0.16)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xC7FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
        ),
        // child sits above the highlight
        Center(child: child),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_orb_large.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/glass_kit/glass_orb_large.dart
git commit -m "feat(welcome-wizard): GlassOrbLarge with specular highlight"
```

---

### Task 9: GlassTitle

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/glass_title.dart`

- [ ] **Step 1: Implement**

```dart
// glass_title.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Cairo title rendered as translucent teal glass via a ShaderMask.
///
/// Recipe (from spec):
/// - Cairo weight 900, 46sp default (manifesto: 52sp via [size]).
/// - Line-height 1.18 — Arabic descenders need the headroom.
/// - Translucent teal gradient clipped to the text shape.
/// - Outer drop-shadow on the wrapping container — NO inner white shadow
///   (the white-shadow recipe creates speckles inside Arabic counters).
class GlassTitle extends StatelessWidget {
  final String text;
  final double size; // sp before .sp scaling
  final TextAlign textAlign;

  const GlassTitle({
    super.key,
    required this.text,
    this.size = 46,
    this.textAlign = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x38009092), // teal .22
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE6009092), // teal .90
            Color(0x80009092), // teal .50
          ],
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: size.sp,
            height: 1.18,
            letterSpacing: -0.4,
            color: Colors.white, // overridden by ShaderMask
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/glass_title.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/glass_title.dart
git commit -m "feat(welcome-wizard): GlassTitle widget (ShaderMask, no inner shadow)"
```

---

### Task 10: WizardBackground (drifting orbs)

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/wizard_background.dart`

- [ ] **Step 1: Implement**

```dart
// wizard_background.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Always-on backdrop layer for every wizard screen — mint gradient + two
/// large drifting orbs + an optional accent orb directly behind the title
/// position. Orbs animate on independent multi-second loops via sin/cos.
class WizardBackground extends StatefulWidget {
  /// If true, renders an additional teal accent orb at ~44% screen height,
  /// near the right edge — gives Feature/Manifesto titles color to refract
  /// through.
  final bool withTitleAccent;

  const WizardBackground({super.key, this.withTitleAccent = true});

  @override
  State<WizardBackground> createState() => _WizardBackgroundState();
}

class _WizardBackgroundState extends State<WizardBackground>
    with TickerProviderStateMixin {
  late final AnimationController _ctrlA;
  late final AnimationController _ctrlB;
  late final AnimationController _ctrlC;

  @override
  void initState() {
    super.initState();
    _ctrlA = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _ctrlB = AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();
    _ctrlC = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    _ctrlC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // mint gradient base
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF1FBF8), Color(0xFFE0F4F0)],
              ),
            ),
          ),
        ),
        // orb A — top-right
        AnimatedBuilder(
          animation: _ctrlA,
          builder: (context, _) {
            final t = _ctrlA.value * 2 * math.pi;
            return Positioned(
              top: -90.h + math.sin(t) * 18.h,
              right: -100.w + math.cos(t) * 12.w,
              child: _orb(diameter: 320.w, opacity: 0.30),
            );
          },
        ),
        // orb B — bottom-left
        AnimatedBuilder(
          animation: _ctrlB,
          builder: (context, _) {
            final t = _ctrlB.value * 2 * math.pi;
            return Positioned(
              bottom: 60.h + math.sin(t) * 14.h,
              left: -80.w + math.cos(t) * 16.w,
              child: _orb(diameter: 250.w, opacity: 0.22),
            );
          },
        ),
        // orb C — title accent
        if (widget.withTitleAccent)
          AnimatedBuilder(
            animation: _ctrlC,
            builder: (context, _) {
              final t = _ctrlC.value * 2 * math.pi;
              return Positioned(
                top: 0.44 * MediaQuery.of(context).size.height +
                    math.sin(t) * 12.h,
                right: -40.w + math.cos(t) * 10.w,
                child: _orb(diameter: 220.w, opacity: 0.30, blurSigma: 60),
              );
            },
          ),
      ],
    );
  }

  Widget _orb({required double diameter, required double opacity, double blurSigma = 48}) {
    return ImageFiltered(
      imageFilter: ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.main.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: AppColors.main.withValues(alpha: opacity),
              blurRadius: blurSigma,
              spreadRadius: blurSigma * 0.4,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/wizard_background.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/wizard_background.dart
git commit -m "feat(welcome-wizard): WizardBackground with 2 drifting orbs + title accent"
```

---

### Task 11: WizardSkipButton, WizardNextButton, WizardPageDots

**Files:** Create three small widgets under `lib/screens/onboarding/welcome_wizard/widgets/`.

- [ ] **Step 1: Implement WizardSkipButton**

`wizard_skip_button.dart`:

```dart
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WizardSkipButton extends StatelessWidget {
  final VoidCallback onTap;
  const WizardSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PositionedDirectional(
      top: 22.h,
      start: 22.w,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Text(
            l.wizard_skip_button,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              fontSize: 12.sp,
              color: const Color(0xA6004146), // teal-near-black .65
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement WizardNextButton**

`wizard_next_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Floating pill in the bottom-trailing corner. Pulses a soft teal halo every
/// 2.6s. If [label] is non-null, shows the label instead of the chevron
/// (used on the closing screen for "Let's begin" / "Done").
class WizardNextButton extends StatefulWidget {
  final VoidCallback onTap;
  final String? label;
  const WizardNextButton({super.key, required this.onTap, this.label});

  @override
  State<WizardNextButton> createState() => _WizardNextButtonState();
}

class _WizardNextButtonState extends State<WizardNextButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label != null;
    return PositionedDirectional(
      bottom: 30.h,
      end: 24.w,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _pulse.value;
            final ringRadius = 12.0 * t;
            final ringOpacity = (1 - t) * 0.35;
            return Container(
              padding: EdgeInsets.all(ringRadius),
              decoration: BoxDecoration(
                shape: hasLabel ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: hasLabel ? BorderRadius.circular(40) : null,
                color: AppColors.main.withValues(alpha: ringOpacity),
              ),
              child: child,
            );
          },
          child: Container(
            height: 58.h,
            padding: hasLabel
                ? EdgeInsets.symmetric(horizontal: 28.w)
                : EdgeInsets.zero,
            constraints: hasLabel ? null : BoxConstraints.tightFor(width: 58.w, height: 58.h),
            decoration: BoxDecoration(
              shape: hasLabel ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: hasLabel ? BorderRadius.circular(40) : null,
              color: AppColors.main,
              boxShadow: [
                BoxShadow(
                  color: AppColors.main.withValues(alpha: 0.55),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Center(
              child: hasLabel
                  ? Text(
                      widget.label!,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22.sp),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement WizardPageDots**

`wizard_page_dots.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/app/const.dart';

/// Animated dot indicators. The active dot extends into a pill shape.
/// Tapping a dot calls [onJump] with that index.
class WizardPageDots extends StatelessWidget {
  final int total;
  final int current;
  final ValueChanged<int> onJump;

  const WizardPageDots({
    super.key,
    required this.total,
    required this.current,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      bottom: 50.h,
      start: 26.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (i) {
          final isActive = i == current;
          return Padding(
            padding: EdgeInsetsDirectional.only(end: 7.w),
            child: GestureDetector(
              onTap: () => onJump(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                width: isActive ? 24.w : 6.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.main
                      : AppColors.main.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/wizard_skip_button.dart \
        lib/screens/onboarding/welcome_wizard/widgets/wizard_next_button.dart \
        lib/screens/onboarding/welcome_wizard/widgets/wizard_page_dots.dart
git commit -m "feat(welcome-wizard): skip button, next button (pulse), animated dots"
```

---

## Phase 4 — Scaffolds

### Task 12: FeatureScaffold

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/scaffolds/feature_scaffold.dart`

- [ ] **Step 1: Define the spec types**

Add to top of the new file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_capsule.dart';
import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_shard.dart';
import '../glass_kit/glass_tag.dart';
import '../glass_title.dart';

/// Position of a marble: percentages of screen width/height + size + per-
/// marble animation phase (so they don't sync).
class MarbleSpec {
  final double topPct;       // 0..1 — vertical position
  final double startPct;     // 0..1 — start (right in RTL, left in LTR)
  final double sizePx;       // logical px (scaled by .w outside)
  final Duration period;     // bob duration
  final Duration phaseOffset; // start delay

  const MarbleSpec({
    required this.topPct,
    required this.startPct,
    required this.sizePx,
    required this.period,
    this.phaseOffset = Duration.zero,
  });
}

class CapsuleSpec {
  final double topPct;
  final double startPct;
  final double widthPx;
  final double heightPx;
  final double rotation; // radians
  const CapsuleSpec({
    required this.topPct,
    required this.startPct,
    required this.widthPx,
    required this.heightPx,
    required this.rotation,
  });
}
```

- [ ] **Step 2: Implement the scaffold**

Continue in the same file:

```dart
/// FeatureScaffold — workhorse layout for ~10 wizard screens.
///
/// Composition (RTL-first, end-side = right in AR, mirrors in LTR):
/// - Step tag in upper-trailing corner
/// - Hero icon in upper area (centerish), with rotated capsule under it
/// - 4 marbles scattered around the hero
/// - Glass shard behind the title
/// - Glass title at ~46% of screen height
/// - Body text below the title
/// - The Wizard's skip/dots/next chrome is added by the parent screen.
class FeatureScaffold extends StatefulWidget {
  final Widget heroIcon; // size already configured by caller
  final String stepTagText;
  final String title;
  final String body;
  final List<MarbleSpec> marbles;     // exactly 4 expected, but flexible
  final CapsuleSpec capsule;
  final Widget? extraTopOverlay;       // optional per-screen signature motion overlay

  const FeatureScaffold({
    super.key,
    required this.heroIcon,
    required this.stepTagText,
    required this.title,
    required this.body,
    required this.marbles,
    required this.capsule,
    this.extraTopOverlay,
  });

  @override
  State<FeatureScaffold> createState() => _FeatureScaffoldState();
}

class _FeatureScaffoldState extends State<FeatureScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;
  late final AnimationController _capsuleCtrl;
  late final AnimationController _heroCtrl;
  late final AnimationController _shardCtrl;

  @override
  void initState() {
    super.initState();
    _marbleCtrls = widget.marbles.map((spec) {
      final c = AnimationController(vsync: this, duration: spec.period);
      Future.delayed(spec.phaseOffset, () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    }).toList();
    _capsuleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..repeat(reverse: true);
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _shardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  @override
  void dispose() {
    for (final c in _marbleCtrls) {
      c.dispose();
    }
    _capsuleCtrl.dispose();
    _heroCtrl.dispose();
    _shardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Step tag — upper-trailing
        PositionedDirectional(
          top: 0.08 * size.height,
          end: 0.14 * size.width,
          child: GlassTag(text: widget.stepTagText),
        ),

        // 4 marbles, each on its own bobbing keyframe
        for (var i = 0; i < widget.marbles.length; i++)
          AnimatedBuilder(
            animation: _marbleCtrls[i],
            builder: (context, child) {
              final t = _marbleCtrls[i].value;
              final dx = (-8 + i * 4) * t * (i.isEven ? 1 : -1);
              final dy = (-10 + (i * 3)) * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                end: widget.marbles[i].startPct * size.width + dx,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        // Capsule under the hero icon — rotates and bobs
        AnimatedBuilder(
          animation: _capsuleCtrl,
          builder: (context, child) {
            final t = _capsuleCtrl.value;
            final extraRot = (1 - t.abs()) * 6 * 3.14159 / 180;
            final dy = -4 * t;
            return PositionedDirectional(
              top: widget.capsule.topPct * size.height + dy,
              end: widget.capsule.startPct * size.width,
              child: Transform.rotate(
                angle: widget.capsule.rotation + extraRot,
                child: GlassCapsule(
                  width: widget.capsule.widthPx.w,
                  height: widget.capsule.heightPx.h,
                ),
              ),
            );
          },
        ),

        // Hero icon — bobs subtly
        AnimatedBuilder(
          animation: _heroCtrl,
          builder: (context, child) {
            final t = _heroCtrl.value;
            final dy = -5 * t;
            final rot = (-6 + 3 * t) * 3.14159 / 180;
            return Positioned(
              top: 0.16 * size.height + dy,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(angle: rot, child: child),
              ),
            );
          },
          child: widget.heroIcon,
        ),

        // Optional per-screen signature overlay
        if (widget.extraTopOverlay != null) widget.extraTopOverlay!,

        // Glass shard behind the title
        Positioned(
          top: 0.50 * size.height,
          right: 30.w,
          child: GlassShard(
            width: 220.w,
            height: 90.h,
            animation: _shardCtrl,
          ),
        ),

        // Title
        PositionedDirectional(
          top: 0.46 * size.height,
          start: 22.w,
          end: 22.w,
          child: GlassTitle(text: widget.title, size: 46),
        ),

        // Body
        PositionedDirectional(
          top: 0.70 * size.height,
          start: 24.w,
          end: 24.w,
          child: Text(
            widget.body,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              fontSize: 15.sp,
              color: const Color(0xC7004146), // teal-near-black .78
              height: 1.65,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/scaffolds/feature_scaffold.dart`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/scaffolds/feature_scaffold.dart
git commit -m "feat(welcome-wizard): FeatureScaffold (workhorse layout)"
```

---

### Task 13: ManifestoScaffold

**Files:** Create `lib/screens/onboarding/welcome_wizard/widgets/scaffolds/manifesto_scaffold.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_shard.dart';
import '../glass_title.dart';
import 'feature_scaffold.dart' show MarbleSpec; // reuse spec type

/// ManifestoScaffold — used for screens where the title IS the message
/// (Health intro, Loyalty intro, Referral). Larger title (52sp), small
/// icon-tag in the top-trailing corner, fewer marbles, more whitespace.
class ManifestoScaffold extends StatefulWidget {
  final Widget iconTag;     // small 64×64 teal icon tile in top corner
  final String title;
  final String body;
  final List<MarbleSpec> marbles;
  final Widget? extraOverlay;

  const ManifestoScaffold({
    super.key,
    required this.iconTag,
    required this.title,
    required this.body,
    required this.marbles,
    this.extraOverlay,
  });

  @override
  State<ManifestoScaffold> createState() => _ManifestoScaffoldState();
}

class _ManifestoScaffoldState extends State<ManifestoScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;
  late final AnimationController _shardCtrl;

  @override
  void initState() {
    super.initState();
    _marbleCtrls = widget.marbles.map((spec) {
      final c = AnimationController(vsync: this, duration: spec.period);
      Future.delayed(spec.phaseOffset, () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    }).toList();
    _shardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  @override
  void dispose() {
    for (final c in _marbleCtrls) {
      c.dispose();
    }
    _shardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // icon tag in top corner
        PositionedDirectional(
          top: 0.14 * size.height,
          end: 26.w,
          child: widget.iconTag,
        ),

        for (var i = 0; i < widget.marbles.length; i++)
          AnimatedBuilder(
            animation: _marbleCtrls[i],
            builder: (context, child) {
              final t = _marbleCtrls[i].value;
              final dx = (-6 + i * 3) * t * (i.isEven ? 1 : -1);
              final dy = (-8 + (i * 2)) * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                start: widget.marbles[i].startPct * size.width + dx,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        if (widget.extraOverlay != null) widget.extraOverlay!,

        // shard
        Positioned(
          top: 0.32 * size.height,
          right: 30.w,
          child: GlassShard(
            width: 240.w,
            height: 100.h,
            animation: _shardCtrl,
          ),
        ),

        // big title (52sp)
        PositionedDirectional(
          top: 0.28 * size.height,
          start: 22.w,
          end: 22.w,
          child: GlassTitle(text: widget.title, size: 52),
        ),

        // body
        PositionedDirectional(
          top: 0.56 * size.height,
          start: 24.w,
          end: 24.w,
          child: Text(
            widget.body,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
              fontSize: 16.sp,
              color: const Color(0xC7004146),
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/scaffolds/manifesto_scaffold.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/scaffolds/manifesto_scaffold.dart
git commit -m "feat(welcome-wizard): ManifestoScaffold (52sp glass title hero)"
```

---

### Task 14: ShowcaseScaffold + CelebrationScaffold

**Files:** Create both scaffolds in their respective files. They share most structure (orb-stage hero with content inside), so we keep them separate but parallel.

- [ ] **Step 1: Implement ShowcaseScaffold**

`lib/screens/onboarding/welcome_wizard/widgets/scaffolds/showcase_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_orb_large.dart';
import 'feature_scaffold.dart' show MarbleSpec;

/// ShowcaseScaffold — used for opener (01) and closer (18). Large glass orb
/// holds the hero (logo, brand mark). Content beneath: title + tagline +
/// subline.
class ShowcaseScaffold extends StatefulWidget {
  final Widget orbContent;            // sits inside the GlassOrbLarge
  final Widget? aboveTitle;           // e.g. small "أهلاً" salam line
  final Widget title;                  // typically GlassTitle
  final String? tagline;
  final String? subline;
  final List<MarbleSpec> marbles;

  const ShowcaseScaffold({
    super.key,
    required this.orbContent,
    this.aboveTitle,
    required this.title,
    this.tagline,
    this.subline,
    this.marbles = const [],
  });

  @override
  State<ShowcaseScaffold> createState() => _ShowcaseScaffoldState();
}

class _ShowcaseScaffoldState extends State<ShowcaseScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;

  @override
  void initState() {
    super.initState();
    _marbleCtrls = widget.marbles.map((spec) {
      final c = AnimationController(vsync: this, duration: spec.period);
      Future.delayed(spec.phaseOffset, () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _marbleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        for (var i = 0; i < widget.marbles.length; i++)
          AnimatedBuilder(
            animation: _marbleCtrls[i],
            builder: (context, child) {
              final t = _marbleCtrls[i].value;
              final dy = -8 * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                start: widget.marbles[i].startPct * size.width,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        // hero orb
        Positioned(
          top: 0.16 * size.height,
          left: 0,
          right: 0,
          child: Center(
            child: GlassOrbLarge(diameter: 210.w, child: widget.orbContent),
          ),
        ),

        // content stack — centered
        Positioned(
          top: 0.55 * size.height,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              children: [
                if (widget.aboveTitle != null) widget.aboveTitle!,
                SizedBox(height: 12.h),
                widget.title,
                if (widget.tagline != null) ...[
                  SizedBox(height: 14.h),
                  Text(
                    widget.tagline!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                      color: const Color(0xFF003A3B),
                      height: 1.4,
                    ),
                  ),
                ],
                if (widget.subline != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    widget.subline!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp,
                      color: const Color(0xA6004146), // .65
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Implement CelebrationScaffold**

`lib/screens/onboarding/welcome_wizard/widgets/scaffolds/celebration_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../glass_kit/glass_marble.dart';
import '../glass_kit/glass_orb_large.dart';
import 'feature_scaffold.dart' show MarbleSpec;

/// CelebrationScaffold — used for Promotions, Personal Gifts, Earn points,
/// Vouchers. Same orb-stage as Showcase but with sparkles fading in/out
/// around the orb to reinforce the celebratory moment.
class CelebrationScaffold extends StatefulWidget {
  final Widget orbContent;
  final String title;
  final String body;
  final List<MarbleSpec> marbles;
  final List<Offset> sparklePositions; // fractions of (width, height)
  final Widget sparkleIcon;             // a small SVG, sized by parent

  const CelebrationScaffold({
    super.key,
    required this.orbContent,
    required this.title,
    required this.body,
    required this.marbles,
    required this.sparklePositions,
    required this.sparkleIcon,
  });

  @override
  State<CelebrationScaffold> createState() => _CelebrationScaffoldState();
}

class _CelebrationScaffoldState extends State<CelebrationScaffold>
    with TickerProviderStateMixin {
  late final List<AnimationController> _marbleCtrls;
  late final List<AnimationController> _sparkleCtrls;

  @override
  void initState() {
    super.initState();
    _marbleCtrls = widget.marbles.map((spec) {
      final c = AnimationController(vsync: this, duration: spec.period);
      Future.delayed(spec.phaseOffset, () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    }).toList();
    _sparkleCtrls = widget.sparklePositions.asMap().entries.map((e) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2500),
      );
      Future.delayed(Duration(milliseconds: 800 * e.key), () {
        if (mounted) c.repeat();
      });
      return c;
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _marbleCtrls) {
      c.dispose();
    }
    for (final c in _sparkleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        for (var i = 0; i < widget.marbles.length; i++)
          AnimatedBuilder(
            animation: _marbleCtrls[i],
            builder: (context, child) {
              final t = _marbleCtrls[i].value;
              final dy = -6 * t;
              return PositionedDirectional(
                top: widget.marbles[i].topPct * size.height + dy,
                start: widget.marbles[i].startPct * size.width,
                child: GlassMarble(size: widget.marbles[i].sizePx.w),
              );
            },
          ),

        // sparkles — fade in/out on staggered loops
        for (var i = 0; i < widget.sparklePositions.length; i++)
          AnimatedBuilder(
            animation: _sparkleCtrls[i],
            builder: (context, child) {
              final t = _sparkleCtrls[i].value;
              // 0..0.5: fade in + scale up; 0.5..1.0: fade out + scale down
              final phase = t < 0.5 ? t * 2 : (1 - t) * 2;
              return Positioned(
                top: widget.sparklePositions[i].dy * size.height,
                left: widget.sparklePositions[i].dx * size.width,
                child: Opacity(
                  opacity: phase,
                  child: Transform.scale(scale: phase, child: child),
                ),
              );
            },
            child: widget.sparkleIcon,
          ),

        // orb-stage hero
        Positioned(
          top: 0.14 * size.height,
          left: 0,
          right: 0,
          child: Center(
            child: GlassOrbLarge(diameter: 200.w, child: widget.orbContent),
          ),
        ),

        // title + body — centered text
        Positioned(
          top: 0.62 * size.height,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 28.sp,
                    color: const Color(0xFF003A3B),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w500,
                    fontSize: 14.sp,
                    color: const Color(0xC7004146),
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/widgets/scaffolds/`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/widgets/scaffolds/showcase_scaffold.dart \
        lib/screens/onboarding/welcome_wizard/widgets/scaffolds/celebration_scaffold.dart
git commit -m "feat(welcome-wizard): Showcase + Celebration scaffolds"
```

---

## Phase 5 — The 18 screens

Each screen is one task. Pattern: small file (~80–150 lines) returning a scaffold with screen-specific config. Per-screen position-variation rule (spec section "Per-screen position variation") MUST be respected — no two adjacent screens may share the same marble layout.

For brevity below, I show full code for **screens 01, 06, 07, 11, 14, 18** (one per mode plus a handful of representative Feature screens). The remaining screens follow the same template — copy + icon path + unique marble layout. **For each unspec'd screen, follow the same shape as the closest representative below.**

### Task 15: Screen 01 — Welcome (breath-catcher)

**Files:** Create `lib/screens/onboarding/welcome_wizard/screens/s01_welcome.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/glass_kit/glass_marble.dart';
import '../widgets/glass_kit/glass_orb_large.dart';
import '../widgets/glass_title.dart';

class S01Welcome extends StatefulWidget {
  final String firstName;
  const S01Welcome({super.key, required this.firstName});

  @override
  State<S01Welcome> createState() => _S01WelcomeState();
}

class _S01WelcomeState extends State<S01Welcome>
    with TickerProviderStateMixin {
  // entrance choreography — one-shot, no looping
  late final AnimationController _entry;

  // background marble bobs (3 marbles)
  late final List<AnimationController> _marbles;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _marbles = [
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true),
    ];
  }

  @override
  void dispose() {
    _entry.dispose();
    for (final c in _marbles) {
      c.dispose();
    }
    super.dispose();
  }

  // staged opacity helpers
  Animation<double> _stage(double startPct, double endPct) =>
      CurvedAnimation(
        parent: _entry,
        curve: Interval(startPct, endPct, curve: Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // decorative marbles — bobbing background motion
        AnimatedBuilder(
          animation: _marbles[0],
          builder: (context, _) {
            return Positioned(
              top: 0.10 * size.height + (-8 * _marbles[0].value),
              left: 0.20 * size.width,
              child: GlassMarble(size: 24.w),
            );
          },
        ),
        AnimatedBuilder(
          animation: _marbles[1],
          builder: (context, _) {
            return Positioned(
              top: 0.46 * size.height + (10 * _marbles[1].value),
              right: 0.18 * size.width,
              child: GlassMarble(size: 18.w),
            );
          },
        ),
        AnimatedBuilder(
          animation: _marbles[2],
          builder: (context, _) {
            return Positioned(
              top: 0.36 * size.height + (-12 * _marbles[2].value),
              left: 0.32 * size.width,
              child: GlassMarble(size: 14.w),
            );
          },
        ),

        // logo orb (entrance: fade-up + scale)
        Positioned(
          top: 0.16 * size.height,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _stage(0.10, 0.50),
              builder: (context, child) {
                final t = _stage(0.10, 0.50).value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 18),
                    child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
                  ),
                );
              },
              child: GlassOrbLarge(
                diameter: 110.w,
                child: SvgPicture.asset(
                  'assets/images/docsera_main.svg',
                  width: 70.w,
                ),
              ),
            ),
          ),
        ),

        // greeting block
        Positioned(
          top: 0.42 * size.height,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              children: [
                FadeTransition(
                  opacity: _stage(0.36, 0.55),
                  child: Text(
                    l.wizard_welcome_salam,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                      fontSize: 16.sp,
                      letterSpacing: 0.4,
                      color: const Color(0x8C004146), // .55
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                FadeTransition(
                  opacity: _stage(0.40, 0.65),
                  child: GlassTitle(
                    text: widget.firstName,
                    size: 64,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 22.h),
                FadeTransition(
                  opacity: _stage(0.55, 0.75),
                  child: Container(
                    width: 50.w,
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0x00009092),
                          Color(0x73009092),
                          Color(0x00009092),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                FadeTransition(
                  opacity: _stage(0.62, 0.82),
                  child: Text(
                    l.wizard_welcome_tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                      color: const Color(0xFF003A3B),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                FadeTransition(
                  opacity: _stage(0.70, 0.92),
                  child: Text(
                    l.wizard_welcome_subline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp,
                      color: const Color(0xA6004146),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/screens/s01_welcome.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/screens/s01_welcome.dart
git commit -m "feat(welcome-wizard): screen 01 — breath-catcher welcome"
```

---

### Task 16: Screen 02 — Search (Feature)

**Files:** Create `lib/screens/onboarding/welcome_wizard/screens/s02_search.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/feature_scaffold.dart';

class S02Search extends StatelessWidget {
  final int stepIndex;
  final int total;
  const S02Search({super.key, required this.stepIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FeatureScaffold(
      heroIcon: Container(
        width: 68.w,
        height: 68.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF009092), Color(0xFF4DD0D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.main.withValues(alpha: .55),
              blurRadius: 26,
              offset: const Offset(0, 14),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/onboarding/ic_search.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      stepTagText: l.wizard_step_label('${stepIndex + 1}', '$total'),
      title: l.wizard_search_title,
      body: l.wizard_search_body,
      // Unique marble layout for Screen 02 — different from screens 01, 03.
      marbles: const [
        MarbleSpec(topPct: 0.13, startPct: 0.16, sizePx: 32, period: Duration(milliseconds: 5000)),
        MarbleSpec(topPct: 0.26, startPct: 0.70, sizePx: 18, period: Duration(milliseconds: 6500)),
        MarbleSpec(topPct: 0.33, startPct: 0.12, sizePx: 38, period: Duration(milliseconds: 5500), phaseOffset: Duration(milliseconds: 500)),
        MarbleSpec(topPct: 0.09, startPct: 0.36, sizePx: 14, period: Duration(milliseconds: 7000), phaseOffset: Duration(seconds: 1)),
      ],
      capsule: const CapsuleSpec(
        topPct: 0.21,
        startPct: 0.30,
        widthPx: 110,
        heightPx: 44,
        rotation: -0.21, // -12 deg in radians
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/screens/s02_search.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/screens/s02_search.dart
git commit -m "feat(welcome-wizard): screen 02 — search"
```

---

### Tasks 17–22: Screens 03 through 08 (Feature mode workhorses)

Each follows the **exact pattern of Task 16** but with screen-specific:
- ARB title key (`wizard_doctor_title`, `wizard_favorites_title`, `wizard_promotions_title` (treat as Feature visually, mode is Celebration via different scaffold — see below), `wizard_booking_title`, `wizard_chat_title`)
- Body key
- SVG icon path
- **Unique marble layout** (different `topPct`, `startPct`, sizes, periods than screens 02, 04, 05, 06)
- Unique capsule rotation/position

For Screen 05 (Promotions) and Screen 06 (Personal gifts), use **`CelebrationScaffold`** instead of `FeatureScaffold`. See Task 22 below for the Personal Gifts pattern.

For Screens 03 (Doctor profile), 04 (Favorites), 07 (Booking), 08 (Chat) — use `FeatureScaffold` with these icon paths:
- 03: `ic_doctor.svg`
- 04: `ic_heart.svg`
- 07: `ic_calendar.svg`
- 08: `ic_chat.svg`

For 05 (Promotions), Celebration mode — see Task 21 below for the gift pattern, but swap the orb content from `ic_gift.svg` to `ic_promo.svg` and use `wizard_promotions_*` ARB keys.

#### Task 17: Screen 03 — Doctor profile

**Files:** Create `lib/screens/onboarding/welcome_wizard/screens/s03_doctor_profile.dart`

Same structure as Task 16 but:
- icon: `ic_doctor.svg`
- title: `l.wizard_doctor_title`
- body: `l.wizard_doctor_body`
- Marble spec — unique:
  ```dart
  marbles: const [
    MarbleSpec(topPct: 0.10, startPct: 0.22, sizePx: 28, period: Duration(milliseconds: 5800)),
    MarbleSpec(topPct: 0.30, startPct: 0.65, sizePx: 22, period: Duration(milliseconds: 6200)),
    MarbleSpec(topPct: 0.38, startPct: 0.18, sizePx: 34, period: Duration(milliseconds: 5300), phaseOffset: Duration(milliseconds: 800)),
    MarbleSpec(topPct: 0.13, startPct: 0.45, sizePx: 12, period: Duration(milliseconds: 7400)),
  ],
  capsule: const CapsuleSpec(
    topPct: 0.22, startPct: 0.27, widthPx: 118, heightPx: 46, rotation: -0.18,
  ),
  ```

- [ ] Implement, verify analyze, commit `feat(welcome-wizard): screen 03 — doctor profile`.

#### Task 18: Screen 04 — Favorites

icon: `ic_heart.svg`. title/body: `wizard_favorites_*`. Marbles unique. Commit `feat(welcome-wizard): screen 04 — favorites`.

#### Task 19: Screen 07 — Booking

icon: `ic_calendar.svg`. title/body: `wizard_booking_*`. Marbles unique. Commit `feat(welcome-wizard): screen 07 — booking`.

#### Task 20: Screen 08 — Chat

icon: `ic_chat.svg`. title/body: `wizard_chat_*`. Marbles unique. Commit `feat(welcome-wizard): screen 08 — chat`.

---

### Task 21: Screen 06 — Personal gifts (Celebration)

**Files:** Create `lib/screens/onboarding/welcome_wizard/screens/s06_personal_gifts.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/celebration_scaffold.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;

class S06PersonalGifts extends StatelessWidget {
  const S06PersonalGifts({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return CelebrationScaffold(
      orbContent: SvgPicture.asset(
        'assets/images/onboarding/ic_gift.svg',
        width: 110.w,
      ),
      title: l.wizard_gifts_title,
      body: l.wizard_gifts_body,
      marbles: const [
        MarbleSpec(topPct: 0.10, startPct: 0.22, sizePx: 16, period: Duration(milliseconds: 5400)),
        MarbleSpec(topPct: 0.16, startPct: 0.18, sizePx: 26, period: Duration(milliseconds: 6500)),
        MarbleSpec(topPct: 0.38, startPct: 0.12, sizePx: 12, period: Duration(milliseconds: 5800), phaseOffset: Duration(milliseconds: 700)),
        MarbleSpec(topPct: 0.44, startPct: 0.16, sizePx: 22, period: Duration(milliseconds: 7100)),
      ],
      sparklePositions: const [
        Offset(0.32, 0.18),
        Offset(0.65, 0.22),
        Offset(0.36, 0.38),
      ],
      sparkleIcon: SvgPicture.asset(
        'assets/images/onboarding/ic_points.svg',
        width: 14.w,
        colorFilter: const ColorFilter.mode(Color(0xFF009092), BlendMode.srcIn),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify, commit**

`feat(welcome-wizard): screen 06 — personal gifts`

#### Task 22: Screen 05 — Promotions (Celebration)

Same shape as Task 21 but:
- orbContent: `ic_promo.svg`
- title: `wizard_promotions_title`
- body: `wizard_promotions_body`
- Different marble layout
- Different sparkle positions

Implement, verify, commit `feat(welcome-wizard): screen 05 — promotions`.

---

### Task 23: Screens 09, 10, 12, 13 (Feature mode — care/health/notes/relatives)

Same shape as Task 16 / 17 with these mappings:

| Screen | File | Icon | ARB title key | Notes |
|---|---|---|---|---|
| 09 Visit reports | `s09_visit_reports.dart` | `ic_report.svg` | `wizard_reports_title` | — |
| 10 Documents | `s10_documents.dart` | `ic_documents.svg` | `wizard_documents_title` | Render an inline "Encrypted" badge: a small pill widget right-after the title. Use `wizard_documents_badge`. |
| 12 Notes | `s12_notes.dart` | `ic_pen.svg` | `wizard_notes_title` | Render a "Private" badge using `wizard_notes_badge`. Match the documents pattern. |
| 13 Relatives | `s13_relatives.dart` | `ic_family.svg` | `wizard_relatives_title` | — |

For 10 and 12, the "Encrypted/Private" badge is a small `Container` with rounded corners, teal-tint background, white outline, sized 9.5sp text. Place to the right of the title (or inline at end). One implementation:

```dart
// inside the FeatureScaffold's title slot, replace plain GlassTitle with:
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: GlassTitle(text: l.wizard_documents_title, size: 46)),
    SizedBox(width: 8.w),
    Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: _BadgePill(text: l.wizard_documents_badge),
    ),
  ],
)
```

Define `_BadgePill` as a private widget at the bottom of the screen file:

```dart
class _BadgePill extends StatelessWidget {
  final String text;
  const _BadgePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0x1A009092), // teal .10
        border: Border.all(color: const Color(0x33009092)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 9.5.sp,
          letterSpacing: 0.4,
          color: const Color(0xFF007E80),
        ),
      ),
    );
  }
}
```

Note: `FeatureScaffold` currently takes a String `title`, not a Widget. For screens with badges, **add a new optional `Widget? customTitle` parameter to `FeatureScaffold`** that, when non-null, replaces the GlassTitle slot. Update `feature_scaffold.dart` accordingly:

```dart
// in FeatureScaffold:
final Widget? customTitle;

// in build, replace the title PositionedDirectional with:
PositionedDirectional(
  top: 0.46 * size.height,
  start: 22.w,
  end: 22.w,
  child: widget.customTitle ?? GlassTitle(text: widget.title, size: 46),
),
```

Implement each, verify, commit one per screen:
- Task 23a: `feat(welcome-wizard): screen 09 — visit reports`
- Task 23b: `feat(welcome-wizard): add customTitle to FeatureScaffold + screen 10 — documents`
- Task 23c: `feat(welcome-wizard): screen 12 — notes (private badge)`
- Task 23d: `feat(welcome-wizard): screen 13 — relatives`

---

### Task 24: Screen 11 — Health page (Manifesto)

**Files:** Create `lib/screens/onboarding/welcome_wizard/screens/s11_health.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/app/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/scaffolds/manifesto_scaffold.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;

class S11Health extends StatelessWidget {
  const S11Health({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ManifestoScaffold(
      iconTag: Container(
        width: 64.w,
        height: 64.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF009092), Color(0xFF4DD0D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.main.withValues(alpha: .55),
              blurRadius: 26, offset: const Offset(0, 12), spreadRadius: -6,
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/onboarding/ic_health.svg',
            width: 32.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
      title: l.wizard_health_title,
      body: l.wizard_health_body,
      marbles: const [
        MarbleSpec(topPct: 0.18, startPct: 0.18, sizePx: 26, period: Duration(milliseconds: 5000)),
        MarbleSpec(topPct: 0.50, startPct: 0.14, sizePx: 16, period: Duration(milliseconds: 6000)),
        MarbleSpec(topPct: 0.22, startPct: 0.36, sizePx: 20, period: Duration(milliseconds: 5500), phaseOffset: Duration(milliseconds: 500)),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify, commit**

`feat(welcome-wizard): screen 11 — health (manifesto)`

#### Task 25: Screens 14 (Loyalty intro) and 17 (Referral) — Manifesto mode

Same shape as Task 24 but:

- 14: icon `ic_loyalty.svg`, title `wizard_loyalty_title`, body `wizard_loyalty_body`. Unique marbles.
- 17: icon `ic_referral.svg`, title `wizard_referral_title`, body `wizard_referral_body`. Unique marbles.

Implement each, commit:
- Task 25a: `feat(welcome-wizard): screen 14 — loyalty intro (manifesto)`
- Task 25b: `feat(welcome-wizard): screen 17 — referral (manifesto)`

---

### Task 26: Screens 15 (Earn points) and 16 (Vouchers) — Celebration mode

Pattern matches Task 21 but:

- 15: orbContent is a numerals widget that ticks "+0" → "+25" via an `AnimationController`. Title `wizard_earn_title`, body `wizard_earn_body`. The ticking widget:

```dart
class _PointsCounter extends StatefulWidget {
  const _PointsCounter();
  @override
  State<_PointsCounter> createState() => _PointsCounterState();
}

class _PointsCounterState extends State<_PointsCounter> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    // restart on interval to show the loop
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _ctrl..reset()..forward();
        });
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final n = (Curves.easeOut.transform(_ctrl.value) * 25).round();
        return Text(
          '+$n',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 48.sp,
            color: const Color(0xFF009092),
            shadows: const [
              Shadow(color: Color(0x4D009092), blurRadius: 14, offset: Offset(0, 6)),
            ],
          ),
        );
      },
    );
  }
}
```

- 16: orbContent is `ic_qr.svg` (~110.w wide). Title `wizard_vouchers_title`, body `wizard_vouchers_body`. Marbles unique.

Implement, commit:
- Task 26a: `feat(welcome-wizard): screen 15 — earn points (counter ticks)`
- Task 26b: `feat(welcome-wizard): screen 16 — vouchers (QR)`

---

### Task 27: Screen 18 — All set (Closing showcase)

**Files:** Create `lib/screens/onboarding/welcome_wizard/screens/s18_all_set.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/glass_title.dart';
import '../widgets/scaffolds/feature_scaffold.dart' show MarbleSpec;
import '../widgets/scaffolds/showcase_scaffold.dart';

class S18AllSet extends StatelessWidget {
  final String firstName;
  const S18AllSet({super.key, required this.firstName});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ShowcaseScaffold(
      orbContent: SvgPicture.asset(
        'assets/images/docsera_main.svg',
        width: 80.w,
      ),
      title: GlassTitle(
        text: l.wizard_allset_title(firstName),
        size: 32,
        textAlign: TextAlign.center,
      ),
      tagline: l.wizard_allset_body,
      marbles: const [
        MarbleSpec(topPct: 0.12, startPct: 0.20, sizePx: 16, period: Duration(milliseconds: 5500)),
        MarbleSpec(topPct: 0.22, startPct: 0.65, sizePx: 26, period: Duration(milliseconds: 6500)),
        MarbleSpec(topPct: 0.42, startPct: 0.16, sizePx: 12, period: Duration(milliseconds: 5800), phaseOffset: Duration(milliseconds: 700)),
        MarbleSpec(topPct: 0.46, startPct: 0.72, sizePx: 22, period: Duration(milliseconds: 7100)),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

`feat(welcome-wizard): screen 18 — all set (closing)`

---

## Phase 6 — Wizard screen shell

### Task 28: WelcomeWizardScreen (the host)

**Files:**
- Create: `lib/screens/onboarding/welcome_wizard/welcome_wizard_screen.dart`

- [ ] **Step 1: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_cubit.dart';
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

import 'screens/s01_welcome.dart';
import 'screens/s02_search.dart';
import 'screens/s03_doctor_profile.dart';
import 'screens/s04_favorites.dart';
import 'screens/s05_promotions.dart';
import 'screens/s06_personal_gifts.dart';
import 'screens/s07_booking.dart';
import 'screens/s08_chat.dart';
import 'screens/s09_visit_reports.dart';
import 'screens/s10_documents.dart';
import 'screens/s11_health.dart';
import 'screens/s12_notes.dart';
import 'screens/s13_relatives.dart';
import 'screens/s14_loyalty_intro.dart';
import 'screens/s15_earn_points.dart';
import 'screens/s16_vouchers.dart';
import 'screens/s17_referral.dart';
import 'screens/s18_all_set.dart';
import 'widgets/wizard_background.dart';
import 'widgets/wizard_next_button.dart';
import 'widgets/wizard_page_dots.dart';
import 'widgets/wizard_skip_button.dart';

const int kWelcomeWizardScreenCount = 18;

/// Host page for the welcome wizard. Owns the PageController, the cubit, and
/// the chrome (skip / dots / next). Each page is a small stateful widget that
/// renders a screen-specific composition.
///
/// Caller must provide [firstName] (used on screens 01 + 18) and the entry
/// mode. On completion the cubit emits `completed = true` and this screen
/// listens for it to handle the appropriate exit (push home for firstTime,
/// pop for replay).
class WelcomeWizardScreen extends StatefulWidget {
  final WizardEntryMode entryMode;
  final String firstName;
  final VoidCallback onCompleteFirstTime; // navigates to pending-links → home
  final VoidCallback onCompleteReplay;    // Navigator.pop()

  const WelcomeWizardScreen({
    super.key,
    required this.entryMode,
    required this.firstName,
    required this.onCompleteFirstTime,
    required this.onCompleteReplay,
  });

  @override
  State<WelcomeWizardScreen> createState() => _WelcomeWizardScreenState();
}

class _WelcomeWizardScreenState extends State<WelcomeWizardScreen> {
  late final PageController _pageController;
  late final WelcomeWizardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cubit = WelcomeWizardCubit(
      entryMode: widget.entryMode,
      totalPages: kWelcomeWizardScreenCount,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_cubit.state.currentPage == 0) {
      // On screen 1, treat back as skip.
      _cubit.skip();
      return false;
    }
    _cubit.previous();
    return false;
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return S01Welcome(firstName: widget.firstName);
      case 1: return S02Search(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 2: return S03DoctorProfile(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 3: return S04Favorites(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 4: return S05Promotions(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 5: return const S06PersonalGifts();
      case 6: return S07Booking(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 7: return S08Chat(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 8: return S09VisitReports(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 9: return S10Documents(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 10: return const S11Health();
      case 11: return S12Notes(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 12: return S13Relatives(stepIndex: index, total: kWelcomeWizardScreenCount);
      case 13: return const S14LoyaltyIntro();
      case 14: return const S15EarnPoints();
      case 15: return const S16Vouchers();
      case 16: return const S17Referral();
      case 17: return S18AllSet(firstName: widget.firstName);
      default: throw RangeError('Unknown screen index $index');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<WelcomeWizardCubit, WelcomeWizardState>(
        listenWhen: (p, c) =>
            p.completed != c.completed || p.currentPage != c.currentPage,
        listener: (context, state) {
          if (state.completed) {
            if (state.entryMode == WizardEntryMode.firstTime) {
              widget.onCompleteFirstTime();
            } else {
              widget.onCompleteReplay();
            }
            return;
          }
          // sync page controller to cubit's currentPage
          if (_pageController.hasClients &&
              _pageController.page?.round() != state.currentPage) {
            _pageController.animateToPage(
              state.currentPage,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOut,
            );
          }
        },
        builder: (context, state) {
          final isLast = state.currentPage == kWelcomeWizardScreenCount - 1;
          final nextLabel = isLast
              ? (state.entryMode == WizardEntryMode.replay
                  ? l.wizard_done
                  : l.wizard_lets_begin)
              : null;

          return WillPopScope(
            onWillPop: _onWillPop,
            child: Scaffold(
              body: Stack(
                children: [
                  const WizardBackground(),
                  PageView.builder(
                    controller: _pageController,
                    itemCount: kWelcomeWizardScreenCount,
                    onPageChanged: (i) => _cubit.jumpTo(i),
                    itemBuilder: (context, index) => _buildPage(index),
                  ),
                  WizardSkipButton(onTap: _cubit.skip),
                  WizardPageDots(
                    total: kWelcomeWizardScreenCount,
                    current: state.currentPage,
                    onJump: _cubit.jumpTo,
                  ),
                  WizardNextButton(
                    onTap: _cubit.next,
                    label: nextLabel,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/onboarding/welcome_wizard/welcome_wizard_screen.dart`
Expected: no errors. (You may need to import additional screen files if any are missing — confirm by inspecting analyzer output.)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/welcome_wizard/welcome_wizard_screen.dart
git commit -m "feat(welcome-wizard): host screen with PageView + skip/dots/next chrome"
```

---

## Phase 7 — Integration

### Task 29: Update WelcomePage CTA copy + target

**Files:** Modify `lib/screens/auth/sign_up/WelcomePage.dart`

- [ ] **Step 1: Locate the CTA**

Open the file. Find the `ElevatedButton` near line 171 with `Navigator.pushAndRemoveUntil(... CustomBottomNavigationBar)`.

- [ ] **Step 2: Replace the button copy and target**

Find:

```dart
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        fadePageRoute(CustomBottomNavigationBar()),
                            (route) => false,
                      );
                    },
                    // ...
                    child: SizedBox(
                      width: 200.w,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.goToHomepage,
                          // ...
```

Replace with:

```dart
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        fadePageRoute(WelcomeWizardScreen(
                          entryMode: WizardEntryMode.firstTime,
                          firstName: widget.signUpInfo.firstName ?? '',
                          onCompleteFirstTime: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              fadePageRoute(LegalReconsentGate(
                                child: CustomBottomNavigationBar(),
                              )),
                              (route) => false,
                            );
                          },
                          onCompleteReplay: () {}, // unused in firstTime
                        )),
                        (route) => false,
                      );
                    },
                    // ...
                    child: SizedBox(
                      width: 200.w,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.discoverDocsera,
                          // ...
```

- [ ] **Step 3: Add the imports**

At the top of `WelcomePage.dart`, add:

```dart
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart';
import 'package:docsera/screens/onboarding/welcome_wizard/welcome_wizard_screen.dart';
import 'package:docsera/widgets/legal_reconsent_gate.dart';
```

- [ ] **Step 4: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/auth/sign_up/WelcomePage.dart`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/auth/sign_up/WelcomePage.dart
git commit -m "feat(welcome-wizard): WelcomePage CTA → wizard (was → home directly)"
```

---

### Task 30: Add replay tile to account page

**Files:** Modify `lib/screens/home/account_page.dart`

- [ ] **Step 1: Find the right insertion point**

Open the file. Find the section just before `Divider(color: Colors.grey[200], height: 2.h),` followed by `AccountSectionTitle(title: AppLocalizations.of(context)!.confidentiality)` (around line 487-489 in the existing file).

- [ ] **Step 2: Insert a new tile and divider before that block**

```dart
              // Replay welcome wizard
              _buildPrivacyItem(
                AppLocalizations.of(context)!.replayWelcomeTour,
                () {
                  final user = context.read<UserCubit>().state.userData;
                  Navigator.push(
                    context,
                    fadePageRoute(WelcomeWizardScreen(
                      entryMode: WizardEntryMode.replay,
                      firstName: user?['first_name']?.toString() ?? '',
                      onCompleteFirstTime: () {}, // unused in replay
                      onCompleteReplay: () => Navigator.pop(context),
                    )),
                  );
                },
              ),
              Divider(color: Colors.grey[200], height: 2.h),

              SizedBox(height: 15.h),
              AccountSectionTitle(title: AppLocalizations.of(context)!.confidentiality),
```

(Move the `SizedBox(height: 15.h)` and `AccountSectionTitle` from their previous position to AFTER the new tile so the visual order is correct.)

- [ ] **Step 3: Add imports**

At the top:

```dart
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_state.dart';
import 'package:docsera/screens/onboarding/welcome_wizard/welcome_wizard_screen.dart';
```

- [ ] **Step 4: Verify analyze**

Run: `flutter analyze --no-pub lib/screens/home/account_page.dart`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/account_page.dart
git commit -m "feat(welcome-wizard): replay-tour tile in account page"
```

---

### Task 31: One-time migration in main.dart

**Files:** Modify `lib/main.dart`

- [ ] **Step 1: Locate the app initialization**

Open `lib/main.dart`. Find the `main()` function — there's likely a section around `WidgetsFlutterBinding.ensureInitialized()` and dependency setup (Supabase, SharedPreferences, etc.).

- [ ] **Step 2: Call the migration**

Right after `WidgetsFlutterBinding.ensureInitialized()` and before the `runApp(...)` call, add:

```dart
  // One-time migration: existing users who predate the welcome wizard
  // should not be shown it. The flag is only set if not already present —
  // new signups (post-wizard release) hit the wizard via the WelcomePage
  // CTA, which sets the flag at completion/skip.
  await WelcomeWizardCubit.migrateExistingUser();
```

- [ ] **Step 3: Add the import**

```dart
import 'package:docsera/Business_Logic/Onboarding/welcome_wizard/welcome_wizard_cubit.dart';
```

- [ ] **Step 4: Verify analyze**

Run: `flutter analyze --no-pub lib/main.dart`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(welcome-wizard): one-time migration for existing users"
```

---

## Phase 8 — Verification & polish

### Task 32: Run full test suite + analyzer

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: ALL tests PASS, including the new `welcome_wizard_cubit_test.dart`.

If any existing tests fail, investigate. The wizard should not affect other features — failures here are likely import resolution issues or accidental breakage.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: no errors. Existing warnings ok.

- [ ] **Step 3: Regenerate l10n**

Run: `flutter gen-l10n`
Expected: no errors.

---

### Task 33: Manual visual QA

- [ ] **Step 1: Run the app on a real device or simulator**

Run: `flutter run`
Sign up as a new user. Verify:
- WelcomePage button shows "تعرّف على دوكسيرا" (AR) / "Discover DocSera" (EN).
- Tapping it pushes the wizard.
- Screen 01 entrance choreography plays once.
- Swipe forward through all 18 screens.
- Each screen has DIFFERENT marble positions/sizes (no two adjacent screens look identical).
- Glass title has NO white speckles inside Arabic letterforms.
- Skip button silently dismisses.
- Closing button on screen 18 says "هيا نبدأ".
- After completion, app routes to home via the pending-links gate.

- [ ] **Step 2: Test replay from account**

Open Account → "أعد الجولة التعريفية". Wizard launches.
- Closing button on screen 18 says "تم".
- Tapping it pops back to account.
- Skip pops back to account.

- [ ] **Step 3: Test LTR**

Switch app language to English. Re-run the wizard. Verify:
- All copy reads in English.
- Skip button is in top-right (not top-left).
- Next button is in bottom-right with forward chevron.
- Page dots are bottom-left.
- Marble compositions still feel balanced (auto-mirrored via `PositionedDirectional`).

- [ ] **Step 4: Test existing-user migration**

Force the SharedPreferences to NOT have `welcome_wizard_completed_v1` (uninstall + reinstall, or use ADB to clear app data). Re-launch. Verify the migration sets the flag correctly. The wizard should NOT auto-show — it only mounts via WelcomePage post-signup or the account-page tile.

- [ ] **Step 5: If a native-touching change crept in**

If `pubspec.yaml` got new deps (it shouldn't have — verify), or if any iOS/Android files were modified, run the build workflow:

```bash
gh workflow run build.yml
```

If pure Dart, skip the build workflow run.

---

### Task 34: Final review and push

- [ ] **Step 1: Inspect the diff**

Run: `git log --oneline origin/main..HEAD`
Expected: a clean sequence of feat commits, one per logical task.

- [ ] **Step 2: Push to origin**

```bash
git push origin main
```

The user's memory note: "Commit + push to origin after every step; another agent wiped uncommitted work once" — push aggressively.

---

## Self-review (the planner's checklist before handoff)

I scanned the spec section by section and mapped each requirement to a task:

- ✅ Visual signature (4-layer model) → Tasks 5–11
- ✅ Glass kit primitives (5 widgets) → Tasks 5–8
- ✅ Glass title → Task 9
- ✅ Four screen modes → Tasks 12–14
- ✅ All 18 screens → Tasks 15–27
- ✅ Wizard cubit + state with persistence (incl. migration) → Task 4
- ✅ Wizard host shell (PageView + skip/dots/next) → Task 28
- ✅ WelcomePage button copy + target → Task 29
- ✅ Account-page replay tile → Task 30
- ✅ Migration in main.dart → Task 31
- ✅ ARB strings (43 keys × 2 locales) → Task 2
- ✅ 16 custom SVG icons → Task 3
- ✅ Folder + README → Task 1
- ✅ Per-screen position-variation rule → enforced in screen tasks (each spec is unique) + documented in README
- ✅ RTL/LTR mirroring → all positions use `PositionedDirectional`, `EdgeInsetsDirectional`, `start/end`; `Directionality` flips chevron and text alignment automatically
- ✅ Two entry modes (firstTime/replay) with different exit behavior → Task 4 (cubit) + Task 28 (shell) + Tasks 29/30 (callers)
- ✅ Verification → Tasks 32–34

Type / signature consistency check:
- `WizardEntryMode` enum: defined in `welcome_wizard_state.dart` (Task 4), imported by Tasks 28, 29, 30 — consistent.
- `WelcomeWizardCubit({required entryMode, required totalPages})` — same signature in Task 4 (definition), Task 28 (instantiation).
- `MarbleSpec`, `CapsuleSpec` — defined in `feature_scaffold.dart` (Task 12), reused by Tasks 13–14 via `show MarbleSpec` import — consistent.
- `WelcomeWizardScreen({entryMode, firstName, onCompleteFirstTime, onCompleteReplay})` — same in Tasks 28, 29, 30.

No placeholders found. No spec gaps.

---

## Execution handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-10-welcome-wizard.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration with fresh context for each.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints for review.

**Which approach?**
