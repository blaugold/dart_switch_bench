import 'dart:io';

void main(List<String> args) {
  var branches = 32;
  var invocations = 200;

  if (args.isNotEmpty) {
    branches = int.parse(args[0]);
  }
  if (args.length > 1) {
    invocations = int.parse(args[1]);
  }

  generateDispatchBenchmark(branches: branches, invocations: invocations);
}

void generateDispatchBenchmark({required int branches, required invocations}) {
  final file = File('benchmark/dispatch.g.dart');

  final buffer = StringBuffer();
  buffer.writeln('''
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:benchmark_harness/benchmark_harness.dart';
''');

  writeFunctions(buffer, branches);
  writeEnum(buffer, branches);
  writeBenchmarkBase(buffer, branches, invocations);
  writeIntSwitchBenchmark(buffer, branches);
  writeEnumSwitchBenchmark(buffer, branches);
  writeIfTreeBenchmark(buffer, branches);
  writeTableBenchmark(buffer, branches);

  writeMain(buffer);
  buffer.writeln();

  file.writeAsStringSync(buffer.toString(), flush: true);

  // Format the file.
  Process.runSync('dart', ['format', file.path], runInShell: true);
}

void writeFunctions(StringBuffer buffer, int branches) {
  for (var i = 0; i < branches; i++) {
    buffer.writeln('''
int _fn$i() => $i;
''');
  }
}

void writeEnum(StringBuffer buffer, int branches) {
  buffer.writeln('enum Enum {');
  for (var i = 0; i < branches; i++) {
    buffer.writeln('_$i,');
  }
  buffer.writeln('}');
}

void writeBenchmarkBase(StringBuffer buffer, int branches, int invocations) {
  buffer.writeln('''
abstract class DispatchBenchmark<T> extends BenchmarkBase {
  DispatchBenchmark(String name) : super('Dispatch(\$name)');

  int dispatch(T v);
}
''');

  buffer.writeln('''
abstract class IntDispatchBenchmark extends DispatchBenchmark<int> {
  IntDispatchBenchmark(String name) : super(name);

  @override
  void run() {
''');

  for (var i = 0; i < invocations; i++) {
    buffer.writeln('dispatch(${i % branches});');
  }

  buffer.writeln('''
  }
}
''');

  buffer.writeln('''
abstract class EnumDispatchBenchmark extends DispatchBenchmark<Enum> {
  EnumDispatchBenchmark(String name) : super(name);

  @override
  void run() {
''');

  for (var i = 0; i < invocations; i++) {
    buffer.writeln('dispatch(Enum._${i % branches});');
  }

  buffer.writeln('''
  }
}
''');
}

void writeIntSwitchBenchmark(StringBuffer buffer, int branches) {
  buffer.writeln(r'''
class IntSwitchBenchmark extends IntDispatchBenchmark {
  IntSwitchBenchmark() : super('int switch');

  @pragma('vm:never-inline')
  @override
  int dispatch(int v) {
    switch (v) {
''');

  for (var i = 0; i < branches; i++) {
    buffer.write('''
case $i:
        return $i;
''');
  }

  buffer.writeln(r'''
    }

    return -1;
  }
}
''');
}

void writeEnumSwitchBenchmark(StringBuffer buffer, int branches) {
  buffer.writeln(r'''
class EnumSwitchBenchmark extends EnumDispatchBenchmark {
  EnumSwitchBenchmark() : super('enum switch');

  @pragma('vm:never-inline')
  @override
  int dispatch(Enum v) {
    switch (v) {
''');

  for (var i = 0; i < branches; i++) {
    buffer.write('''
case Enum._$i:
        return $i;
''');
  }

  buffer.writeln(r'''
    }
  }
}
''');
}

void writeIfTreeBenchmark(StringBuffer buffer, int branches) {
  buffer.writeln(r'''
class IfTreeBenchmark extends IntDispatchBenchmark {
  IfTreeBenchmark() : super('if tree');

  @pragma('vm:never-inline')
  @override
  int dispatch(int v) {
''');

  void writeBranches(int start, int end) {
    if (start == end) {
      buffer.write('return $start;');
      return;
    }

    final mid = (start + end) ~/ 2;
    buffer.write('if (v <= $mid) {');
    writeBranches(start, mid);
    buffer.write('} else {');
    writeBranches(mid + 1, end);
    buffer.write('}');
  }

  writeBranches(0, branches - 1);

  buffer.writeln(r'''
  }
}
''');
}

void writeTableBenchmark(StringBuffer buffer, int branches) {
  buffer.write('''
class FunctionTableBenchmark extends IntDispatchBenchmark {
  FunctionTableBenchmark() : super('function table');

  final _table = [
''');

  for (var i = 0; i < branches; i++) {
    buffer.writeln('''_fn$i,''');
  }

  buffer.writeln(r'''
  ];

  @pragma('vm:never-inline')
  @override
  int dispatch(int v) {
    return _table[v]();
  }
}
''');
}

void writeMain(StringBuffer buffer) {
  buffer.writeln('''
void main() {
  final benchmarks = [
    IntSwitchBenchmark(),
    EnumSwitchBenchmark(),
    IfTreeBenchmark(),
    FunctionTableBenchmark(),
  ];

  for (final benchmark in benchmarks) {
    benchmark.report();
  }
}
''');
}
