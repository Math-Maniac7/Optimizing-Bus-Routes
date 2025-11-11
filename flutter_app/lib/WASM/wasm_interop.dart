//It's deprecated but it works, so
import 'dart:js_util' as util;
import 'dart:js' as js;

Future<String> phase_1(String input) async {
  final module = js.context['Module'];

  // Allocate input string
  final inptr = module.callMethod('allocateUTF8', [input]);
  final json_out = module.callMethod('_malloc', [4]); // char**

  // Call C++ function
  final outptr = module.callMethod('__Z5do_p1PcPS_', [inptr, json_out]);


  //The C++ function uses emscripten_sleep to handle async processing while returning control to the main loop
  //This causes problems for us because it means that this function resumes once we hit sleep, and while the api fetch
  //occurs in the background this function just returns a null pointer and moves on.
  //Local testing would be entirely invalidated (and much of the software would have to be rewritten) if we 
  //decided to move to a more asyncronous way of handling api calls
  //Instead, we periodically check to see if our output pointer has changed, then we return the value which we recieved. 
  while (module.callMethod('__Z20json_out_to_C_stringPPc', [json_out]) == 0){
    await Future.delayed(Duration(milliseconds: 500));
  }

  // Free input pointer
  module.callMethod('_free', [inptr]);

  String output;
  try {
    // Convert output pointer to Dart string
    output = module.callMethod('UTF8ToString', [module.callMethod('__Z20json_out_to_C_stringPPc', [json_out])]);
  } finally {
    // Free output pointers to avoid memory leak
    module.callMethod('_free', [outptr]);
    module.callMethod('_free', [module.callMethod('__Z20json_out_to_C_stringPPc', [json_out])]);
    module.callMethod('_free', [json_out]);
  }

  return output;
}

Future<String> phase_2(String input) async {
  final module = js.context['Module'];

  // Allocate input string
  final inptr = module.callMethod('allocateUTF8', [input]);
  final json_out = module.callMethod('_malloc', [4]); // char**

  // Call C++ function
  final outptr = module.callMethod('__Z5do_p2PcPS_', [inptr, json_out]);


  //The C++ function uses emscripten_sleep to handle async processing while returning control to the main loop
  while (module.callMethod('__Z20json_out_to_C_stringPPc', [json_out]) == 0){
    await Future.delayed(Duration(milliseconds: 500));
  }

  // Free input pointer
  module.callMethod('_free', [inptr]);

  String output;
  try {
    // Convert output pointer to Dart string
    output = module.callMethod('UTF8ToString', [module.callMethod('__Z20json_out_to_C_stringPPc', [json_out])]);
  } finally {
    // Free output pointers to avoid memory leak
    module.callMethod('_free', [outptr]);
    module.callMethod('_free', [module.callMethod('__Z20json_out_to_C_stringPPc', [json_out])]);
    module.callMethod('_free', [json_out]);
  }

  return output;
}

Future<String> phase_3(String input) async {
  final module = js.context['Module'];

  // Allocate input string
  final inptr = module.callMethod('allocateUTF8', [input]);
  final json_out = module.callMethod('_malloc', [4]); // char**

  // Call C++ function
  final outptr = module.callMethod('__Z5do_p3PcPS_', [inptr, json_out]);


  //The C++ function uses emscripten_sleep to handle async processing while returning control to the main loop
  while (module.callMethod('__Z20json_out_to_C_stringPPc', [json_out]) == 0){
    await Future.delayed(Duration(milliseconds: 500));
  }

  // Free input pointer
  module.callMethod('_free', [inptr]);

  String output;
  try {
    // Convert output pointer to Dart string
    output = module.callMethod('UTF8ToString', [module.callMethod('__Z20json_out_to_C_stringPPc', [json_out])]);
  } finally {
    // Free output pointers to avoid memory leak
    module.callMethod('_free', [outptr]);
    module.callMethod('_free', [module.callMethod('__Z20json_out_to_C_stringPPc', [json_out])]);
    module.callMethod('_free', [json_out]);
  }

  return output;
}