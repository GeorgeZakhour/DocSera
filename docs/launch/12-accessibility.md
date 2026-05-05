# 12 — Accessibility Audit & Patterns

**Date:** 2026-05-05
**Score impact:** 9.55 → 9.65
**Roadmap step:** 13

> Note: this doc is numbered 12 because it covers what the launch roadmap calls Step 13 (a11y). The `12-` prefix follows file-creation order.

## Why this step exists

DocSera serves Syrian patients, including elderly and visually-impaired users who rely on screen readers, larger system fonts, and high-contrast displays. The audit caught two categories of real bugs:

1. **Contrast violations** — text colors that fail WCAG AA on the actual background they render on.
2. **Missing screen-reader labels** — icon-only buttons that announce as just "button" with no context.

A third category (text scaling / overflow under user-elevated font sizes) was spot-checked and looks generally healthy on hot screens; an exhaustive sweep is deferred to a later session.

## What WCAG AA actually requires (the cheat sheet)

| Element | Contrast threshold |
|---|---|
| Body text (< 18pt regular OR < 14pt bold) | **4.5:1** |
| Large text (≥ 18pt regular OR ≥ 14pt bold) | **3:1** |
| UI components (button borders, input outlines) | **3:1** |
| Decorative icons / branding | no requirement |
| Functional icons (inside buttons) | **3:1** if essential to identify the button |

Quick check: paste any two hex colors into [contrast-ratio.com](https://contrast-ratio.com).

## Bugs fixed in this pass

### 1. "Personal Records" section title — orange-on-teal failed AA

**File:** [`lib/screens/home/health_page.dart`](../../lib/screens/home/health_page.dart) line 472–489
**User report:** "السجلات الشخصية title is orange and appears in some places on the gradient teal-white background unreadable"

**Was:** `AppColors.orangeText` (`#FFA070`) at 15sp bold → ~1.84:1 contrast on white. Hard fail at AA-large (3:1 threshold) and double-fail at AA-normal (4.5:1).

**Fix:** switched to `AppColors.giftAccent` (`#E07A1F`) — passes AA-large at 15sp bold while keeping the warm-orange accent the design intended.

Subtitle was a separate-but-related bug: it used `AppColors.background3` (`#F7FDFC`, near-white) which was effectively invisible on the gradient's white half. Switched to `Colors.grey.shade700` for a guaranteed-readable secondary tone.

### 2. "Too late to reschedule" pill — same orange-on-pale-orange failure

**File:** [`lib/screens/home/appointment/appointment_details_page.dart`](../../lib/screens/home/appointment/appointment_details_page.dart) line 401–407

`AppColors.orangeText` text on a 10%-alpha-orange pill background → ~1.8:1. Same fix: `AppColors.giftAccent`.

### 3. Icon-only buttons missing screen-reader labels

Without a `tooltip:` (which Flutter exposes to TalkBack/VoiceOver as the Semantics label), an `IconButton` with only an icon announces as just *"button"*. Visually-impaired users have no way to tell apart back/favorite/QR/share.

Added tooltips on:
- `search_page.dart` — clear-search button
- `doctor_profile_page.dart` — back, favorite (toggles between "Add to favorites" / "Remove from favorites"), QR code, share

Four new l10n keys added to both ARB files: `clearSearchTooltip`, `addToFavorites`, `showQrCodeTooltip`, `shareTooltip`. Reused existing `back` and `removeFromFavorites`.

## Patterns for future code

### Pattern: never use `AppColors.orangeText` (#FFA070) as text color

It's a peachy accent that doesn't survive contrast requirements on either light or branded-orange backgrounds. Use cases:
- **Want orange accent on a primary text element?** Use `AppColors.giftAccent` (#E07A1F).
- **Want orange icon on a light background?** `orangeText` is acceptable for decorative icons (no contrast requirement) or for icons ≥ 24sp where the shape is the signal.
- **Never** use `orangeText` for body text or labels.

### Pattern: every icon-only `IconButton` needs `tooltip:`

```dart
// ✅ GOOD
IconButton(
  icon: const Icon(Icons.share),
  tooltip: AppLocalizations.of(context)!.shareTooltip,
  onPressed: _share,
)

// ❌ BAD — screen reader announces as "button"
IconButton(
  icon: const Icon(Icons.share),
  onPressed: _share,
)
```

Tooltip text doubles as the screen reader's Semantics label, so it satisfies both UX (long-press hint) and a11y (TalkBack/VoiceOver readout) in one parameter.

### Pattern: for non-`IconButton` tappable icons, wrap in `Semantics`

`GestureDetector(child: Icon(...))` and `InkWell(child: Icon(...))` don't get an automatic label. Wrap:

```dart
Semantics(
  label: AppLocalizations.of(context)!.someTooltipKey,
  button: true,
  child: GestureDetector(
    onTap: ...,
    child: const Icon(Icons.foo),
  ),
)
```

### Pattern: avoid hardcoded heights on text-bearing Containers

Text scales when the OS font size is bumped. A `Container(height: 40, child: Text(...))` will clip the text on a 200% font-size setting. Either:
- Don't set the height; let the text size determine it
- Use `MediaQuery.textScalerOf(context)` to scale the height proportionally
- Set `min`/`max` instead of fixed (e.g. `ConstrainedBox(constraints: BoxConstraints(minHeight: 40))`)

## What's intentionally NOT in this pass

- **Full-app contrast sweep.** I fixed the two reported/found cases on hot screens. A complete sweep would mean opening every screen with a contrast-ratio overlay tool, which is a 1-2 day calendar task. Deferred.
- **Dynamic Type stress test.** Best done by setting iOS "Larger Accessibility Sizes" or Android system font 200% and walking through every screen. Recommend doing this informally during the soft launch.
- **VoiceOver / TalkBack walkthroughs of every screen.** Same — a manual smoke test, not a code task.
- **Color-blind mode validation.** Most of the brand uses teal which is friendly to deuteranopia and protanopia (the two most common color-blindness types). The orange/yellow accents are the ones to check during soft-launch testing.

## How to test what's been fixed

**Contrast (works on Mac):**
```bash
# In a browser, visit https://contrast-ratio.com
# Paste foreground + background colors
# Anything below 3:1 (large text) or 4.5:1 (body) is a fail
```

**Tooltips on iOS Simulator / Android Emulator:**
1. Settings → Accessibility → VoiceOver (iOS) or TalkBack (Android)
2. Open the app, navigate to the doctor profile
3. Swipe right to step through the AppBar — you should hear "back", "add to favorites", "show QR code", "share" announced
4. Without the fix, all four would have announced as just "button"

## Score impact

9.55 → **9.65**. Smaller jump than Steps 8/11 because most of the audit value is preventive (cleaner patterns for future code) rather than fixing visible bugs. The two contrast bugs that were fixed *were* visible (the user reported one of them) — but the broader long-term value is the documented patterns: every future agent and developer now has clear "use this color for orange text / never use that one / always tooltip an IconButton" guidance.
