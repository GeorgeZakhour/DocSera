# Welcome Wizard — Design Spec

**Status:** approved by product (George), 2026-05-10
**Owner:** patient app
**Touches:** new screens, new cubit, new auth-flow integration, new account-page tile, new ARB strings, no schema changes

---

## Goal

After a new user finishes signup and lands on the existing `WelcomePage`, take them through a polished animated tour of every major DocSera feature so they leave with: (a) excitement about loyalty, (b) confidence about booking, (c) awareness that their medical history & documents flow through the app, (d) a desire to invite friends.

The wizard is the single most-important first-impression surface in the app. Quality bar: Apple device-setup, Spotify Wrapped, Notion first-run, Linear.

## Non-goals

- The existing `WelcomePage.dart` (post-signup celebration with confetti + animated logo background) **stays exactly as it is** — we only change its CTA button copy and target.
- The wizard does NOT collect data, configure preferences, or block any flow. It is purely informational + emotional.
- Existing users on app upgrade do **not** see the wizard (one-time migration sets the persistence flag to `true`).

---

## Visual signature — "Glass Atelier"

A four-layer system used on every screen. The composition varies per screen so no two feel templated, but the language is constant.

### Layer 1 — Backdrop

- Background: `linear-gradient(180deg, #F1FBF8 0%, #E0F4F0 100%)`. Mint canvas.
- Two large drifting orbs (`rgba(0, 144, 146, .28..30)` and `.20..22`), `blur(48px)`, animated on independent 18s/22s loops with sin/cos translation.
- One additional accent orb behind the title position (`.30`, `blur(60px)`) so the glass headline always has color to refract through.

### Layer 2 — Glass kit (composable widgets)

Implemented as reusable Flutter widgets under `lib/screens/onboarding/welcome_wizard/widgets/glass_kit/`:

| Widget | Purpose | Implementation |
|---|---|---|
| `GlassMarble` | Small floating sphere (12–48px) | `Container` with `BackdropFilter(ImageFilter.blur(10, 10))`, radial-gradient fill, white border, soft shadow |
| `GlassCapsule` | Frosted pill, ~110×44px, rotated | `BackdropFilter(blur 14)`, white .50 fill, 1px white border, drop shadow, optional rotation |
| `GlassTag` | Pill with text inside (e.g. "الخطوة ٤ من ١٦") | Same as capsule but with `Text` child |
| `GlassShard` | Larger frosted capsule placed BEHIND the glass title to give it color to refract; rotated −3° | `BackdropFilter(blur 8)`, .22 white fill, sweeping animation |
| `GlassOrbLarge` | 180–210px sphere; used for Showcase + Celebration modes (icon or numerals inside) | `BackdropFilter(blur 22, saturate 170%)`, radial-gradient interior, inner + outer shadows for 3D feel |

Per screen, marbles + capsule + tag are arranged in a **different composition** — different positions, sizes, rotations. The README in the wizard folder documents the convention so future feature additions follow the same idiom.

### Layer 3 — Hero

Two flavors:

- **Solid teal feature icon** (Feature mode) — rounded rectangle 64–72px, gradient `#009092 → #4DD0D2`, icon in white, subtle bob+rotation animation. Custom DocSera SVG icons (see "Icon library" below).
- **Icon-inside-large-glass-orb** (Showcase + Celebration modes) — the icon (or numerals / QR / gift box) lives inside `GlassOrbLarge`.

### Layer 4 — Typography

- Body: Cairo, weight 500, 15sp, color `rgba(0, 65, 70, .78)`, line-height 1.65, RTL-aligned to right.
- **Glass title** (Feature + Manifesto modes): the recipe locked in v3.
  - Cairo weight 900, 46sp (manifesto: 52sp).
  - Line-height **1.18** (Arabic descenders/loops in ع، ق، ج، ة need that headroom — line-height 1.05 clipped them).
  - Translucent teal gradient clipped to text via `ShaderMask`:
    ```
    LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xE6009092), Color(0x80009092)], // 90%→50% teal
    )
    ```
  - Outer drop shadow only (`drop-shadow(0 6px 12px rgba(0, 144, 146, .22))`). **NO white text-shadow** — the white inner-shadow speckles into Arabic letter counters.
  - Behind the title: a `GlassShard` sits at z-index BELOW the title text (the title is z 6, shard is z 3) so the glass appears as a frosted halo behind the letters, not a panel on top of them.

