# 06 — Syrian Ministry License (ترخيص) Playbook

**Audience:** You, returning to this doc whenever you need to remember what to do.
**Last updated:** 2026-05-04

This is your single source of truth for getting and maintaining a Syrian app license. It covers: what the license is, what you need to submit, the full flow, what gets tested, common pitfalls, post-license obligations.

⚠ **Honest disclaimer:** This playbook captures general best practice and what I can infer about the Syrian Ministry of Communications & Technology process. Specific procedures, fees, exact forms, and contact people change. **Treat the procedural details as a starting framework, and fill in the exact specifics as you learn them from the ministry directly.** Add notes to this file whenever you discover something new.

---

## Part 1 — The big picture

### What is "the license"?

A formal authorization (ترخيص) issued by the Syrian Ministry of Communications & Technology (وزارة الاتصالات والتقنية) to operate a digital service that handles Syrian citizen data — especially **healthcare data**, which is regulated more strictly.

Without it:
- App stores **may** still list you, but you operate in a legal gray zone within Syria.
- You cannot legally market the app as approved for medical use.
- Banks, partners, doctors' associations are unlikely to integrate with you.
- You're vulnerable to a future order to suspend operations.

With it:
- Legitimate operation under Syrian law.
- Credibility with doctors, hospitals, partners.
- Foundation for any future B2B / enterprise deals (clinics, insurance, ministry contracts).

### Who at the ministry handles app licensing?

The **General Authority for Cybersecurity** (الهيئة العامة للأمن السيبراني) under the ministry typically handles security testing. The licensing department itself (مديرية التراخيص or similar) handles the paperwork. Names and structures change — verify before each interaction.

### Three documents you'll be asked for

| Document | What it actually is | Where it lives in this repo |
|---|---|---|
| **APK / IPA** | The compiled app binary | Built via `flutter build apk --release ...` |
| **General documentation** | Architecture, features, data flows | [docs/launch/05a-pentest-brief.md](05a-pentest-brief.md) is the perfect base — print it |
| **الربط البرمجي** ("programmatic integration") | API integration documentation — endpoints, request/response shapes, auth model | Need to write this; see Part 4 |

---

## Part 2 — Terminology cheat sheet

| Term | What it means in our context |
|---|---|
| **ترخيص** | License / permit. The thing you're getting. |
| **الربط البرمجي** | Programmatic / API integration documentation. Lists every endpoint, request shape, response shape. Mostly for licensing purposes. |
| **اختبار اختراق** (ikhtibar ikhtirāq) | Penetration test. The ministry runs this. |
| **مراجعة أمنية** | Security review. Internal or external. |
| **الأمن السيبراني** | Cybersecurity. The department that owns testing. |
| **سياسة الخصوصية** | Privacy policy. You'll need this. |
| **شروط الاستخدام** | Terms of service / use. You'll need this. |
| **اقرار طبي** | Medical disclaimer. Required for healthcare apps. |

---

## Part 3 — The complete flow

```
                ┌──────────────────────────┐
                │ 1. Pre-submission prep   │ ← you are mostly here now
                └────────────┬─────────────┘
                             │
                ┌────────────▼─────────────┐
                │ 2. Submit application    │
                │   APK + docs + fees      │
                └────────────┬─────────────┘
                             │
                ┌────────────▼─────────────┐
                │ 3. Initial review        │
                │   Paperwork check        │
                │   (1-2 weeks)            │
                └────────────┬─────────────┘
                             │
                ┌────────────▼─────────────┐
                │ 4. Security testing      │
                │   Pen test by ministry   │
                │   (2-6 weeks)            │
                └────────────┬─────────────┘
                             │
                  ┌──────────┴──────────┐
                  │                     │
             findings              passed
                  │                     │
   ┌──────────────▼────┐                │
   │ 5a. Fix findings  │                │
   │     resubmit      │                │
   └──────────┬────────┘                │
              │                         │
              └─────► back to step 4 ◄──┘
                             │
                             ▼
                ┌────────────────────────┐
                │ 6. License granted     │
                │   (ترخيص issued)        │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │ 7. Ongoing obligations │
                │   Renewals, breach     │
                │   reporting, updates   │
                └────────────────────────┘
```

