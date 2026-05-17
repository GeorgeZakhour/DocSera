import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const { email, purpose } = await req.json(); // ✅ Get purpose

    if (!email || typeof email !== "string") {
      return new Response(
        JSON.stringify({ error: "Invalid email" }),
        { status: 400 }
      );
    }

    // ------------------------------------------------------------
    // Supabase service client (Edge only)
    // ------------------------------------------------------------
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ------------------------------------------------------------
    // Per-IP rate limit (anti-abuse / anti-enumeration). Caps OTP requests
    // from a single IP at 30/hour. Phone/email-level limits already exist;
    // this is the complementary limit for IPs rotating identifiers.
    // ------------------------------------------------------------
    const fwdHeader =
      req.headers.get("x-forwarded-for") ||
      req.headers.get("cf-connecting-ip") ||
      "";
    const ip = fwdHeader.split(",")[0].trim();
    const { data: ipOk, error: ipErr } = await supabase.rpc(
      "rpc_check_otp_ip_rate",
      { p_email: email, p_ip: ip }
    );
    if (ipErr) {
      console.error("[Security] IP rate-limit RPC error:", ipErr);
      // Fail open — don't lock out users on internal errors.
    } else if (ipOk === false) {
      return new Response(
        JSON.stringify({
          error: "OTP_TOO_FREQUENT",
          message: "Too many requests from this network. Please try again later.",
        }),
        { status: 429, headers: { "Content-Type": "application/json" } }
      );
    }

    // ------------------------------------------------------------
    // BYPASS PATHS — two independent mechanisms write a hashed OTP row
    // and skip the Mailgun send. rpc_verify_email_otp looks up rows by
    // hash, so we have to insert (not just return 200).
    //
    // 1) Reviewer path: ALWAYS ON for the single configured email.
    //    Set REVIEWER_EMAIL + REVIEWER_EMAIL_OTP on the VPS and hand
    //    those credentials to App Store / Play Store reviewers in
    //    their App Review Information field. No env-var toggle —
    //    this works regardless of ALLOW_TEST_OTP.
    //
    // 2) Dev-test path: gated on ALLOW_TEST_OTP. Three accepted forms,
    //    backwards-compatible:
    //      - empty or "false"          → off
    //      - "true"                    → on (legacy, no auto-expiry)
    //      - ISO timestamp e.g.        → on until that time
    //        "2026-05-17T20:00:00Z"      (auto-expires; safest in prod)
    //    The test OTP code (default "123456") and the email patterns
    //    that qualify (default the legacy @doctor.com / @member.com /
    //    @email.com set) can be overridden via env so prod operators
    //    can rotate the OTP without code edits.
    //
    // Production: the dev-test path MUST be off (ALLOW_TEST_OTP unset
    // or "false") most of the time. Flip it on briefly via timestamp
    // when you need to test with a fake account, e.g.:
    //
    //    ALLOW_TEST_OTP="$(date -u -v+2H +%Y-%m-%dT%H:%M:%SZ)"
    //    supabase functions deploy send_email_otp ...
    //
    // The bypass auto-disables once now > the timestamp, even if you
    // forget to flip it back.
    // ------------------------------------------------------------

    const normalizedEmail = email.trim().toLowerCase();

    const reviewerEmail = (Deno.env.get("REVIEWER_EMAIL") ?? "")
      .trim()
      .toLowerCase();
    const reviewerOtp = (Deno.env.get("REVIEWER_EMAIL_OTP") ?? "").trim();
    const isReviewer =
      reviewerEmail !== "" &&
      reviewerOtp !== "" &&
      normalizedEmail === reviewerEmail;

    const testOtpCode =
      (Deno.env.get("TEST_EMAIL_OTP") ?? "").trim() || "123456";

    // CSV of substrings the email must endsWith() to qualify; default
    // is the legacy hardcoded set so existing test workflows still work.
    const patternsCsv = (Deno.env.get("TEST_EMAIL_PATTERNS") ?? "").trim();
    const testPatterns =
      patternsCsv === ""
        ? ["@doctor.com", "@member.com", "@email.com"]
        : patternsCsv
            .split(",")
            .map((s) => s.trim().toLowerCase())
            .filter((s) => s.length > 0);

    const matchesDevTestPattern =
      /^test\d+@docsera\.dev$/.test(normalizedEmail) ||
      testPatterns.some((p) => normalizedEmail.endsWith(p));

    const isDevTest = isDevTestOtpActive() && matchesDevTestPattern;

    // Pick the bypass code, if any. Reviewer wins over dev-test in the
    // unlikely overlap where the reviewer email matches a dev pattern.
    let bypassCode: string | null = null;
    let bypassReason = "";
    if (isReviewer) {
      bypassCode = reviewerOtp;
      bypassReason = "reviewer";
    } else if (isDevTest) {
      bypassCode = testOtpCode;
      bypassReason = "dev-test";
    }

    if (bypassCode !== null) {
      const otpPurpose =
        (purpose as string | undefined) || "signup_email_verify";
      const codeHash = await sha256Hex(bypassCode);
      // Invalidate any prior unconsumed rows so the latest one wins.
      await supabase
        .from("email_otps")
        .update({ consumed_at: new Date().toISOString() })
        .eq("email", normalizedEmail)
        .eq("purpose", otpPurpose)
        .is("consumed_at", null);
      const { error: insertErr } = await supabase
        .from("email_otps")
        .insert({
          email: normalizedEmail,
          code_hash: codeHash,
          purpose: otpPurpose,
          expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
        });
      if (insertErr) {
        console.error(
          `[${bypassReason} bypass] send_email_otp insert failed for ${normalizedEmail}:`,
          insertErr,
        );
        return new Response(
          JSON.stringify({ error: "Failed to generate OTP" }),
          { status: 500, headers: { "Content-Type": "application/json" } },
        );
      }
      console.log(
        `[${bypassReason} bypass] send_email_otp wrote row for ${normalizedEmail} (purpose=${otpPurpose})`,
      );
      return new Response(
        JSON.stringify({ success: true }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // ------------------------------------------------------------
    // 0️⃣ Security Check: Verify email belongs to DocSera user
    // ------------------------------------------------------------
    console.log(`[Debug] Checking existence for email: ${email}`);

    // Check 'users' table
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("id, email")
      .ilike("email", email)
      .maybeSingle();

    if (userError) console.error("[Debug] User check error:", userError);
    else console.log(`[Debug] User found: ${!!user ? JSON.stringify(user) : 'false'}`);

    // If not found, return FAKE SUCCESS (Security: Anti-Enumeration)
    // EXCEPTION: Allow 'signup_email_verify' purpose even if user doesn't exist yet,
    // as this is used during the registration flow before the profile is created.
    if (!user && purpose !== "signup_email_verify") {
      console.log(`[Security] OTP requested for non-existent email: ${email} -> RETURNING FAKE SUCCESS`);
      // Return 200 OK as if sent
      return new Response(
        JSON.stringify({ success: true }),
        { status: 200, headers: {'Content-Type': 'application/json'} }
      );
    }

    console.log(`[Debug] User exists. Generating OTP...`);

    // ------------------------------------------------------------
    // 1️⃣ Create OTP via RPC
    // ------------------------------------------------------------
    const { data, error } = await supabase.rpc("rpc_create_email_otp", {
      p_email: email,
      p_purpose: purpose || "signup_email_verify", // ✅ Use provided purpose or default
    });

if (error) {
  if (error.message?.includes('OTP_TOO_FREQUENT')) {
    return new Response(
      JSON.stringify({
        error: 'OTP_TOO_FREQUENT',
        message: 'Please wait before requesting another code',
      }),
      { status: 429 }
    );
  }

  console.error("OTP RPC error:", error);
  return new Response(
    JSON.stringify({ error: "Failed to generate OTP" }),
    { status: 500 }
  );
}


    const code = data.code;
    const expiresAt = new Date(data.expires_at);

    const minutes = Math.max(
      1,
      Math.round((expiresAt.getTime() - Date.now()) / 60000)
    );

    // ------------------------------------------------------------
    // 2️⃣ Email content
    // ------------------------------------------------------------
    const subject = "رمز التحقق - دوكسيرا";

    const html = `
    <!DOCTYPE html>
    <html lang="ar" dir="rtl">
    <head>
      <meta charset="UTF-8" />
      <title>رمز التحقق - دوكسيرا</title>
    </head>

    <body style="
      margin:0;
      padding:0;
      background-color:#f4f6f8;
      font-family: Tahoma, Arial, Helvetica, sans-serif;
      direction: rtl;
    ">

    <!-- ================= FULL WIDTH HEADER ================= -->
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td style="background-color:#009688;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td align="center" style="padding:24px 16px 32px 16px;">

                <!-- App Logo -->
                <img
                  src="https://api.docsera.app/storage/v1/object/public/app.files/logo/docsera_white.png"
                  alt="Docsera"
                  width="140"
                  style="
                    display:block;
                    margin:0 auto 6px auto;
                    border:0;
                    outline:none;
                    text-decoration:none;
                  "
                />

                <div style="
                  font-size:12px;
                  color:#e6fffa;
                  opacity:0.95;
                ">
                  Care you trust
                </div>

              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>

    <!-- ================= CURVE ================= -->
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td style="background-color:#009688;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td style="
                background-color:#f4f6f8;
                height:42px;
                border-top-left-radius:100% 42px;
                border-top-right-radius:100% 42px;
              ">
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>

    <!-- ================= BODY CARD ================= -->
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td align="center" style="padding:24px 16px 32px 16px;">

          <table width="100%" cellpadding="0" cellspacing="0" style="
            max-width:560px;
            background-color:#ffffff;
            border-radius:18px;
            box-shadow:0 8px 22px rgba(0,0,0,0.08);
          ">
            <tr>
              <td style="padding:32px 24px; text-align:center;">

                <h2 style="
                  margin:0 0 12px 0;
                  font-size:20px;
                  font-weight:700;
                  color:#1f2937;
                ">
                  رمز التحقق
                </h2>

                <p style="
                  margin:0 0 22px 0;
                  font-size:14px;
                  color:#4b5563;
                  line-height:1.7;
                ">
                  يرجى استخدام هذا الرمز لإتمام عملية التحقق في
                  <strong>دوكسيرا</strong>.
                </p>

                <!-- OTP -->
                <div style="
                  display:inline-block;
                  background-color:#ecfdf5;
                  color:#009688;
                  font-size:30px;
                  font-weight:700;
                  letter-spacing:6px;
                  padding:14px 26px;
                  border-radius:12px;
                  margin-bottom:18px;
                ">
                  ${code}
                </div>

                <p style="
                  margin:0;
                  font-size:13px;
                  color:#6b7280;
                ">
                  هذا الرمز صالح لمدة <strong>${minutes} دقائق</strong>.
                </p>

                <!-- Info -->
                <p style="
                  margin:16px 0 0 0;
                  font-size:13px;
                  color:#6b7280;
                  line-height:1.6;
                ">
                  <span style="display:block;">
                    إذا لم تطلب هذا الرمز، يمكنك تجاهل هذه الرسالة بأمان.
                  </span>
                  <span style="display:block; margin-top:6px;">
                    لا تشارك رمز التحقق مع أي شخص حفاظًا على أمان حسابك.
                  </span>
                </p>

              </td>
            </tr>
          </table>

        </td>
      </tr>
    </table>

    <!-- ================= GMAIL CLIP FIX (TECHNICAL FOOTER) ================= -->
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td align="center" style="
          padding:12px 16px 24px 16px;
          font-size:11px;
          line-height:1.6;
          color:#9ca3af;
          font-family: Tahoma, Arial, Helvetica, sans-serif;
        ">
          <div>
            فريق دوكسيرا – DocSera<br>
            <a href="mailto:support@docsera.app"
               style="color:#9ca3af;text-decoration:none;">
              support@docsera.app
            </a>
          </div>
        </td>
      </tr>
    </table>

    </body>
    </html>
    `;






    // ------------------------------------------------------------
    // 3️⃣ SMTP via TLS (mailgun.org – port 465)
    // ------------------------------------------------------------
    const host = Deno.env.get("SMTP_HOST")!;
    const port = Number(Deno.env.get("SMTP_PORT")!); // Should be 465
    // Use PATIENT-SPECIFIC credentials to avoid conflict with Pro app
    const smtpUser = Deno.env.get("SMTP_USER_PATIENT")!;
    const pass = Deno.env.get("SMTP_PASS_PATIENT")!;
    const from = Deno.env.get("SMTP_FROM")!;

    if (!smtpUser || !pass) {
        console.error("[Debug] Missing SMTP_USER_PATIENT or SMTP_PASS_PATIENT env vars");
        return new Response(
          JSON.stringify({ error: "SMTP Configuration Error" }),
          { status: 500 }
        );
    }

    const conn = await Deno.connectTls({
      hostname: host,
      port,
    });

    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    const debugSteps: string[] = [];

    const send = async (cmd: string) => {
      debugSteps.push(`Sending: ${cmd.substring(0, 15)}...`);
      await conn.write(encoder.encode(cmd + "\r\n"));
      const buf = new Uint8Array(1024);
      const readBytes = await conn.read(buf);
      if (readBytes) {
        debugSteps.push(`Received: ${decoder.decode(buf.subarray(0, readBytes)).trim()}`);
      }
    };

    try {
      debugSteps.push("Connecting...");
      await send("EHLO docsera.app");
      await send("AUTH LOGIN");
      await send(btoa(smtpUser));
      await send(btoa(pass));
      await send(`MAIL FROM:<${smtpUser}>`);
      await send(`RCPT TO:<${email}>`);
      await send("DATA");
      
      const emailBody = `From: ${from}
To: ${email}
Subject: ${subject}
Content-Type: text/html; charset=UTF-8

${html}
.`.replace(/\n/g, "\r\n");

      await send(emailBody);
      await send("QUIT");
    } catch (smtpError) {
      debugSteps.push(`SMTP Error: ${smtpError instanceof Error ? smtpError.message : String(smtpError)}`);
      conn.close();
      return new Response(
        JSON.stringify({ error: "SMTP transaction failed", debug: debugSteps }),
        { status: 500 }
      );
    }

    conn.close();

    // ------------------------------------------------------------
    // 4️⃣ Success response (no OTP returned)
    // ------------------------------------------------------------
    return new Response(
      JSON.stringify({ success: true }),
      { status: 200 }
    );
  } catch (e) {
    console.error("send_email_otp error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error", debug: e instanceof Error ? e.message : String(e) }),
      { status: 500 }
    );
  }
});

// SHA-256 helper used by the bypass paths. Same shape as the helper
// in Pro's send_doctor_otp so the hashed OTP row is in the exact format
// the verify RPC (rpc_verify_email_otp) expects.
async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/// Parse ALLOW_TEST_OTP. Returns true iff the dev-test bypass should
/// be active right now. Backwards-compatible with the prior boolean
/// form. Unrecognised input fails closed (returns false) so a typo
/// can't accidentally leave the bypass open.
///
///   unset / ""              → false
///   "false" (any case)      → false
///   "true"  (any case)      → true  (legacy; no auto-expiry)
///   "2026-05-17T20:00:00Z"  → true iff Date.now() < that time
///   anything else           → false (safe failure)
function isDevTestOtpActive(): boolean {
  const v = (Deno.env.get("ALLOW_TEST_OTP") ?? "").trim();
  if (v === "" || v.toLowerCase() === "false") return false;
  if (v.toLowerCase() === "true") return true;
  const expiry = Date.parse(v);
  if (Number.isNaN(expiry)) return false;
  return Date.now() < expiry;
}
