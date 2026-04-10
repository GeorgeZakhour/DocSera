/// Arabic text reshaper for PDF generation.
/// Converts standard Arabic Unicode (U+0621-U+064A) into Presentation Forms-B
/// (U+FE70-U+FEFF) so that the `pdf` package renders connected Arabic text.
///
/// Vendored from https://pub.dev/packages/arabic_reshaper (MIT license).
/// Simplified: only core shaping + Lam-Alef ligatures. No harakat, no tatweel.

// ── Constants ──
const int _isolated = 0;
const int _initial = 1;
const int _medial = 2;
const int _final_ = 3;
const int _notSupported = -1;

// ── Letter map: char → [Isolated, Initial, Medial, Final] ──
// Empty string = form not supported (letter doesn't connect that way)
const Map<String, List<String>> _letters = {
  '\u0621': ['\uFE80', '', '', ''],
  '\u0622': ['\uFE81', '', '', '\uFE82'],
  '\u0623': ['\uFE83', '', '', '\uFE84'],
  '\u0624': ['\uFE85', '', '', '\uFE86'],
  '\u0625': ['\uFE87', '', '', '\uFE88'],
  '\u0626': ['\uFE89', '\uFE8B', '\uFE8C', '\uFE8A'],
  '\u0627': ['\uFE8D', '', '', '\uFE8E'],
  '\u0628': ['\uFE8F', '\uFE91', '\uFE92', '\uFE90'],
  '\u0629': ['\uFE93', '', '', '\uFE94'],
  '\u062A': ['\uFE95', '\uFE97', '\uFE98', '\uFE96'],
  '\u062B': ['\uFE99', '\uFE9B', '\uFE9C', '\uFE9A'],
  '\u062C': ['\uFE9D', '\uFE9F', '\uFEA0', '\uFE9E'],
  '\u062D': ['\uFEA1', '\uFEA3', '\uFEA4', '\uFEA2'],
  '\u062E': ['\uFEA5', '\uFEA7', '\uFEA8', '\uFEA6'],
  '\u062F': ['\uFEA9', '', '', '\uFEAA'],
  '\u0630': ['\uFEAB', '', '', '\uFEAC'],
  '\u0631': ['\uFEAD', '', '', '\uFEAE'],
  '\u0632': ['\uFEAF', '', '', '\uFEB0'],
  '\u0633': ['\uFEB1', '\uFEB3', '\uFEB4', '\uFEB2'],
  '\u0634': ['\uFEB5', '\uFEB7', '\uFEB8', '\uFEB6'],
  '\u0635': ['\uFEB9', '\uFEBB', '\uFEBC', '\uFEBA'],
  '\u0636': ['\uFEBD', '\uFEBF', '\uFEC0', '\uFEBE'],
  '\u0637': ['\uFEC1', '\uFEC3', '\uFEC4', '\uFEC2'],
  '\u0638': ['\uFEC5', '\uFEC7', '\uFEC8', '\uFEC6'],
  '\u0639': ['\uFEC9', '\uFECB', '\uFECC', '\uFECA'],
  '\u063A': ['\uFECD', '\uFECF', '\uFED0', '\uFECE'],
  '\u0640': ['\u0640', '\u0640', '\u0640', '\u0640'], // Tatweel
  '\u0641': ['\uFED1', '\uFED3', '\uFED4', '\uFED2'],
  '\u0642': ['\uFED5', '\uFED7', '\uFED8', '\uFED6'],
  '\u0643': ['\uFED9', '\uFEDB', '\uFEDC', '\uFEDA'],
  '\u0644': ['\uFEDD', '\uFEDF', '\uFEE0', '\uFEDE'],
  '\u0645': ['\uFEE1', '\uFEE3', '\uFEE4', '\uFEE2'],
  '\u0646': ['\uFEE5', '\uFEE7', '\uFEE8', '\uFEE6'],
  '\u0647': ['\uFEE9', '\uFEEB', '\uFEEC', '\uFEEA'],
  '\u0648': ['\uFEED', '', '', '\uFEEE'],
  // ى (Alef Maksura) — Cairo Bold lacks PF-B, use base char
  '\u0649': ['\u0649', '', '', '\u0649'],
  // ي (Ya) — Cairo Bold lacks all presentation forms, use base char
  '\u064A': ['\u064A', '\u064A', '\u064A', '\u064A'],
  // Extended Arabic (common for names)
  '\u067E': ['\uFB56', '\uFB58', '\uFB59', '\uFB57'], // Peh
  '\u0686': ['\uFB7A', '\uFB7C', '\uFB7D', '\uFB7B'], // Tcheh
  '\u06A9': ['\uFB8E', '\uFB90', '\uFB91', '\uFB8F'], // Keheh
  '\u06AF': ['\uFB92', '\uFB94', '\uFB95', '\uFB93'], // Gaf
  // Farsi Yeh — Cairo Bold lacks all PF forms, use base Ya char
  '\u06CC': ['\u064A', '\u064A', '\u064A', '\u064A'],
};


