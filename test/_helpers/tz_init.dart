// Tests that touch any DocSeraTime / model-with-timestamp code MUST call
// initTzForTests() in setUpAll. Without it, the timezone DB is empty and
// any DocSeraTime.nowSyria() / tryParseToSyria() throws LocationNotFoundException.

import 'package:docsera/utils/time_utils.dart';

bool _initialized = false;

void initTzForTests() {
  if (_initialized) return;
  initializeTimeZonesOnce();
  _initialized = true;
}