---

## The four screen modes

Each screen is assigned one mode based on its narrative role.

| Mode | Used for | Composition |
|---|---|---|
| **Showcase** | Opening (01), Closing (18) | `GlassOrbLarge` centered upper-mid with logo / brand mark inside. Atmospheric. Choreographed entrance. |
| **Feature** | The 10 workhorse screens | Floating composition: small hero icon (rotated −6°), `GlassCapsule` under it, 4 `GlassMarble`s on independent keyframes, `GlassTag` (step counter) top-corner, glass title at ~46% of screen height with shard behind it, body at ~70%. |
| **Manifesto** | Health page (11), Loyalty intro (14), Referral (17) | Larger glass title (52sp), small icon-tag in top corner, fewer marbles, more typographic weight. The title is the message. |
| **Celebration** | Promotions (05), Personal gifts (06), Earn points (15), Vouchers (16) | `GlassOrbLarge` with the relevant element inside (a discount tag, a gift box, a counter, a QR). Sparkles fade in/out around the orb. |

---

## Screen list — final, ordered as a six-act narrative

All copy was code-anchored: numbers are real (loyalty: +5/+15/+25 from `app_ar.arb`), feature claims are real (no ratings on doctor profiles, encryption is server-fetched-key not E2E, visit reports are optional, partners are pharmacies/labs/clinics/optical), brand spelling is **دوكسيرا**.

### Act 1 — Welcome

**01 · Welcome (Showcase)** — *breath-catcher intro*
- Hero: DocSera logo (real SVG: `assets/images/docsera_main.svg`) with static halo + entrance choreography (no looping breath).
- Greeting in glass typography: "أهلاً، {firstName}" — name pulled from `SignUpInfo.firstName`.
- Tagline: **"في رعايةٍ تليق بك"** / *"In care that suits you"*
- Subline: **"خطوةٌ، خطوة — معاً نُكمل المشوار."** / *"Step by step — we complete the journey together."*
- Animation: choreographed entrance only — logo fade-up → halo emerges → name scales in → shard slides under → divider draws → tagline appears → subline. Settles after ~2s. No loop.

### Act 2 — Finding care

**02 · Search (Feature)**
- Title: **"اعثر على طبيبك بثوانٍ"** / *"Find your doctor in seconds"*
- Body: **"ابحث بالاسم، التخصص، أو العيادة. وفلتر بالموقع، اللغة، وساعات العمل."** / *"Search by name, specialty, or clinic. Filter by location, language, hours."*
- Hero icon: magnifier
- Signature motion: magnifier traces a slow elliptical orbit around screen center; marbles trail behind for 600ms.

**03 · Doctor profile (Feature)**
- Title: **"كل ما تحتاج، قبل الحجز"** / *"Everything you need, before you book"*
- Body: **"الاختصاص، اللغات، ساعات العمل، العنوان، الأسعار، والخدمات — على ملف واحد."** / *"Specialty, languages, hours, address, pricing, services — on a single profile."*
- Hero icon: person silhouette / profile card
- Signature motion: tiny glass attribute pills ("اللغة · الساعات · العنوان · الأسعار") fan out from behind the icon, staggered 120ms each.
- ⚠ NOTE: doctor profiles do not show ratings — copy reflects that.

**04 · Favorites (Feature)**
- Title: **"احفظ من تثق بهم"** / *"Keep your trusted doctors close"*
- Body: **"أضف أطباءك المفضّلين بضغطة، وارجع إليهم لاحقاً — دون بحث جديد."** / *"One-tap favorites. Come back without searching again."*
- Hero icon: heart with sparkle
- Signature motion: a teal-outline heart fills bottom-up over 800ms with the brand gradient; three smaller heart marbles orbit it.

