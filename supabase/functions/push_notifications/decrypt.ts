// Message decryption helper for the push-notification renderer.
//
// Handles two prefixes produced by the patient chat encryption layer:
//   "ENCv2:" → AES-256-GCM (current format, AEAD with 128-bit auth tag).
//              Layout: base64(nonce(12) || ciphertext || tag(16))
//   "ENC:"   → AES-256-CBC + PKCS7 (legacy format, decrypt-only).
//              Layout: base64(iv(16) || ciphertext)
//
// Strings without either prefix are returned unchanged (assumed plain text).
// Key is fetched via rpc_get_encryption_key_service.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const PREFIX_V2 = "ENCv2:";
const PREFIX_V1 = "ENC:";
const GCM_NONCE_LENGTH = 12;
const GCM_TAG_BITS = 128;
const CBC_IV_LENGTH = 16;

export async function decryptMessage(
  supabase: SupabaseClient,
  encrypted: string,
): Promise<string | null> {
  if (encrypted.startsWith(PREFIX_V2)) {
    return await _decryptGcm(supabase, encrypted);
  }
  if (encrypted.startsWith(PREFIX_V1)) {
    return await _decryptCbcLegacy(supabase, encrypted);
  }
  return encrypted;
}

async function _fetchKeyBytes(
  supabase: SupabaseClient,
): Promise<Uint8Array | null> {
  const { data: keyHex, error: rpcErr } = await supabase.rpc(
    "rpc_get_encryption_key_service",
  );
  if (rpcErr || !keyHex) {
    console.error("❌ Key fetching failed:", rpcErr);
    return null;
  }
  return new Uint8Array(
    keyHex.match(/.{1,2}/g)!.map((byte: string) => parseInt(byte, 16)),
  );
}

async function _decryptGcm(
  supabase: SupabaseClient,
  encrypted: string,
): Promise<string | null> {
  const keyBytes = await _fetchKeyBytes(supabase);
  if (!keyBytes) return null;

  try {
    const combined = Uint8Array.from(
      atob(encrypted.substring(PREFIX_V2.length)),
      (c) => c.charCodeAt(0),
    );
    // Minimum length: 12-byte nonce + 16-byte tag (empty ciphertext).
    if (combined.length < GCM_NONCE_LENGTH + (GCM_TAG_BITS / 8)) return null;

    const iv = combined.slice(0, GCM_NONCE_LENGTH);
    // Web Crypto's AES-GCM expects ciphertext+tag concatenated.
    const cipherBytes = combined.slice(GCM_NONCE_LENGTH);

    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      keyBytes,
      { name: "AES-GCM" },
      false,
      ["decrypt"],
    );
    const decryptedBuffer = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv, tagLength: GCM_TAG_BITS },
      cryptoKey,
      cipherBytes,
    );
    return new TextDecoder().decode(decryptedBuffer);
  } catch (err) {
    console.error("⚠️ GCM Decryption Error:", err);
    return null;
  }
}

async function _decryptCbcLegacy(
  supabase: SupabaseClient,
  encrypted: string,
): Promise<string | null> {
  const keyBytes = await _fetchKeyBytes(supabase);
  if (!keyBytes) return null;

  try {
    const combined = Uint8Array.from(
      atob(encrypted.substring(PREFIX_V1.length)),
      (c) => c.charCodeAt(0),
    );
    const iv = combined.slice(0, CBC_IV_LENGTH);
    const cipherBytes = combined.slice(CBC_IV_LENGTH);

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
    // Defensive PKCS#7 padding strip — Web Crypto typically auto-strips,
    // but the original monolith carried this and we preserve byte-for-byte.
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
    console.error("⚠️ CBC Decryption Error:", err);
    return null;
  }
}