### Realistic timeline

- **Best case (everything passes first try):** 6-8 weeks total from submission to license issued.
- **Typical case (1-2 rounds of fixes):** 3-4 months.
- **Worst case (major rework needed):** 6+ months.

**Plan as if it's 4 months minimum.** Do this in parallel with App Store / Play Store submission — you can often start beta testing while the license is in review.

---

## Part 4 — Pre-submission checklist

Use this every time you submit (or resubmit after rejection). Tick each item.

### A. Code & build

- [ ] All Critical / High security findings closed (see [05-security-review.md](05-security-review.md))
- [ ] Build the submission APK with obfuscation:
  ```bash
  flutter build apk --release \
    --obfuscate \
    --split-debug-info=build/symbols/ \
    --dart-define-from-file=dart_defines/sentry.json
  ```
- [ ] Built from a tagged git commit (so you can reproduce later)
- [ ] `flutter analyze` returns 0 errors
- [ ] App tested end-to-end on a real Syrian SIM (Syriatel) — login, booking, messaging
- [ ] Forced-update mechanism verified working (set min version higher than build → app blocks)
- [ ] `dart_defines/sentry.json` is **gitignored**; the binary contains DSN as a baked constant only
- [ ] No debug-only menus or test buttons in the build (search: `kDebugMode`, `assert(false`, `throw 'TEST'`)

### B. Documentation to include

- [ ] **Cover letter** in Arabic + English — what the app does, who it's for
- [ ] **Architecture document** — print [05a-pentest-brief.md](05a-pentest-brief.md). Adapt to Arabic if requested.
- [ ] **API integration document** (الربط البرمجي) — list every Supabase RPC and edge function the app calls (covered in Part 5 below)
- [ ] **Privacy policy** in Arabic + English (Step 6 — see roadmap)
- [ ] **Terms of service** in Arabic + English
- [ ] **Medical disclaimer** prominently — "DocSera is a tool for booking and reporting; it does not provide medical opinions or diagnoses"
- [ ] **Data residency statement** — "All patient data is stored on a self-hosted Syrian VPS (Syriatel infrastructure)"
- [ ] **Encryption statement** — "Messages encrypted with AES-256-GCM. TLS 1.2+ for all transit. Encryption keys never bundled in the app."
- [ ] **Retention policy** — "Analytics: 24 months. Medical records: indefinitely or until account deletion + legal-retention period"
- [ ] **Account deletion process** — describe how a user requests deletion and the timeline
- [ ] **Breach notification commitment** — your policy if a breach occurs (typically 72 hours notice)

### C. Test credentials to provide

- [ ] 2 test phone numbers + accounts (mark as "for ministry testing")
- [ ] 2 test email accounts
- [ ] One test admin account (if the ministry asks)
- [ ] OTP delivery via Syriatel SMS confirmed working for test numbers

### D. Backup / safety

- [ ] `build/symbols/` directory backed up (you need it to debug release crashes)
- [ ] Submission build APK + version + git commit recorded somewhere durable
- [ ] All passwords / credentials for VPS access documented (sealed envelope, encrypted vault — your choice)

---

## Part 5 — How to write the الربط البرمجي document

This is the document the Syrian ministry asks for that doesn't have an exact English equivalent. It's roughly: **API integration documentation describing every external call your app makes**.

### Template structure