**05 · Promotions (Celebration)**
- Title: **"عروض من أطباء دوكسيرا"** / *"Offers from DocSera doctors"*
- Body: **"احصل على رمز الخصم من التطبيق، واعرضه عند الدفع — يُطبَّق الخصم تلقائياً على فاتورتك."** / *"Claim a discount code in the app. Show it at payment — applied automatically to your bill."*
- Hero: discount tag
- Signature motion: a "%" tag hangs from a thin thread, swinging gently; a small "-20%" pill appears from offscreen and lands beside it.

**06 · Personal gifts (Celebration)**
- Title: **"هدايا شخصية من طبيبك"** / *"Personal gifts from your doctor"*
- Body: **"بعض الأطباء يرسلون هدايا حصرية لمرضاهم في دوكسيرا — تصل مباشرة إلى محفظتك."** / *"Some doctors send exclusive gifts to their DocSera patients — they land in your wallet."*
- Hero: gift box (custom DocSera SVG: teal box, peach ribbon)
- Signature motion: the ribbon untwists once, the lid lifts 8px, a 360° sparkle burst, lid settles. Loops every 4s.
- ⚠ NOTE: gifts ≠ promotions. Gifts are personal items sent by a specific doctor to a specific patient (lands in wallet). Promotions are public discount codes.

**07 · Booking (Feature)**
- Title: **"احجز موعدك بدقيقة"** / *"Book in under a minute"*
- Body: **"اختر اليوم والساعة. ستصلك تذكيرات قبل الموعد — بدون اتصالات أو انتظار."** / *"Pick a day and time. We'll remind you. No calls. No waiting."*
- Hero icon: calendar with check
- Signature motion: the calendar's day cells light up in sequence (left-to-right, 80ms each), final cell pulses with brand teal.

### Act 3 — Care between visits

**08 · Chat (Feature)**
- Title: **"كلّم طبيبك مباشرةً، بأمان"** / *"Message your doctor, securely"*
- Body: **"أرسل سؤالاً، صورةً، أو ملاحظة صوتية — محادثاتك معه مشفّرة بالكامل."** / *"Send a question, photo, or voice note. Fully encrypted."*
- Hero icon: chat bubble
- Signature motion: typing indicator — three dot-marbles bounce in sequence inside a chat bubble, then a checkmark sweeps across.
- ⚠ NOTE: "fully encrypted" not "end-to-end" — the AES-256-GCM encryption uses a server-fetched key (per `MessageEncryptionService`), so strict E2E is overclaiming.

**09 · Visit reports (Feature)**
- Title: **"تقارير زياراتك، محفوظة لك"** / *"Your visit reports, kept for you"*
- Body: **"حين يُرفق طبيبك تقريراً بعد الزيارة — تشخيص، أدوية، تعليمات — تجده هنا، في أي وقت."** / *"When your doctor attaches a report — diagnosis, meds, instructions — you'll find it here."*
- Hero icon: document with fold
- Signature motion: folded paper unfolds in 3 stages (corner flips → middle flattens → text lines draw in). Loops every 5s.
- ⚠ NOTE: reports are optional — copy uses "حين" (when), not "إن أراد طبيبك" (if your doctor wants).

**10 · Documents (Feature)**
- Title: **"ملفاتك الطبية، بأمان"** / *"Your medical files, safe"* — with **"مشفّر / Encrypted"** privacy badge
- Body: **"ارفع التحاليل، الوصفات، والصور الشعاعية. ستجد بجانبها الملفات التي يرسلها أطباؤك."** / *"Upload labs, prescriptions, scans. Files sent by your doctors land here too."*
- Hero icon: document stack
- Signature motion: three document tiles slide in from offscreen and stack with slight rotation offsets — like papers tossed onto a desk.

### Act 4 — Owning your health

