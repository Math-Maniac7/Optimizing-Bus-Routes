//It's deprecated but it works, so
import 'dart:js_util' as util;
import 'dart:js' as js;

String phase_1(String input) {
  final module = js.context['Module'];

  // Allocate input string
  final inptr = module.callMethod('allocateUTF8', [input]);

  // Call C++ function
  final outptr = module.callMethod('__Z5do_p1Pc', [inptr]);

  // Free input pointer
  module.callMethod('_free', [inptr]);

  String output;
  try {
    // Convert output pointer to Dart string
    output = module.callMethod('UTF8ToString', [outptr]);
  } finally {
    // Free output pointer to avoid memory leak
    module.callMethod('_free', [outptr]);
  }

  return output;
}