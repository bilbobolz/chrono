import 'dart:js_interop';

@JS('chronoPlayBeep')
external void _chronoPlayBeep();

void playCompletionSound() {
  try {
    _chronoPlayBeep();
  } catch (_) {}
}
