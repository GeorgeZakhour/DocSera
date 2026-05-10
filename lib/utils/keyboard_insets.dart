import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

/// Reads the real keyboard inset, bypassing the Android-only global
/// keyboard-as-overlay override applied in `main.dart`.
///
/// On iOS the global override is not installed, so this just returns
/// the normal MediaQuery value. On Android it pulls the inset directly
/// from `View.of(context)`, which sits below the override.
double realKeyboardInset(BuildContext context) {
  if (!Platform.isAndroid) {
    return MediaQuery.of(context).viewInsets.bottom;
  }
  return MediaQueryData.fromView(View.of(context)).viewInsets.bottom;
}

/// True iff the soft keyboard is currently visible. Android-safe.
bool isKeyboardVisible(BuildContext context) =>
    realKeyboardInset(context) > 0;

/// Restores the real `viewInsets` for a subtree, opting out of the global
/// keyboard-as-overlay override on Android. Wrap a `Scaffold` or a bottom
/// sheet's body with this when you want the keyboard to push content up
/// — e.g. the chat composer or a sheet whose `TextField` must stay above
/// the keyboard.
///
/// Listens to `WidgetsBindingObserver.didChangeMetrics` and rebuilds on
/// every IME show/hide, since the global override suppresses the normal
/// MediaQuery rebuild. On iOS this is a no-op pass-through.
class RealKeyboardInsets extends StatefulWidget {
  final Widget child;
  const RealKeyboardInsets({super.key, required this.child});

  @override
  State<RealKeyboardInsets> createState() => _RealKeyboardInsetsState();
}

class _RealKeyboardInsetsState extends State<RealKeyboardInsets>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (Platform.isAndroid) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return widget.child;
    final mq = MediaQuery.of(context);
    final realInsets = MediaQueryData.fromView(View.of(context)).viewInsets;
    return MediaQuery(
      data: mq.copyWith(viewInsets: realInsets),
      child: widget.child,
    );
  }
}