**11 · Health page (Manifesto)**
- Title (glass typography, 52sp): **"صحّتك بصورة كاملة"** / *"Your health, the full picture"*
- Body: **"حساسيّاتك، أدويتك، أمراضك المزمنة، تاريخك العائلي، نمط حياتك — مرجع واحد، مفيد في الحالات الطارئة."** / *"Allergies, medications, conditions, family history, lifestyle — one reference, useful in emergencies."*
- Icon-tag: heart-with-pulse (small, top-right corner)
- Signature motion: a heart-rhythm pulse line draws across the upper third of the screen left-to-right; the spike at center coincides with the title appearing.

**12 · Notes (Feature) — privacy emphasis**
- Title: **"ملاحظاتك — لك أنت فقط"** / *"Notes only you can see"* — with **"خاص / Private"** privacy badge
- Body: **"دوّن أعراضاً، أسئلة لطبيبك، أو ملاحظات شخصية. لا أحد يراها — حتى نحن."** / *"Symptoms, questions, personal observations. No one else can read them — not even us."*
- Hero icon: pen scribble
- Signature motion: a stylized teal line draws beneath the title like a signature being signed; a small lock-icon marble appears near the end.

**13 · Relatives (Feature)**
- Title: **"اعتنِ بعائلتك من حسابك"** / *"Care for your family from one account"*
- Body: **"أضف أبناءك، والدَيك، أو من تعتني بهم — واحجز وادر مواعيدهم من نفس المكان."** / *"Add children, parents, or anyone you care for. Book and manage their visits in the same place."*
- Hero icon: family silhouettes
- Signature motion: three small person-marbles appear in sequence (200ms apart); soft teal lines draw between them, forming a triangle.

### Act 5 — The bonus (loyalty)

**14 · Loyalty intro (Manifesto)**
- Title (glass typography): **"ولاؤك له قيمة"** / *"Your loyalty earns its value"*
- Body: **"كل تفاعل مع دوكسيرا — موعد، ملف، أو دعوة صديق — يصبح نقاطاً تفتح لك عروضاً وهدايا حقيقية."** / *"Every move with DocSera — a visit, a profile, a friend — becomes points that unlock real offers and gifts."*
- Icon-tag: loyalty star
- Signature motion: five small spark-marbles fly inward toward center and assemble into the loyalty-star icon; light burst as it locks in.

**15 · Earn points (Celebration)**
- Title: **"كل خطوة، نقطة في رصيدك"** / *"Every step adds to your balance"*
- Body: **"احضر موعداً، أكمل ملفك الصحي، ادعُ صديقاً — كلها تضيف إلى رصيدك تلقائياً، بدون أي مجهود إضافي."** / *"Attend a visit, complete your health profile, invite a friend — they all add up automatically."*
- Hero: numerals "+25" inside `GlassOrbLarge`
- Signature motion: the counter ticks "+0" → "+25" over 1.4s with easing; tiny "+5", "+15" labels float past as it ticks.
- ⚠ NOTE: do not mention "1 point ≈ 500 SYP" — too direct, dollar-anchoring undercuts the storytelling.

**16 · Vouchers (Celebration)**
- Title: **"استبدل، امسح، استمتع"** / *"Redeem, scan, enjoy"*
- Body: **"حوّل نقاطك إلى قسائم. أظهر رمز QR لدى أحد شركائنا — صيدلية، مخبر، عيادة، محل نظارات، وغيرها — وستحصل على خصمك فوراً."** / *"Turn points into vouchers. Show your QR at one of our partners — pharmacy, lab, clinic, optical shop, and others — and your discount applies instantly."*
- Hero: QR code icon inside `GlassOrbLarge`
- Signature motion: scattered teal squares migrate inward and lock into the QR-code shape over 1.2s. Loops every 5s.
- ⚠ NOTE: partner types are real — pulled from `lib/screens/home/loyalty/offers_page.dart` (pharmacies, labs, clinics, optical shops, mobile credit). "وغيرها" added per user request.

