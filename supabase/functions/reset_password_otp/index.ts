import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
    }

    const { email, code, newPassword } = await req.json();

    if (!email || !code || !newPassword) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // ------------------------------------------------------------
    // Supabase Admin Client (Service Role)
    // ------------------------------------------------------------
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ------------------------------------------------------------
    // 1️⃣ Verify OTP (Consumes it)
    // ------------------------------------------------------------
    const { data: isValid, error: otpError } = await supabase.rpc("rpc_verify_email_otp", {
      p_email: email,
      p_code: code,
      p_purpose: "forgot_password",
    });

    if (otpError) {
      console.error("OTP Verification Error:", otpError);
      return new Response(
        JSON.stringify({ error: "Database error during verification" }),
        { status: 500, headers: corsHeaders }
      );
    }

    if (isValid !== true) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired code" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // ------------------------------------------------------------
    // 2️⃣ Get User ID
    // ------------------------------------------------------------
    // We look up in public.users to find the UUID
    const { data: userRow, error: userError } = await supabase
      .from("users")
      .select("id")
      .ilike("email", email)
      .maybeSingle();

    if (userError || !userRow) {
      return new Response(
        JSON.stringify({ error: "User not found" }),
        { status: 404, headers: corsHeaders }
      );
    }

    // ------------------------------------------------------------
    // 3️⃣ Update Password (Admin)
    // ------------------------------------------------------------
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userRow.id,
      { password: newPassword }
    );

    if (updateError) {
      console.error("Update Password Error:", updateError);
      return new Response(
        JSON.stringify({ error: "Failed to update password" }),
        { status: 500, headers: corsHeaders }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: corsHeaders }
    );

  } catch (e) {
    console.error("reset_password_otp error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: corsHeaders }
    );
  }
});
