// Message decryption helper. Handles the "ENC:" prefix used by the patient
// chat encryption layer (AES-CBC, key fetched via rpc_get_encryption_key_service).
//
// Extracted from the previous monolithic index.ts. Behavior preserved
// byte-for-byte — same key fetch, same cipher params, same padding strip.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

export async function decryptMessage(
  supabase: SupabaseClient,
  encrypted: string,
): Promise<string | null> {
  if (!encrypted.startsWith("ENC:")) return encrypted;

  const { data: keyHex, error: rpcErr } = await supabase.rpc(
    "rpc_get_encryption_key_service",
  );
  if (rpcErr || !keyHex) {
    console.error("❌ Key fetching failed:", rpcErr);
    return null;
  }

  try {
    const combined = Uint8Array.from(
      atob(encrypted.substring(4)),
      (c) => c.charCodeAt(0),
    );
    const iv = combined.slice(0, 16);
    const cipherBytes = combined.slice(16);

    const keyBytes = new Uint8Array(
      keyHex.match(/.{1,2}/g)!.map((byte: string) => parseInt(byte, 16)),
    );
    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      keyBytes,
      { name: "AES-CBC" },
      false,
      ["decrypt"],
    );

    const decryptedBuffer = await crypto.subtle.decrypt(
      { name: "AES-CBC", iv },
      cryptoKey,
      cipherBytes,
    );

    let decoded = new TextDecoder().decode(decryptedBuffer);
    // Strip PKCS#7-style padding if the cipher block left tail bytes.
    try {
      const padLen = decoded.charCodeAt(decoded.length - 1);
      if (padLen > 0 && padLen <= 16) {
        decoded = decoded.substring(0, decoded.length - padLen);
      }
    } catch (_e) {
      // ignore — best-effort padding strip
    }
    return decoded;
  } catch (err) {
    console.error("⚠️ Decryption Error:", err);
    return null;
  }
}
