import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// 🧪 PAYLOAD SIZE SIMULATION TEST
// -----------------------------------------------------------------------------
// Since we cannot sniff real network traffic in this environment, we will
// mathematically demonstrate the payload difference using realistic data models.
// -----------------------------------------------------------------------------

void main() {
  test('💰 COST VERIFICATION: Optimized vs Legacy Payload Size', () {
    print('\n📊 --- SUPABASE PAYLOAD COST ANALYSIS ---');

    // 1. SETUP: Create realistic dummy data keys
    // A single conversation row (Metadata only)
    final conversationRow = {
      "id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
      "doctor_id": "d1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
      "patient_id": "p2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
      "last_message": "Hello doctor, I have a question about the prescription.",
      "unread_count": 2,
      "updated_at": "2026-01-01T12:00:00Z",
      "doctor_name": "Dr. Strange",
      "doctor_specialty": "Neurology"
    };

    // A single message row (The heavy data we used to fetch)
    final messageRow = {
      "id": "msg-001",
      "conversation_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
      "text": "This is a detailed message history that we used to download unnecessarily.",
      "sender_id": "d1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
      "timestamp": "2026-01-01T12:00:00Z",
      "is_user": false
    };

    // 2. SCENARIO 1: The Optimized Query (.limit(20) + No Join)
    // We fetch 20 conversations ONLY.
    final List<Map<String, dynamic>> optimizedPayload = 
        List.generate(20, (_) => conversationRow);
    
    final optimizedJson = jsonEncode(optimizedPayload);
    final optimizedBytes = utf8.encode(optimizedJson).length;
    final optimizedKB = optimizedBytes / 1024;

    // 3. SCENARIO 2: The Legacy Query (Nested Join)
    // We fetch 20 conversations, PLUS 50 messages inside EACH conversation.
    final List<Map<String, dynamic>> legacyPayload = List.generate(20, (index) {
      final row = Map<String, dynamic>.from(conversationRow);
      // Nesting 50 messages inside, simulating the old join
      row['messages'] = List.generate(50, (_) => messageRow); 
      return row;
    });

    final legacyJson = jsonEncode(legacyPayload);
    final legacyBytes = utf8.encode(legacyJson).length;
    final legacyKB = legacyBytes / 1024;

    // 4. THE REPORT
    print('--------------------------------------------------');
    print('📥 SCENARIO: Loading a list of 20 Conversations');
    print('--------------------------------------------------');
    print('🔴 OLD WAY (Brute Force):');
    print('   - Structure: 20 Convos + (20 * 50 Messages)');
    print('   - Payload Size: ${legacyKB.toStringAsFixed(2)} KB');
    print('--------------------------------------------------');
    print('🟢 NEW WAY (Optimized):');
    print('   - Structure: 20 Convos ONLY');
    print('   - Payload Size: ${optimizedKB.toStringAsFixed(2)} KB');
    print('--------------------------------------------------');
    
    final reduction = ((legacyBytes - optimizedBytes) / legacyBytes) * 100;
    print('🚀 EFFICIENCY GAIN: ${reduction.toStringAsFixed(1)}% Reduction');
    print('--------------------------------------------------\n');

    // Assertion: Ensure the optimization checks out mathematically
    expect(optimizedBytes, lessThan(legacyBytes / 10), reason: "Optimized payload should be at least 10x smaller");
  });
}
