//It's deprecated but it works, so
import 'dart:js' as js;
import 'dart:async';

/// Maximum time to wait for WASM operation to complete (5 minutes)
const Duration _maxWaitTime = Duration(minutes: 5);
const Duration _pollInterval = Duration(milliseconds: 500);

Future<String> phase_1(String input) async {
  final module = js.context['Module'];

  // Allocate input string
  final inptr = module.callMethod('allocateUTF8', [input]);
  final jsonOut = module.callMethod('_malloc', [4]); // char**

  // Call C++ function
  module.callMethod('__Z5do_p1PcPS_', [inptr, jsonOut]);

  //The C++ function uses emscripten_sleep to handle async processing while returning control to the main loop
  //This causes problems for us because it means that this function resumes once we hit sleep, and while the api fetch
  //occurs in the background this function just returns a null pointer and moves on.
  //Local testing would be entirely invalidated (and much of the software would have to be rewritten) if we 
  //decided to move to a more asyncronous way of handling api calls
  //Instead, we periodically check to see if our output pointer has changed, then we return the value which we recieved. 
  
  final startTime = DateTime.now();
  while (module.callMethod('__Z20json_out_to_C_stringPPc', [jsonOut]) == 0) {
    // Check for timeout
    if (DateTime.now().difference(startTime) > _maxWaitTime) {
      // Free input pointer before throwing
      module.callMethod('_free', [inptr]);
      module.callMethod('_free', [jsonOut]);
      throw TimeoutException(
        'Route generation timed out after ${_maxWaitTime.inMinutes} minutes. '
        'The Overpass API may be experiencing issues. Please try again later.',
        _maxWaitTime,
      );
    }
    await Future.delayed(_pollInterval);
  }

  // Free input pointer
  module.callMethod('_free', [inptr]);

  String output;
  final resultPtr = module.callMethod('__Z20json_out_to_C_stringPPc', [jsonOut]);
  try {
    // Convert output pointer to Dart string
    if (resultPtr == 0) {
      throw Exception('WASM Error: empty result pointer');
    }
    output = module.callMethod('UTF8ToString', [resultPtr]);
    
    // Check if output is an error message
    if (output.startsWith('error ') || output.contains('ERROR') || output.contains('Overpass HTTP')) {
      throw Exception('WASM Error: $output');
    }
  } finally {
    // Free output pointers to avoid memory leak
    module.callMethod('_free', [resultPtr]);
    module.callMethod('_free', [jsonOut]);
  }

  return output;
}

Future<String> phase_2(String input) async {
  final module = js.context['Module'];

  // Allocate input string
  final inptr = module.callMethod('allocateUTF8', [input]);
  final jsonOut = module.callMethod('_malloc', [4]); // char**

  // Call C++ function
  module.callMethod('__Z5do_p2PcPS_', [inptr, jsonOut]);

  //The C++ function uses emscripten_sleep to handle async processing while returning control to the main loop
  final startTime = DateTime.now();
  while (module.callMethod('__Z20json_out_to_C_stringPPc', [jsonOut]) == 0) {
    // Check for timeout
    if (DateTime.now().difference(startTime) > _maxWaitTime) {
      // Free input pointer before throwing
      module.callMethod('_free', [inptr]);
      module.callMethod('_free', [jsonOut]);
      throw TimeoutException(
        'Route generation timed out after ${_maxWaitTime.inMinutes} minutes. '
        'The Overpass API may be experiencing issues. Please try again later.',
        _maxWaitTime,
      );
    }
    await Future.delayed(_pollInterval);
  }

  // Free input pointer
  module.callMethod('_free', [inptr]);

  String output;
  final resultPtr = module.callMethod('__Z20json_out_to_C_stringPPc', [jsonOut]);
  try {
    // Convert output pointer to Dart string
    if (resultPtr == 0) {
      throw Exception('WASM Error: empty result pointer');
    }
    output = module.callMethod('UTF8ToString', [resultPtr]);
    
    // Check if output is an error message
    if (output.startsWith('error ') || output.contains('ERROR') || output.contains('Overpass HTTP')) {
      throw Exception('WASM Error: $output');
    }
  } finally {
    // Free output pointers to avoid memory leak
    module.callMethod('_free', [resultPtr]);
    module.callMethod('_free', [jsonOut]);
  }

  return output;
}

Future<String> phase_3(String input) async {
  final module = js.context['Module'];

  // Allocate input string
  final inptr = module.callMethod('allocateUTF8', [input]);
  final jsonOut = module.callMethod('_malloc', [4]); // char**

  // Call C++ function
  module.callMethod('__Z5do_p3PcPS_', [inptr, jsonOut]);

  //The C++ function uses emscripten_sleep to handle async processing while returning control to the main loop
  final startTime = DateTime.now();
  while (module.callMethod('__Z20json_out_to_C_stringPPc', [jsonOut]) == 0) {
    // Check for timeout
    if (DateTime.now().difference(startTime) > _maxWaitTime) {
      // Free input pointer before throwing
      module.callMethod('_free', [inptr]);
      module.callMethod('_free', [jsonOut]);
      throw TimeoutException(
        'Route generation timed out after ${_maxWaitTime.inMinutes} minutes. '
        'The Overpass API may be experiencing issues. Please try again later.',
        _maxWaitTime,
      );
    }
    await Future.delayed(_pollInterval);
  }

  // Free input pointer
  module.callMethod('_free', [inptr]);

  String output;
  final resultPtr = module.callMethod('__Z20json_out_to_C_stringPPc', [jsonOut]);
  try {
    // Convert output pointer to Dart string
    if (resultPtr == 0) {
      throw Exception('WASM Error: empty result pointer');
    }
    output = module.callMethod('UTF8ToString', [resultPtr]);
    
    // Check if output is an error message
    if (output.startsWith('error ') || output.contains('ERROR') || output.contains('Overpass HTTP')) {
      throw Exception('WASM Error: $output');
    }
  } finally {
    // Free output pointers to avoid memory leak
    module.callMethod('_free', [resultPtr]);
    module.callMethod('_free', [jsonOut]);
  }

  return output;
}
