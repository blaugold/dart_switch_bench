import 'dart:convert';
import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';

class DecodeJSONBenchmark extends BenchmarkBase {
  const DecodeJSONBenchmark() : super('DecodeJSON');

  static final jsonString = File('benchmark/sample.json').readAsStringSync();

  @override
  void run() {
    for (var i = 0; i < 10; i++) {
      json.decode(jsonString);
    }
  }
}

void main() {
  DecodeJSONBenchmark().report();
}