**17 · Referral (Manifesto)**
- Title (glass typography): **"ادعُ صديقاً، اربحوا معاً"** / *"Invite a friend, both win"*
- Body: **"تكسب ٢٥ نقطة لكل صديق ينضم برمزك، وهو يحصل على ١٥ مكافأة ترحيب — في نفس اليوم."** / *"25 points for you, 15 welcome points for them — same day they join with your code."*
- Icon-tag: handshake
- Signature motion: two person-marbles slide in from opposite sides; a small heart-spark appears between them; they settle inside the orb.
- ⚠ NOTE: numbers are real — `earnSourceReferralName` & `earnSourceReferredName` ARB strings.

### Act 6 — Closing

**18 · All set (Showcase)**
- Hero: DocSera logo inside `GlassOrbLarge`
- Title (glass typography): **"كلّ شيء جاهز، {firstName}"** / *"You're all set, {firstName}"*
- Body: **"حسابك مفعّل، أدواتك تنتظر، ونقاطك تبدأ من الآن. هيا نبدأ."** / *"Account ready, tools waiting, points starting now. Let's go."*
- Button: replaces the chevron with a labeled CTA — **"هيا نبدأ"** / *"Let's begin"* (firstTime mode) or **"تم"** / *"Done"* (replay mode).
- Signature motion: a circular confetti burst (teal + white particles) radiates from the orb once, tagline appears, button replaces dots/arrow.

---

## Per-screen position variation

This is a strict design rule, called out so future contributors don't break it: **the floating composition (marble positions/sizes/rotations, capsule angle, step-tag position) MUST differ between adjacent screens.** Each screen has a unique arrangement defined in its widget file. The README documents this.

This prevents the wizard from feeling like 18 instances of one template — it makes each screen its own composition.

## Custom DocSera SVG icon library

All emojis replaced with custom SVGs in `assets/images/onboarding/`:

- `ic_doctor.svg` — stethoscope curve
- `ic_search.svg` — magnifying glass with teal handle
- `ic_heart.svg` — heart with pulse line
- `ic_promo.svg` — discount tag
- `ic_gift.svg` — DocSera-style gift box (teal body, peach ribbon, white lid highlight)
- `ic_calendar.svg` — calendar with checkmark inside the day cell
- `ic_chat.svg` — speech bubble with three dots
- `ic_report.svg` — document with corner fold + lines
- `ic_documents.svg` — document stack
- `ic_health.svg` — heart with pulse waveform
- `ic_pen.svg` — pen scribble (notes)
- `ic_family.svg` — three person silhouettes
- `ic_loyalty.svg` — 5-point star medallion
- `ic_points.svg` — sparkle / numerical badge
- `ic_qr.svg` — QR pattern (clean, ~21×21 modules)
- `ic_referral.svg` — two figures + heart
- `ic_logo_mark.svg` — reuse existing `assets/images/docsera_main.svg`

Spec: 64×64 viewBox, single-color stroke 3.5 OR filled with teal/white, no shadows in the SVG itself (added via Flutter).

---

## Flow placement & integration

### Mount point

```
recap_info.dart (existing)
  → WelcomePage.dart (existing — kept exactly as is)
    → WelcomeWizardScreen [NEW]
      → maybe_show_link_request_gate (existing)
        → CustomBottomNavigationBar (home)
```

The wizard mounts after `WelcomePage`'s CTA. `WelcomePage`'s `Navigator.pushAndRemoveUntil(...)` target changes from `CustomBottomNavigationBar` to `WelcomeWizardScreen(entryMode: WizardEntryMode.firstTime)`.

`WelcomePage` itself is unchanged otherwise (confetti, animated logos, etc. — all preserved).

### WelcomePage button copy change

| | Before | After |
|---|---|---|
| ARB key | `goToHomepage` | `discoverDocsera` (new key) |
| AR | الانتقال إلى الصفحة الرئيسية | تعرّف على دوكسيرا |
| EN | Go to Homepage | Discover DocSera |

