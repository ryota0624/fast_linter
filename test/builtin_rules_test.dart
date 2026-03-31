import 'package:fast_linter/src/engine/runner.dart';
import 'package:fast_linter/src/rules/builtin/all.dart';
import 'package:fast_linter/src/rules/builtin/always_declare_return_types.dart';
import 'package:fast_linter/src/rules/builtin/avoid_void_async.dart';
import 'package:fast_linter/src/rules/builtin/directives_ordering.dart';
import 'package:fast_linter/src/rules/builtin/implementation_imports.dart';
import 'package:fast_linter/src/rules/builtin/prefer_single_quotes.dart';
import 'package:fast_linter/src/rules/builtin/public_member_api_docs.dart';
import 'package:fast_linter/src/rules/builtin/unawaited_futures.dart';
import 'package:test/test.dart';

void main() {
  group('prefer_single_quotes', () {
    late LintRunner runner;
    setUp(() => runner = LintRunner(rules: [PreferSingleQuotes()]));

    test('reports double quotes without single quote content', () {
      final d = runner.runOnSource(
        'var x = "hello";\n',
        filePath: '/test.dart',
      );
      expect(d, hasLength(1));
      expect(d.first.code, 'prefer_single_quotes');
    });

    test('allows single quotes', () {
      final d = runner.runOnSource(
        "var x = 'hello';\n",
        filePath: '/test.dart',
      );
      expect(d, isEmpty);
    });

    test('allows double quotes containing single quotes', () {
      final d = runner.runOnSource(
        'var x = "it\'s ok";\n',
        filePath: '/test.dart',
      );
      expect(d, isEmpty);
    });
  });

  group('always_declare_return_types', () {
    late LintRunner runner;
    setUp(() => runner = LintRunner(rules: [AlwaysDeclareReturnTypes()]));

    test('reports function without return type', () {
      final d = runner.runOnSource(
        'foo() {}\n',
        filePath: '/test.dart',
      );
      expect(d, hasLength(1));
      expect(d.first.code, 'always_declare_return_types');
    });

    test('allows function with return type', () {
      final d = runner.runOnSource(
        'void foo() {}\n',
        filePath: '/test.dart',
      );
      expect(d, isEmpty);
    });

    test('reports method without return type', () {
      final d = runner.runOnSource('''
class A {
  foo() {}
}
''', filePath: '/test.dart');
      expect(d, hasLength(1));
    });

    test('allows setter without return type', () {
      final d = runner.runOnSource('''
class A {
  set value(int v) {}
}
''', filePath: '/test.dart');
      expect(d, isEmpty);
    });
  });

  group('directives_ordering', () {
    late LintRunner runner;
    setUp(() => runner = LintRunner(rules: [DirectivesOrdering()]));

    test('reports non-dart import before dart import', () {
      final d = runner.runOnSource('''
import 'package:foo/foo.dart';
import 'dart:core';
''', filePath: '/test.dart');
      expect(d.any((e) => e.code == 'directives_ordering'), isTrue);
    });

    test('allows dart imports first', () {
      final d = runner.runOnSource('''
import 'dart:core';
import 'package:foo/foo.dart';
''', filePath: '/test.dart');
      expect(d, isEmpty);
    });

    test('reports unsorted imports within section', () {
      final d = runner.runOnSource('''
import 'dart:io';
import 'dart:async';
''', filePath: '/test.dart');
      expect(d.any((e) => e.code == 'directives_ordering'), isTrue);
    });

    test('reports export before import ends', () {
      final d = runner.runOnSource('''
import 'dart:core';
export 'dart:async';
import 'dart:io';
''', filePath: '/test.dart');
      expect(d.any((e) => e.code == 'directives_ordering'), isTrue);
    });
  });

  group('public_member_api_docs', () {
    late LintRunner runner;
    setUp(() => runner = LintRunner(rules: [PublicMemberApiDocs()]));

    test('reports public function without doc', () {
      final d = runner.runOnSource(
        'void foo() {}\n',
        filePath: '/project/lib/src/foo.dart',
      );
      expect(d, hasLength(1));
      expect(d.first.code, 'public_member_api_docs');
    });

    test('allows documented function', () {
      final d = runner.runOnSource(
        '/// Does foo.\nvoid foo() {}\n',
        filePath: '/project/lib/src/foo.dart',
      );
      expect(d, isEmpty);
    });

    test('ignores private members', () {
      final d = runner.runOnSource(
        'void _foo() {}\n',
        filePath: '/project/lib/src/foo.dart',
      );
      expect(d, isEmpty);
    });

    test('skips files not in lib/', () {
      final d = runner.runOnSource(
        'void foo() {}\n',
        filePath: '/project/test/foo_test.dart',
      );
      expect(d, isEmpty);
    });

    test('allows override without doc', () {
      final d = runner.runOnSource('''
class A {
  @override
  String toString() => 'A';
}
''', filePath: '/project/lib/src/a.dart');
      // toString has @override so should not be reported
      expect(d.where((e) => e.message.contains('toString')), isEmpty);
    });
  });

  group('avoid_void_async', () {
    late LintRunner runner;
    setUp(() => runner = LintRunner(rules: [AvoidVoidAsync()]));

    test('reports void async function', () {
      final d = runner.runOnSource(
        'void foo() async {}\n',
        filePath: '/test.dart',
      );
      expect(d, hasLength(1));
      expect(d.first.code, 'avoid_void_async');
    });

    test('allows Future<void> async function', () {
      final d = runner.runOnSource(
        'Future<void> foo() async {}\n',
        filePath: '/test.dart',
      );
      expect(d, isEmpty);
    });

    test('allows void sync function', () {
      final d = runner.runOnSource(
        'void foo() {}\n',
        filePath: '/test.dart',
      );
      expect(d, isEmpty);
    });

    test('skips main()', () {
      final d = runner.runOnSource(
        'void main() async {}\n',
        filePath: '/test.dart',
      );
      expect(d, isEmpty);
    });
  });

  group('implementation_imports', () {
    late LintRunner runner;
    setUp(() => runner = LintRunner(rules: [ImplementationImports()]));

    test('reports importing src/ from another package', () {
      final d = runner.runOnSource(
        "import 'package:other_pkg/src/internal.dart';\n",
        filePath: '/project/packages/my_pkg/lib/foo.dart',
      );
      expect(d, hasLength(1));
      expect(d.first.code, 'implementation_imports');
    });

    test('allows importing src/ from own package', () {
      final d = runner.runOnSource(
        "import 'package:my_pkg/src/internal.dart';\n",
        filePath: '/project/packages/my_pkg/lib/foo.dart',
      );
      expect(d, isEmpty);
    });

    test('allows importing public API from another package', () {
      final d = runner.runOnSource(
        "import 'package:other_pkg/other_pkg.dart';\n",
        filePath: '/project/packages/my_pkg/lib/foo.dart',
      );
      expect(d, isEmpty);
    });

    test('allows dart: imports', () {
      final d = runner.runOnSource(
        "import 'dart:core';\n",
        filePath: '/project/packages/my_pkg/lib/foo.dart',
      );
      expect(d, isEmpty);
    });
  });

  group('unawaited_futures', () {
    test('no-op in AST-only mode', () {
      final runner = LintRunner(rules: [UnawaitedFutures()]);
      final d = runner.runOnSource('''
import 'dart:async';
void foo() async {
  Future.delayed(Duration(seconds: 1));
}
''', filePath: '/test.dart');
      expect(d, isEmpty);
    });
  });

  group('createBuiltinRegistry', () {
    test('registers all 7 rules', () {
      final registry = createBuiltinRegistry();
      expect(registry.length, 7);
      expect(registry.getByName('prefer_single_quotes'), isNotNull);
      expect(registry.getByName('always_declare_return_types'), isNotNull);
      expect(registry.getByName('directives_ordering'), isNotNull);
      expect(registry.getByName('implementation_imports'), isNotNull);
      expect(registry.getByName('public_member_api_docs'), isNotNull);
      expect(registry.getByName('avoid_void_async'), isNotNull);
      expect(registry.getByName('unawaited_futures'), isNotNull);
    });
  });
}
