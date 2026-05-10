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
