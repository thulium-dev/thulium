import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:thulium_cli/cli_command_runner.dart';
import 'package:thulium_cli/cli_runtime.dart';

void main() {
  test('all levels of help avoid executing account operations', () async {
    final output = <String>[];
    final runtime = _Runtime();
    final runner = ThuliumCommandRunner(
      runtime: runtime,
      writeLine: output.add,
    );
    for (final arguments in <List<String>>[
      [],
      ['--help'],
      ['help'],
      ['session'],
      for (final name in [
        'login',
        'logout',
        'status',
        'session',
        'schedule',
        'learn-courses',
        'learn-homework',
        'learn-materials',
        'learn-materials-cover',
      ])
        [name, '--help'],
      ['help', 'learn-materials', 'download'],
      ['learn-materials-cover', 'download', '--help'],
    ]) {
      output.clear();
      await runner.run(arguments);
      expect(output.join('\n'), contains('Usage: thulium'));
      expect(runtime.calls, isEmpty);
    }
  });

  test(
    'existing account, session and campus commands retain dispatch and flags',
    () async {
      final runtime = _Runtime();
      final runner = ThuliumCommandRunner(runtime: runtime);
      final cases = <String, List<String>>{
        'login': ['login', '--force', '--verbose'],
        'logout': ['logout'],
        'status': ['status'],
        'inspect': ['session', 'inspect'],
        'reveal': ['session', 'reveal-cookies'],
        'schedule': ['schedule', '--refresh'],
        'courses': ['learn-courses', '-s', '2026-2027-1'],
        'homework': ['learn-homework', '--refresh'],
      };
      for (final entry in cases.entries) {
        await runner.run(entry.value);
        expect(runtime.calls.last.$1, entry.key);
      }
      expect(runtime.calls.first.$2['force'], isTrue);
      expect(runtime.calls.first.$2['verbose'], isTrue);
      expect(runtime.calls.last.$2['refresh'], isTrue);
    },
  );

  test(
    'legacy list, explicit list and cover aliases retain options and precedence',
    () async {
      final runtime = _Runtime();
      final runner = ThuliumCommandRunner(runtime: runtime);
      await runner.run(['learn-materials', '--size', '7', '--refresh']);
      expect(runtime.calls.last.$1, 'materials');
      expect(runtime.calls.last.$2['size'], '7');
      expect(runtime.calls.last.$2['refresh'], isTrue);
      await runner.run([
        'learn-materials',
        '--size',
        '7',
        'list',
        '--size',
        '9',
      ]);
      expect(runtime.calls.last.$2['size'], '9');
      await runner.run([
        'learn-materials',
        '--verbose',
        'download',
        '--file-id',
        'file',
        '--course-id',
        'course',
      ]);
      expect(runtime.calls.last.$1, 'full');
      expect(runtime.calls.last.$2['verbose'], isTrue);
      for (final prefix in [
        ['learn-materials-cover'],
        ['learn-materials-cover', 'download'],
      ]) {
        await runner.run([
          ...prefix,
          '--file-id',
          'file',
          '--course-id',
          'course',
        ]);
        expect(runtime.calls.last.$1, 'cover');
      }
    },
  );

  test(
    'invalid input gets relevant usage before accessing an account',
    () async {
      final runner = ThuliumCommandRunner();
      for (final args in <List<String>>[
        ['missing'],
        ['login', '--missing'],
        ['status', 'unexpected'],
        ['learn-materials', 'missing'],
        ['learn-materials', '--size', '0'],
        ['learn-materials', 'download'],
        ['learn-materials-cover', '--file-id', 'bad/path'],
      ]) {
        await expectLater(runner.run(args), throwsA(isA<UsageException>()));
      }
    },
  );
}

class _Runtime extends CliRuntime {
  final calls = <(String, Map<String, dynamic>)>[];
  Future<void> record(String name, Map<String, dynamic> options) async =>
      calls.add((name, options));
  @override
  Future<void> login(Map<String, dynamic> options) => record('login', options);
  @override
  Future<void> logout(Map<String, dynamic> options) =>
      record('logout', options);
  @override
  Future<void> status(Map<String, dynamic> options) =>
      record('status', options);
  @override
  Future<void> inspectSession(Map<String, dynamic> options) =>
      record('inspect', options);
  @override
  Future<void> revealCookies(Map<String, dynamic> options) =>
      record('reveal', options);
  @override
  Future<void> schedule(Map<String, dynamic> options) =>
      record('schedule', options);
  @override
  Future<void> courses(Map<String, dynamic> options) =>
      record('courses', options);
  @override
  Future<void> homework(Map<String, dynamic> options) =>
      record('homework', options);
  @override
  Future<void> materials(Map<String, dynamic> options) async =>
      calls.add(('materials', options));
  @override
  Future<void> downloadMaterial(
    Map<String, dynamic> options, {
    bool cover = false,
  }) async => calls.add((cover ? 'cover' : 'full', options));
}