`goToHomepage` is kept (still used elsewhere — `main_screen.dart`).

### Wizard entry modes

```dart
enum WizardEntryMode { firstTime, replay }
```

| Aspect | `firstTime` | `replay` |
|---|---|---|
| Triggered from | `WelcomePage` CTA | Account-page tile |
| Updates `welcome_wizard_completed_v1`? | Yes — set to `true` on completion OR skip | No |
| Closing-screen button label | "هيا نبدأ" / "Let's begin" | "تم" / "Done" |
| Exit destination | `pushAndRemoveUntil` → `LegalReconsentGate(child: CustomBottomNavigationBar)` (after pending-links gate) | `Navigator.pop()` |
| Skip behavior | Silent — sets persistence and routes as if completed | Silent — `Navigator.pop()` |

### Persistence

- Key: `welcome_wizard_completed_v1` (boolean) in `SharedPreferences`.
- Set to `true` when:
  - User reaches screen 18 and taps the start button, OR
  - User taps Skip on any screen, OR
  - One-time migration on app upgrade (existing users).
- Versioned `_v1` suffix: if a future major redesign justifies re-showing the wizard, increment to `_v2` and existing users see it again.

### Migration for existing users

On app boot (in `main.dart` or `splash_screen.dart`), one-time migration:

```dart
final prefs = await SharedPreferences.getInstance();
final hasFlag = prefs.containsKey('welcome_wizard_completed_v1');
if (!hasFlag) {
  // Existing user — they predate the wizard. Don't show it.
  await prefs.setBool('welcome_wizard_completed_v1', true);
}
```

This runs once and is idempotent. New signups go through `recap_info → WelcomePage → wizard`, which sets the flag at completion/skip — they don't hit this migration path until well after the wizard.

### Skip behavior

- "Skip" button visible on every screen (top-left in RTL, top-right in LTR).
- Silent — no confirmation dialog. One tap sets persistence (in `firstTime` mode) and exits.
- System back on Android: previous screen if not on screen 01; on screen 01, prompts a small confirmation, then skip.
- iOS edge swipe: previous screen.
- PageView swipe gestures: forward/back navigation between screens.

### Backward navigation

- Swipe right (RTL) / left (LTR) → previous screen.
- Tapping inactive earlier dot indicators → jump to that screen.
- The next button is the only forward affordance besides swipe.

---

## Replay-from-account

### New tile in `account_page.dart`

Position: between the existing "preferences" / "notifications direct link" group and the "Confidentiality" section divider.

| | AR | EN |
|---|---|---|
| Title | أعد الجولة التعريفية | Replay the welcome tour |
| Subtitle | شاهد كل ما يقدّمه دوكسيرا من جديد | See everything DocSera offers again |
| Icon | Loyalty-star (sparkles) | (same) |
| Action | `Navigator.push` → `WelcomeWizardScreen(entryMode: WizardEntryMode.replay)` | (same) |

ARB keys: `replayWelcomeTour`, `replayWelcomeTourSubtitle`.

---

## File structure

```
lib/
├── Business_Logic/
│   └── Onboarding/
│       └── welcome_wizard/
│           ├── welcome_wizard_cubit.dart
│           └── welcome_wizard_state.dart
├── screens/
│   └── onboarding/
│       └── welcome_wizard/
│           ├── README.md                      [documents the kit + position-variation rule]
│           ├── welcome_wizard_screen.dart     [the shell with PageView + dots + skip + next]
│           ├── widgets/
│           │   ├── glass_kit/
│           │   │   ├── glass_marble.dart
│           │   │   ├── glass_capsule.dart
│           │   │   ├── glass_tag.dart
│           │   │   ├── glass_shard.dart
│           │   │   └── glass_orb_large.dart
│           │   ├── glass_title.dart           [ShaderMask Cairo title with shard behind]
│           │   ├── feature_screen_scaffold.dart
│           │   ├── showcase_screen_scaffold.dart
│           │   ├── manifesto_screen_scaffold.dart
│           │   └── celebration_screen_scaffold.dart
│           └── screens/
│               ├── s01_welcome.dart
│               ├── s02_search.dart
│               ├── s03_doctor_profile.dart
│               ├── s04_favorites.dart
│               ├── s05_promotions.dart
│               ├── s06_personal_gifts.dart
│               ├── s07_booking.dart
│               ├── s08_chat.dart
│               ├── s09_visit_reports.dart
│               ├── s10_documents.dart
│               ├── s11_health.dart
│               ├── s12_notes.dart
│               ├── s13_relatives.dart
│               ├── s14_loyalty_intro.dart
│               ├── s15_earn_points.dart
│               ├── s16_vouchers.dart
│               ├── s17_referral.dart
│               └── s18_all_set.dart

assets/
└── images/
    └── onboarding/
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
```