```markdown
# DocSera — الربط البرمجي

## 1. النظرة العامة (Overview)
- Backend: Self-hosted Supabase on Syrian VPS (api.docsera.app)
- Authentication: JWT-based, OTP login flow
- Encryption: TLS 1.2+ in transit, AES-256-GCM for messages

## 2. نقاط النهاية (Endpoints)

### 2.1 Authentication
- POST /auth/v1/token — Supabase GoTrue token exchange
- POST /functions/v1/send_email_otp — Email OTP delivery (edge function)
- RPC rpc_create_phone_otp — Phone OTP generation
- RPC rpc_verify_phone_otp — Phone OTP verification

### 2.2 User profile
- RPC rpc_get_my_user — Fetch own profile
- RPC rpc_update_my_user — Update own profile
- RPC rpc_get_my_security_state — Fetch 2FA / device state

### 2.3 Appointments
- RPC book_appointment_by_patient — Book a new appointment
- RPC cancel_appointment_by_patient — Cancel
- RPC reschedule_appointment_by_patient — Reschedule
- (table) appointments — Read own via RLS

### 2.4 Messaging
- (table) conversations — Read own via RLS
- (table) messages — Read/insert with encryption (AES-256-GCM)
- RPC rpc_get_encryption_key — Fetch shared message-encryption key (auth required)

### 2.5 Documents
- (storage) /storage/v1/object/documents/<user_id>/* — Per-user document folder
- (table) documents — Read own via RLS

### 2.6 Analytics (internal only)
- RPC rpc_track_events_batch — Anonymous + authenticated event ingestion
- RPC rpc_track_session — Session metadata

## 3. أمن البيانات (Data security)

- All endpoints require TLS 1.2+
- All authenticated endpoints require Authorization: Bearer <JWT>
- Anonymous endpoints (anon role): only OTP creation/verification, public reference data, analytics ingestion
- Row-Level Security (RLS) enabled and forced on every public table
- SECURITY DEFINER functions with pinned search_path

## 4. التراخيص الخارجية (Third-party services)
- Pushy.me — push notifications (US-based, only Pushy device tokens leave the system)
- Sentry.io (EU region) — anonymous crash reports (no PII / PHI)

## 5. تخزين البيانات (Data storage)
- All patient data in PostgreSQL on Syrian VPS
- Files in Supabase Storage on the same VPS
- Encryption at rest via volume encryption + application-level for messages
```

You can take that template, fill in the actual RPC list (use `docs/launch/04b-admin-rpcs.md` as a reference for shape), translate into Arabic, and submit.

---

## Part 6 — What the ministry will probably test

Based on standard government cybersecurity testing methodology:

### Mobile app side
- **Reverse engineering the APK** — extract strings, look for hardcoded secrets, API URLs, weak crypto, anti-tamper checks. Mitigation: `--obfuscate` build flag.
- **Network traffic interception** (mitmproxy on a rooted device) — confirm all traffic is TLS, watch for sensitive data in headers/URLs/bodies.
- **Local storage inspection** — check what's in `/data/data/<package>/shared_prefs/`, Keychain, app sandbox files. Confirm no PII / credentials in plaintext.
- **Deep link fuzzing** — try malicious URLs (`docsera://...` with weird tokens, very long inputs).
- **OTP behavior** — replay attacks, brute force tolerance, timing leaks.

### Backend side
- **API authentication bypass** — call protected endpoints without JWT, with expired JWT, with another user's JWT.
- **RLS verification** — fetch other users' data with a valid JWT.
- **RPC parameter fuzzing** — send malformed inputs, oversized payloads, SQL fragments.
- **Rate limiting** — try to flood OTP requests.
- **Edge function input handling** — same fuzzing.

### Data & privacy
- **Where is patient data stored?** (Syrian VPS — favorable answer)
- **Is data encrypted at rest?** (Yes — AES-256-GCM for messages, encrypted volumes)
- **Who has access?** (Operator only via service_role; users via RLS)
- **Account deletion process?** (Document and demonstrate)
- **Data retention?** (Document — see roadmap Step 6)

### Compliance & operations
- **Privacy policy linked from app?** (Step 6 will add this)
- **Terms of service?** (Step 6)
- **Medical disclaimer visible?** (Already a standing project rule — you have a memory entry on this)
- **Breach response plan?** (Have a written 1-pager)

