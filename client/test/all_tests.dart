import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart' as ft;

import 'switching_router_test.dart';
import 'memory_pipeline_test.dart';
import 'contradiction_resolution_test.dart';
import 'edge_bundle_test.dart';
import 'eval_rater_test.dart';
import 'gemma_edge_test.dart';
import 'local_execution_test.dart';
import 'live_cloud_switching_test.dart';
import 'markdown_formatting_test.dart';
import 'memory_notebook_studio_test.dart';
import 'lorecraft_studio_test.dart';

class TestCase {
  final String suite;
  final String name;
  final dynamic Function() body;
  TestCase(this.suite, this.name, this.body);
}

class TestRunner {
  final List<TestCase> _tests = [];
  int passed = 0;
  int failed = 0;
  final List<String> failures = [];
  String currentSuite = '';

  void register(String name, dynamic Function() body) {
    _tests.add(TestCase(currentSuite, name, body));
  }

  void expect(bool condition, [String? message]) {
    if (!condition) {
      throw Exception(message ?? 'Assertion failed');
    }
  }

  Future<void> runAll() async {
    String? lastSuite;
    for (final t in _tests) {
      if (t.suite != lastSuite) {
        stdout.writeln('\n${t.suite}');
        lastSuite = t.suite;
      }
      try {
        final res = t.body();
        if (res is Future) {
          await res;
        }
        passed++;
        stdout.writeln('  ✓ [PASS] ${t.name}');
      } catch (e, st) {
        failed++;
        failures.add('${t.name}\n    Error: $e\n$st');
        stdout.writeln('  ✗ [FAIL] ${t.name}');
        stdout.writeln('    Error: $e');
      }
    }
  }
}

void main() {
  ft.test(
    'Antigravity Client Test Suite: All tests across 9 suites',
    timeout: const ft.Timeout(Duration(minutes: 2)),
    () async {
      final runner = TestRunner();
      final stopwatch = Stopwatch()..start();

      stdout.writeln('===========================================================');
      stdout.writeln(' ANTIGRAVITY DISTRIBUTED AI CLIENT // TEST SUITE');
      stdout.writeln('===========================================================');

      runner.currentSuite = '[1/9] SWITCHING ROUTER & PII TESTS:';
      runSwitchingRouterTests(runner.register, runner.expect);

      runner.currentSuite = '[2/9] MEMORY PIPELINE TESTS:';
      runMemoryPipelineTests(runner.register, runner.expect);

      runner.currentSuite = '[3/9] CONTRADICTION RESOLUTION & AFFORDANCE TESTS:';
      runContradictionResolutionTests(runner.register, runner.expect);

      runner.currentSuite = '[4/9] COMPACT EDGE BUNDLE TESTS:';
      runEdgeBundleTests(runner.register, runner.expect);

      runner.currentSuite = '[5/9] LLM-AS-A-RATER EVALUATION TESTS:';
      runEvalRaterTests(runner.register, runner.expect);

      runner.currentSuite = '[6/9] GEMMA 4 EDGE ENGINE TESTS:';
      runGemmaEdgeTests(runner.register, runner.expect);

      runner.currentSuite = '[7/9] LOCAL EXECUTION MANAGER & CHROME PROMPT API TESTS:';
      runLocalExecutionTests(runner.register, runner.expect);

      runner.currentSuite = '[8/9] LIVE CLOUD RUN INTEGRATION & SWITCHING TESTS:';
      runLiveCloudSwitchingTests(runner.register, runner.expect);

      runner.currentSuite = '[9/10] MARKDOWN FORMATTING & PARSING TESTS:';
      runMarkdownFormattingTests(runner.register, runner.expect);

      runner.currentSuite = '[10/11] MEMORY NOTEBOOK & PATTERN SIMULATOR TESTS:';
      runMemoryNotebookStudioTests(runner.register, runner.expect);

      runner.currentSuite = '[11/11] LORECRAFT DYNAMIC WORLD & NPC ENGINE TESTS:';
      runLoreCraftTests(runner.register, runner.expect);

      await runner.runAll();

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;

    stdout.writeln('\n===========================================================');
    stdout.writeln(' TEST EXECUTION SUMMARY');
    stdout.writeln('===========================================================');
    stdout.writeln('Total Tests:  ${runner.passed + runner.failed}');
    stdout.writeln('Passed:       ${runner.passed}');
    stdout.writeln('Failed:       ${runner.failed}');
    stdout.writeln('Elapsed Time: ${elapsedMs}ms');

    if (runner.failed == 0) {
      stdout.writeln('\n🎉 ALL TESTS PASSED SUCCESSFULLY (100% PASS RATE)!');
      stdout.writeln('===========================================================');
    } else {
      stdout.writeln('\n❌ TEST RUN FAILED!');
      for (final f in runner.failures) {
        stdout.writeln(f);
      }
      stdout.writeln('===========================================================');
    }

    ft.expect(runner.failed, 0, reason: 'All unit & integration tests across 10 suites must pass');
  });
}

