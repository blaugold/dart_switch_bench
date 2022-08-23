import 'dart:io';

import 'package:path/path.dart';

import 'dispatch_benchmark_gen.dart';

final dartSdk =
    '${Platform.environment['HOME']}/fvm/default/bin/cache/dart-sdk';
final dartBin = '$dartSdk/bin/dart';
final genKernelSnapshot = '$dartSdk/bin/snapshots/gen_kernel.dart.snapshot';
final genSnapshotBin = '$dartSdk/bin/utils/gen_snapshot';
final dartAotRuntimeBin = '$dartSdk/bin/dartaotruntime';
final platform = '$dartSdk/lib/_internal/vm_platform_strong.dill';

const decodeJsonBenchmark = 'benchmark/decode_json.dart';
const dispatchBenchmark = 'benchmark/dispatch.g.dart';

const globalVmFlags = [
  // '--print_flow_graph',
  // '--print_flow_graph_filter=IntSwitchBenchmark.dispatch',
  // '--print_flow_graph_filter=_ChunkedJsonParser.parse',
  // '--print_inlining_tree',
  // '--trace_inlining',
  // '--disassemble',
  // '--disassemble_relative',
];

Future<void> runAot(String file, {List<String> vmFlags = const []}) async {
  file = absolute(file);
  await runCmd(dartBin, [
    genKernelSnapshot,
    '--platform',
    platform,
    '--aot',
    file,
  ]);

  final dillFile = '$file.dill';
  final elfFile = '$file.elf';

  await runCmd(genSnapshotBin, [
    ...globalVmFlags,
    ...vmFlags,
    '--snapshot_kind=app-aot-elf',
    '--elf=$elfFile',
    dillFile,
  ]);

  await runCmd(dartAotRuntimeBin, [elfFile]);
}

Future<void> runJit(String file, {List<String> vmFlags = const []}) async {
  await runCmd(dartBin, [...globalVmFlags, ...vmFlags, file]);
}

Future<void> runCmd(String file, List<String> args) async {
  final process = await Process.start(
    file,
    args,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    print('Failed to run $file $args');
    exit(exitCode);
  }
}

Future<void> runDispatchBenchmark({
  required int branches,
  required bool optimized,
}) async {
  final vmFlags = [
    if (!optimized) '--force-switch-dispatch-type=0',
  ];

  generateDispatchBenchmark(branches: branches, invocations: 200);

  print('Dispatch benchmark: branches: $branches, optimized: $optimized');

  print('JIT');
  await runJit(dispatchBenchmark, vmFlags: vmFlags);

  print('AOT');
  await runAot(dispatchBenchmark, vmFlags: vmFlags);

  print(''); // Newline.
}

Future<void> runDecodeJsonBenchmark({
  required bool optimized,
}) async {
  final vmFlags = [
    if (!optimized) '--force-switch-dispatch-type=0',
  ];

  print('Decode JSON benchmark: optimized: $optimized');

  print('JIT');
  await runJit(decodeJsonBenchmark, vmFlags: vmFlags);

  print('AOT');
  await runAot(decodeJsonBenchmark, vmFlags: vmFlags);

  print(''); // Newline.
}

void main() async {
  for (final branches in [8, 16, 32, 64]) {
    await runDispatchBenchmark(branches: branches, optimized: false);
    await runDispatchBenchmark(branches: branches, optimized: true);
  }

  await runDecodeJsonBenchmark(optimized: false);
  await runDecodeJsonBenchmark(optimized: true);
}