### Why per-screen files (and not one big switch)

- 18 screens with bespoke compositions and unique signature motions ≠ a configurable component. Each screen file is small (~100–150 lines), focused, easy to tweak independently.
- Position variation is enforced by having distinct files — copy-pasting and tweaking is a feature, not a bug, when the goal is "no two screens feel the same."

---

## Cubit

### Responsibilities

- Track `currentPageIndex` (0–17).
- Persist `welcome_wizard_completed_v1` on completion/skip in `firstTime` mode.
- Hold the entry mode (`firstTime` / `replay`).
- Emit state changes for skip / next / page-jumped events.

### State

```dart
class WelcomeWizardState {
  final int currentPage;
  final WizardEntryMode entryMode;
  final bool completed;     // true only after final action

  // ...
}
```

### Methods

```dart
void next();              // advance via next button
void previous();           // back via swipe or system back
void jumpTo(int index);    // dot-tap to jump
void skip();               // sets persistence (firstTime only), emits exit
void complete();           // final screen confirmed, exit
```

---

## ARB strings to add

All strings get keys in both `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`. Naming convention: `wizard_<screen>_<role>` (e.g. `wizard_search_title`, `wizard_search_body`).

Plus four standalone keys:

- `wizard_skip_button` ("تخطّي" / "Skip")
- `wizard_step_label` ("الخطوة {current} من {total}" / "Step {current} of {total}")
- `wizard_lets_begin` ("هيا نبدأ" / "Let's begin")
- `wizard_done` ("تم" / "Done")
- `discoverDocsera` ("تعرّف على دوكسيرا" / "Discover DocSera") — replaces `goToHomepage` on `WelcomePage`
- `replayWelcomeTour` ("أعد الجولة التعريفية" / "Replay the welcome tour")
- `replayWelcomeTourSubtitle` ("شاهد كل ما يقدّمه دوكسيرا من جديد" / "See everything DocSera offers again")

Total: 18 × 2 (title + body per screen) + 7 standalone = **43 new ARB keys per locale**.

For the welcome screen (01) and closing screen (18), title interpolates `{firstName}` from `SignUpInfo.firstName` (passed into the wizard constructor in `firstTime` mode; pulled from `UserCubit` profile in `replay` mode).

---

## Animation implementation notes

### Background motion (always on)

- Two main orbs use `AnimationController` with `Duration(seconds: 18)` and `seconds: 22`, repeating, with sin/cos `Tween`s for translation. Already existing pattern in `notifications_inbox_page.dart` — copy that approach.
- Marbles use individual `AnimationController`s (one per marble, 4 per screen) with different durations (5s / 6.5s / 5.5s / 7s) and offsets so they don't sync.
- The frosted shard sweep uses an 8s controller with a translate + slight rotation tween.

### Glass title

Implementation:

```dart
ShaderMask(
  shaderCallback: (bounds) => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE6009092), Color(0x80009092)],
  ).createShader(bounds),
  blendMode: BlendMode.srcIn,
  child: Text(
    titleText,
    style: TextStyle(
      fontFamily: 'Cairo',
      fontWeight: FontWeight.w900,
      fontSize: 46.sp,
      height: 1.18,
      // NO shadows — the wrapping container provides drop-shadow filter
    ),
    textAlign: TextAlign.right,
  ),
)
```