// Harakat regex — strip diacritics before shaping
final RegExp _harakatRegex = RegExp(
  '[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06dc\u06df-\u06e8\u06ea-\u06ed]',
);

// ── Connectivity helpers ──

bool _connectsBefore(String letter) {
  final forms = _letters[letter];
  if (forms == null) return false;
  return forms[_final_].isNotEmpty || forms[_medial].isNotEmpty;
}

bool _connectsAfter(String letter) {
  final forms = _letters[letter];
  if (forms == null) return false;
  return forms[_initial].isNotEmpty || forms[_medial].isNotEmpty;
}

bool _connectsBoth(String letter) {
  final forms = _letters[letter];
  if (forms == null) return false;
  return forms[_medial].isNotEmpty;
}

// ── Lam-Alef ligatures ──

const Map<String, List<String>> _lamAlefLigatures = {
  '\u0627': ['\uFEFB', '\uFEFC'], // Lam + Alef → [isolated, final]
  '\u0623': ['\uFEF7', '\uFEF8'], // Lam + Alef Hamza Above
  '\u0625': ['\uFEF9', '\uFEFA'], // Lam + Alef Hamza Below
  '\u0622': ['\uFEF5', '\uFEF6'], // Lam + Alef Madda
};

const String _lam = '\u0644';

// ── Shaped character during processing ──

class _Shaped {
  String letter;
  int form;
  _Shaped(this.letter, this.form);
}

/// Reshape Arabic text for correct PDF rendering.
///
/// Call this on any Arabic string before passing it to `pw.Text()`.
/// Non-Arabic text passes through unchanged.
String reshapeArabic(String text) {
  if (text.isEmpty) return '';

  // Strip harakat (diacritics) — PDF fonts handle them poorly
  final clean = text.replaceAll(_harakatRegex, '');
  if (clean.isEmpty) return '';

  final output = <_Shaped>[];

  // ── Pass 1: Contextual analysis ──
  for (int i = 0; i < clean.length; i++) {
    final letter = clean[i];

    if (!_letters.containsKey(letter)) {
      output.add(_Shaped(letter, _notSupported));
      continue;
    }

    if (output.isEmpty) {
      output.add(_Shaped(letter, _isolated));
      continue;
    }

    final prev = output.last;

    if (prev.form == _notSupported ||
        !_connectsBefore(letter) ||
        !_connectsAfter(prev.letter) ||
        (prev.form == _final_ && !_connectsBoth(prev.letter))) {
      output.add(_Shaped(letter, _isolated));
    } else if (prev.form == _isolated) {
      prev.form = _initial;
      output.add(_Shaped(letter, _final_));
    } else {
      prev.form = _medial;
      output.add(_Shaped(letter, _final_));
    }
  }

  // ── Pass 2: Lam-Alef ligatures (backwards) ──
  for (int i = output.length - 1; i > 0; i--) {
    final cur = output[i];
    final prev = output[i - 1];
    if (prev.letter != _lam) continue;
    final ligature = _lamAlefLigatures[cur.letter];
    if (ligature == null) continue;

    // Determine if ligature is isolated or final
    final isConnectedBefore =
        prev.form == _initial || prev.form == _medial;
    final ligForm = isConnectedBefore ? 1 : 0; // 1=final, 0=isolated

    // Replace prev (lam) with the ligature, remove current (alef)
    output[i - 1] = _Shaped(ligature[ligForm], _notSupported);
    output.removeAt(i);
  }

  // ── Pass 3: Build output ──
  final buf = StringBuffer();
  for (final o in output) {
    if (o.form == _notSupported) {
      buf.write(o.letter);
    } else {
      final forms = _letters[o.letter];
      if (forms != null && forms[o.form].isNotEmpty) {
        buf.write(forms[o.form]);
      } else {
        buf.write(o.letter);
      }
    }
  }
  return buf.toString();
}
