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
                  src="https://fxsqfgtlkitvghwjwaeq.supabase.co/storage/v1/object/public/app.files/logo/docsera_white.png"
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
                  منصة الرعاية الطبية الرقمية
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
    // 3️⃣ SMTP via TLS (mailbox.org – port 465)
    // ------------------------------------------------------------
    const host = Deno.env.get("SMTP_HOST")!;
    const port = Number(Deno.env.get("SMTP_PORT")!); // 465
    const user = Deno.env.get("SMTP_USER")!;
    const pass = Deno.env.get("SMTP_PASS")!;
    const from = Deno.env.get("SMTP_FROM")!;

    const conn = await Deno.connectTls({
      hostname: host,
      port,
    });

    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    const send = async (cmd: string) => {
      await conn.write(encoder.encode(cmd + "\r\n"));
      const buf = new Uint8Array(1024);
      await conn.read(buf);
    };

    await send("EHLO docsera.app");
    await send("AUTH LOGIN");
    await send(btoa(user));
    await send(btoa(pass));
    await send(`MAIL FROM:<${user}>`);
    await send(`RCPT TO:<${email}>`);
    await send("DATA");
    await send(
      `From: ${from}
To: ${email}
Subject: ${subject}
Content-Type: text/html; charset=UTF-8

${html}
.`
    );
    await send("QUIT");

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
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 }
    );
  }
});