Wrapped in a `Container` with `BoxShadow` for the outer drop-shadow. The shard sits in the same `Stack` at lower z-index.

### Per-screen signature motion

Each screen owns its own `AnimationController` for the signature motion. Delegated to a private widget within the screen file. No shared state with other screens.

### Performance

- Only the active page's animations are running. `PageView.builder` keeps neighbors mounted, so we listen to page changes via the cubit and pause/resume controllers in the inactive screens.
- Background orbs are cheap (two `Container`s with blur filter). Glass elements use real `BackdropFilter` — known to be expensive on older Android. Test on a low-end device before committing to the marble count per screen.

---

## RTL / LTR mirroring

- Compositions are designed RTL-first (Arabic is the default locale).
- All marble/capsule x-positions are stored as a mirror-pair `{rtl: 0.16, ltr: 0.84}` (fractions of screen width) so flipping is automatic.
- Title, body text alignment auto-flip via Flutter `Directionality`.
- Skip button: `top: 22px, start: 22px` — `EdgeInsetsDirectional`.
- Next button: `bottom: 30px, end: 24px` — using `Directionality` to mirror.
- Chevron in the next button: forward-pointing in current locale (`Icons.arrow_forward_rounded` flips correctly under `Directionality`).

---

## README in the wizard folder

The folder ships with a `README.md` that documents:

1. The four screen modes and which screens use which.
2. The glass-kit primitives (size/usage of each).
3. **The position-variation rule** — every new screen MUST use a different arrangement. Reviewer responsibility.
4. Animation pattern: background-always-on + per-screen signature motion.
5. RTL/LTR rules.
6. How to add a new screen (which parent scaffold to extend, where to add ARB strings, where to add the icon).

This is the artifact the user asked for explicitly: "A short README in the folder explaining the animation pattern conventions you settled on, so future feature additions follow the same idiom."

---

## Out-of-scope (defer)

- Analytics events for wizard progress (skip rate, completion rate, time-per-screen) — useful but not required for v1. Add as a follow-up.
- A/B testing the copy — copy is locked for v1; iteration based on real-world skip data is post-launch.
- Lottie animations — we ruled this out; signature motions are Flutter-native (`AnimationController` + `Tween` + `Curves`) per the user's brief.
- Audio cues / haptic feedback — not in this spec.

---

## Acceptance checklist

- [ ] Wizard mounts after `WelcomePage` CTA, only for new signups.
- [ ] All 18 screens render correctly in both Arabic (RTL) and English (LTR).
- [ ] Glass title renders without speckles in Arabic letter counters (no white text-shadow).
- [ ] Each screen has unique floating-element positions/sizes/rotations.
- [ ] Each screen has a distinct signature motion.
- [ ] Skip button is silent and visible on every screen.
- [ ] PageView swipe forward/back works.
- [ ] System back / iOS edge swipe maps correctly.
- [ ] Persistence flag (`welcome_wizard_completed_v1`) set on completion AND on skip in `firstTime` mode.
- [ ] One-time migration sets the flag for existing users on app upgrade.
- [ ] Replay tile in account page launches in `replay` mode.
- [ ] Replay mode does NOT touch persistence.
- [ ] Replay-mode closing screen says "تم" not "هيا نبدأ".
- [ ] Replay-mode exit is `Navigator.pop()` not push.
- [ ] WelcomePage button copy updated to "تعرّف على دوكسيرا" / "Discover DocSera".
- [ ] All ARB keys exist in both `app_ar.arb` and `app_en.arb`.
- [ ] No emoji used as feature icons — all custom SVG.
- [ ] README in the wizard folder documents the kit, modes, and position-variation rule.
- [ ] No regressions in `WelcomePage`'s confetti/animated-logo background.
- [ ] Build workflow run after touching `pubspec.yaml` (no new deps expected; if any added, build verified).