### Likely "nice to have" tests
- Cert pinning
- Root / jailbreak detection
- Code obfuscation level

We address each of these explicitly in [05a-pentest-brief.md](05a-pentest-brief.md), so the testers can verify each mitigation quickly instead of having to discover it.

---

## Part 7 — Common reasons for rejection (and how to handle them)

| Reason | What to do |
|---|---|
| Missing privacy policy / TOS | Add them. Step 6 will produce these. |
| Cleartext password storage found | Already fixed (CRITICAL-01 in security review). Show the fix. |
| OTP visible in logs | Already fixed. Show the fix. |
| No data residency statement | Write a 1-paragraph statement. Patient data is on Syrian VPS — favorable. |
| API endpoints discoverable but unauthenticated | This is most public APIs by design (anon RPCs are limited and audited). Provide [05a-pentest-brief.md](05a-pentest-brief.md) showing the auth model. |
| No medical disclaimer | Add prominently in onboarding + settings. |
| Force-update mechanism missing | Already built. Demonstrate by setting min version. |
| Insufficient logging / audit trail | Document RBAC + admin RPC audit pattern; if more is needed, add it. |
| App requests too many permissions | Audit `AndroidManifest.xml` and iOS `Info.plist`. Remove any unused permission. |

If rejected, **ask for the specific findings list in writing**. Don't accept "it failed" as the only feedback. You have the right to know what to fix.

---

## Part 8 — Post-license obligations (do not forget these)

| Obligation | When | What to do |
|---|---|---|
| **Renewal** | Annual (typical) | Submit a re-test if asked. Keep your team on top of any changes the ministry makes to requirements. |
| **Breach notification** | Within 72 hours | Have a 1-pager ready: who you notify, what info you provide, what remediation steps. |
| **Major version retest** | When you ship a major version with security-relevant changes | Notify the ministry; they may require a re-test. |
| **Data subject requests** | Always available | User asks for their data → export it. User asks for deletion → delete and confirm in writing within X days (your TOS sets X). |
| **Data residency maintenance** | Ongoing | If you ever migrate the VPS or change the data center, notify the ministry. |
| **Audit logs** | Ongoing | Keep admin / sensitive-action logs for the period the ministry requires (typically 1-3 years). |

Add a calendar reminder for license expiration **6 weeks before** the renewal date — gives you time to prepare a retest if needed.

---

## Part 9 — Quick-reference card (TL;DR)

**Before submission, verify:**
1. ✅ Internal security pass complete (Step 5)
2. ✅ All Critical / High issues fixed
3. ✅ APK built with `--obfuscate --split-debug-info=...`
4. ✅ Privacy Policy + ToS + Medical Disclaimer ready (Step 6)
5. ✅ الربط البرمجي document written (template in Part 5 of this doc)
6. ✅ Test credentials prepared (2 phones, 2 emails, 1 admin)
7. ✅ Hand over: APK + brief ([05a](05a-pentest-brief.md)) + الربط البرمجي + privacy + ToS + disclaimer
8. ✅ Pay the license fee

**Likely outcome:** First-pass approval or 1-2 small findings. Total timeline 6 weeks – 4 months.

**On approval:** Set a calendar reminder 6 weeks before renewal.
**On findings:** Get them in writing. Fix. Resubmit. Repeat.

---

## Part 10 — Things you should write down here as you learn them

(Use this section as a notebook. Add notes after every interaction with the ministry.)

### Contact people
- Name / role / phone / email — _fill in as you meet them_

### Specific submission requirements they asked for
- _fill in_

### Fees actually paid
- _fill in: amount, date, receipt number_

### Submission dates and outcomes
- _fill in: dates, version, outcome, findings_

### Renewal date
- _fill in_

### Notes from each interaction
- _fill in_

---

**Bookmark this file. Update it after every meeting with the ministry. It will save you weeks the second time around.**
