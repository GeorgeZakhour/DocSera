import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://api.docsera.app',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4c3FmZ3Rsa2l0dmdod2p3YWVxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0MzEzOTIsImV4cCI6MjA2NjAwNzM5Mn0.6utWtX1-RRfYNMv-sJepAQj3sdjDEge0naGNJRpXgHc',
  );

  try {
    print("Testing send_email_otp");
    final res = await supabase.functions.invoke('send_email_otp', body: {'email': 'george.zk96@gmail.com'});
    print("Status: ${res.status}");
    print("Data: ${res.data}");
  } catch (e) {
    print("Error calling send_email_otp: $e");
  }
}
