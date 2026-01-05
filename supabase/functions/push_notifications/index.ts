import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

console.log("Push Notification Function Initialized");

serve(async (req) => {
  try {
    const { record, old_record, type, table, schema } = await req.json();
    
    console.log(`🔔 Webhook received! Type: ${type}, Table: ${table}, Schema: ${schema}`);
    console.log("Payload Record:", JSON.stringify(record));
    if (old_record) console.log("Old Record:", JSON.stringify(old_record));

    if (!record) {
      console.error("❌ No record found in payload");
      return new Response("No record found", { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    let targetUserIds = [];
    let title = "DocSera";
    let body = "";
    let payloadData = "";
    const sound = "default"; // or custom sound

    // ===============================================================
    // 📨 CASE 1: New Message (INSERT on 'messages')
    // ===============================================================
    if (table === "messages") {
        if (type !== 'INSERT') return new Response("Skipped non-insert message", { status: 200 });

        const conversationId = record.conversation_id;
        payloadData = `conversation:${conversationId}`;

        // Fetch conversation to get participants
        const { data: conversation, error: convoError } = await supabase
          .from("conversations")
          .select("doctor_id, patient_id, relative_id")
          .eq("id", conversationId)
          .single();

        if (convoError || !conversation) {
          console.error("Error fetching conversation:", convoError);
          return new Response("Conversation not found", { status: 404 });
        }

        if (record.is_user) {
          targetUserIds.push(conversation.doctor_id);
        } else {
          targetUserIds.push(conversation.patient_id);
          if (conversation.relative_id) {
            targetUserIds.push(conversation.relative_id);
          }
        }

        const senderName = record.sender_name || "DocSera";
        // Force Left-Alignment
        const LTR = '\u200E'; 
        title = `${LTR}💬 ${senderName}`;
        
        const rawBody = record.text;
        if (!rawBody || rawBody.trim() === "") {
            if (record.attachments && record.attachments.length > 0) {
                 const t = record.attachments[0].type;
                 if (t === 'image') body = `${LTR}أرسل صورة 📷`;
                 else if (t === 'pdf') body = `${LTR}أرسل مستند 📄`;
                 else body = `${LTR}أرسل مرفق 📎`;
            } else {
                 body = `${LTR}أرسل رسالة`;
            }
        } else {
            body = `${LTR}${rawBody}`;
        }
    }

    // ===============================================================
    // 🗓️ CASE 2: Appointment Update (UPDATE on 'appointments')
    // ===============================================================
    else if (table === "appointments") {
        console.log("🗓️ Processing Appointment Event");
        if (type !== 'UPDATE') {
             console.log(`Skipping: Type is ${type}, expected UPDATE`);
             return new Response("Skipped non-update appointment", { status: 200 });
        }

        const oldStatus = old_record ? old_record.status : null;
        const newStatus = record.status;
        const oldTime = old_record ? old_record.timestamp : null;
        const newTime = record.timestamp;
        const oldReport = old_record ? old_record.report : null;
        const newReport = record.report;
        
        console.log(`Status Change: ${oldStatus} -> ${newStatus}`);
        console.log(`Time Change: ${oldTime} -> ${newTime}`);

        const doctorName = record.doctor_name || "الطبيب";
        
        const isConfirmedBool = record.is_confirmed;
        const oldConfirmedBool = old_record ? old_record.is_confirmed : null;

        // Force Left-Alignment using Unicode Left-to-Right Mark (U+200E)
        // This hints to the system that the paragraph is LTR (align left) without reversing Arabic letters.
        const LTR = '\u200E'; 

        // 1. Rejected (Pending -> Rejected) OR (Pending -> Cancelled)
        if ( 
            (newStatus === 'rejected' || newStatus === 'cancelled' || newStatus === 'cancelled_by_doctor') && 
            (oldStatus === 'pending' || oldStatus === 'not_arrived' || oldStatus === null || oldStatus === '') &&
            (oldConfirmedBool !== true)
        ) {
            console.log("⛔ Condition: Request Rejected");
            title = `${LTR}⛔ تم رفض طلب الحجز`;
            body = `${LTR}نعتذر، لا يمكن للدكتور ${doctorName} قبول طلبك في هذا الوقت.`;
            if (record.rejection_reason) {
                body += ` ${record.rejection_reason}`;
            }
        }
        // 2. Cancelled (Confirmed -> Cancelled/Rejected)
        // Happens when the doctor cancels an ALREADY confirmed appointment
        else if ( 
            (newStatus === 'cancelled' || newStatus === 'rejected' || newStatus === 'cancelled_by_doctor') && 
            (oldStatus === 'confirmed' || oldConfirmedBool === true) 
        ) {
            console.log("❌ Condition: Confirmed Appointment Cancelled");
            title = `${LTR}❌ تم إلغاء الموعد`;
            body = `${LTR}تم إلغاء موعدك المؤكد مع ${doctorName}.`;
            if (record.rejection_reason) {
                body += ` السبب: ${record.rejection_reason}`;
            }
        }
        // 3. Confirmed
        else if ( 
            (newStatus === 'confirmed' && oldStatus !== 'confirmed') || 
            (isConfirmedBool === true && (old_record ? old_record.is_confirmed !== true : true) && 
             newStatus !== 'rejected' && newStatus !== 'cancelled' && newStatus !== 'cancelled_by_doctor') 
        ) {
            console.log("✅ Condition: Confirmed");
            title = `${LTR}✅ تم تثبيت الحجز`;
            body = `${LTR}تم تأكيد موعدك مع ${doctorName}.`;
        }
        // 4. Rescheduled (Time Changed)
        else if (newTime !== oldTime && (newStatus === 'pending' || newStatus === 'confirmed' || newStatus === 'not_arrived' || newStatus === '')) {
            console.log("🕒 Condition: Rescheduled");
            title = `${LTR}🕒 تم تغيير الموعد`;
            body = `${LTR}تم تغيير وقت موعدك مع ${doctorName}، يرجى مراجعة التطبيق.`;
        } 
        // 5. Medical Report (Added or Updated)
        else if (JSON.stringify(newReport) !== JSON.stringify(oldReport)) {
             console.log("📝 Checking Report Change...");
             console.log("Old Report Type:", typeof oldReport);
             console.log("New Report Type:", typeof newReport);

             const hasNew = newReport && (typeof newReport === 'string' ? newReport.trim().length > 0 : Object.keys(newReport).length > 0);
             const hadOld = oldReport && (typeof oldReport === 'string' ? oldReport.trim().length > 0 : Object.keys(oldReport).length > 0);

             if (hasNew && !hadOld) {
                 console.log("📄 Condition: Report Added");
                 title = `${LTR}📄 تقرير طبي جديد`;
                 body = `${LTR}أضاف الدكتور ${doctorName} تقريراً طبياً لموعدك.`;
                 
                 const relId = record.relative_id || 'null';
                 const patName = record.patient_name || 'Patient';
                 payloadData = `report:${record.id}:${relId}:${patName}`;
             }
             else if (hasNew && hadOld) {
                 console.log("📝 Condition: Report Updated");
                 title = `${LTR}📝 تحديث التقرير الطبي`;
                 body = `${LTR}قام الدكتور ${doctorName} بتعديل التقرير الطبي لموعدك.`;
                 
                 const relId = record.relative_id || 'null';
                 const patName = record.patient_name || 'Patient';
                 payloadData = `report:${record.id}:${relId}:${patName}`;
             }
             else {
                 return new Response("Keep Alive (Report Removed or Empty Check)", { status: 200 });
             }
        }
        else {
            console.log("⚠️ No relevant status change detected.");
            return new Response("No relevant status change", { status: 200 });
        }

        // Notify Patient
        if (record.user_id) {
            targetUserIds.push(record.user_id);
            console.log(`Targeting Patient ID: ${record.user_id}`);
        } else {
             console.error("❌ No user_id in appointment record!");
        }
        
        // Default to appointment payload if not set (by report logic)
        if (payloadData === "") {
             payloadData = `appointment:${record.id}`;
        }
    }
    
    // ===============================================================
    // 📄 CASE 3: Documents (INSERT on 'documents')
    // ===============================================================
    else if (table === "documents") {
        if (type !== 'INSERT') return new Response("Skipped non-insert document", { status: 200 });

        // Notify the patient (and maybe relative? stick to patient for now)
        targetUserIds.push(record.patient_id);
        
        // Try to get doctor name if available, or just generic
        const docName = record.conversation_doctor_name || "الطبيب"; // Custom field? Or generic
        
        title = "📄 مستند جديد";
        body = `أضاف ${docName} مستنداً جديداً لملفك الطبي.`;

        // Payload could be document viewer or health page
        payloadData = `document:${record.id}`;
    }

    // fallback
    else {
        return new Response(`Table ${table} not handled`, { status: 200 });
    }

    if (targetUserIds.length === 0) {
        return new Response("No target users", { status: 200 });
    }

    // ---------------------------------------------------------------
    // 🚀 Send Pushy Notification
    // ---------------------------------------------------------------
    const { data: devices, error: devicesError } = await supabase
      .from("user_devices")
      .select("token")
      .in("user_id", targetUserIds);

    if (devicesError) {
      console.error("Error fetching devices:", devicesError);
      return new Response("Error fetching devices", { status: 500 });
    }

    if (!devices || devices.length === 0) {
      console.log("No devices found for targets");
      return new Response("No devices found", { status: 200 });
    }

    const tokens = devices.map((d) => d.token);
    const pushyApiKey = Deno.env.get("PUSHY_API_KEY");
    if (!pushyApiKey) {
      return new Response("Server Misconfiguration: No Pushy Key", { status: 500 });
    }

    const payload = {
      to: tokens,
      data: {
        title: title,
        body: body,
        payload: payloadData,
        sound: sound
      },
      notification: {
        title: title,
        body: body,
        sound: sound
      }
    };

    const pushyResponse = await fetch("https://api.pushy.me/push?api_key=" + pushyApiKey, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const pushyResult = await pushyResponse.json();
    console.log("Pushy Result:", pushyResult);

    return new Response(JSON.stringify(pushyResult), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Error processing request:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    });
  }
});
