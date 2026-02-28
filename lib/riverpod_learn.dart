

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final name = Provider<String>((ref){
  return "Hello World! Flutter App!!";
});


final counter = StateProvider<int>((ref){
  return 0;
});

final counter1 = StateProvider<int>((ref){
  return 0;
});