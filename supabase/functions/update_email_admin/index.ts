
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const { email } = await req.json();

    if (!email || typeof email !== "string") {
      return new Response(
        JSON.stringify({ error: "Invalid email" }),
        { status: 400 }
      );
    }

    // ------------------------------------------------------------
    // 1️⃣ Verify User (Get ID from JWT)
    // ------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401 });
    }

    // Create a client with the user's token to verify identity
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await userClient.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const userId = user.id;

    // ------------------------------------------------------------
    // 2️⃣ Admin Client (Service Role)
    // ------------------------------------------------------------
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ------------------------------------------------------------
    // 3️⃣ Update Auth User (Silent Update)
    // ------------------------------------------------------------
    // email_confirm: true -> marks it as verified directly
    const { error: updateError } = await adminClient.auth.admin.updateUserById(
      userId,
      { email: email, email_confirm: true }
    );

    if (updateError) {
      console.error("Admin update error:", updateError);
      return new Response(
        JSON.stringify({ error: "Failed to update email" }),
        { status: 500 }
      );
    }

    // ------------------------------------------------------------
    // 4️⃣ Sync public.users table (Silent Update)
    // ------------------------------------------------------------
    const { error: dbError } = await adminClient
      .from("users")
      .update({ email: email })
      .eq("id", userId);

    if (dbError) {
      console.error("DB sync error:", dbError);
      // Note: Auth is updated, so we might want to return success with a warning, 
      // or error out. Returning error for safety.
      return new Response(
        JSON.stringify({ error: "Failed to update user profile" }),
        { status: 500 }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200 }
    );

  } catch (e) {
    console.error("update_email_admin error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 }
    );
  }
});
