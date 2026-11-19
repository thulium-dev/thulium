import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'cli_runtime.dart';

/// Standard args command dispatch, with compatibility for implicit list and
/// cover-download operations in earlier versions of the CLI.
class ThuliumCommandRunner extends CommandRunner<void> {
  ThuliumCommandRunner({CliRuntime? runtime, void Function(String)? writeLine})
    : writeLine = writeLine ?? stdout.writeln,
      super(
        'thulium',
        'Tsinghua campus services from your terminal.',
        usageLineLength: 100,
      ) {
    final operations = runtime ?? CliRuntime();
    addCommand(
      _ActionCommand(
        'login',
        'Sign in and save the session in the operating system keyring.',
        operations.login,
        category: 'Account',
        configure: (parser) {
          parser.addFlag(
            'force',
            abbr: 'f',
            help: 'Ignore the stored session and log in again.',
          );
          _verbose(parser);
        },
        examples: ['thulium login', 'thulium login --force --verbose'],
      ),
    );
    addCommand(
      _ActionCommand(
        'logout',
        'Sign out and clear the saved session and course caches.',
        operations.logout,
        category: 'Account',
      ),
    );
    addCommand(
      _ActionCommand(
        'status',
        'Show whether a session is stored and which account it belongs to.',
        operations.status,
        category: 'Account',
      ),
    );
    final session = _ActionCommand(
      'session',
      'Inspect stored session metadata or explicitly reveal cookies.',
      null,
      category: 'Account',
    );
    session.addSubcommand(
      _ActionCommand(
        'inspect',
        'Show cookie scope and expiration without revealing values.',
        operations.inspectSession,
      ),
    );
    session.addSubcommand(
      _ActionCommand(
        'reveal-cookies',
        'Reveal cookie values after confirmation in an interactive terminal.',
        operations.revealCookies,
      ),
    );
    addCommand(session);
    addCommand(
      _ActionCommand(
        'schedule',
        'Show the current academic calendar.',
        operations.schedule,
        category: 'Campus',
        configure: (parser) {
          _verbose(parser);
          parser.addFlag(
            'refresh',
            help: 'Fetch the latest calendar instead of using the cache.',
          );
        },
        examples: ['thulium schedule --refresh'],
      ),
    );
    addCommand(
      _ActionCommand(
        'learn-courses',
        'List semester courses as YAML.',
        operations.courses,
        category: 'Learn',
        configure: _catalogOptions,
        examples: [
          'thulium learn-courses',
          'thulium learn-courses --semester 2026-2027-1 --refresh',
        ],
      ),
    );
    addCommand(
      _ActionCommand(
        'learn-homework',
        'Show assignment counts for all semester courses as YAML.',
        operations.homework,
        category: 'Learn',
        configure: _catalogOptions,
        examples: ['thulium learn-homework --semester 2026-2027-1'],
      ),
    );
    final materials = _ActionCommand(
      'learn-materials',
      'List course materials or download a complete PDF.',
      null,
      category: 'Learn',
      configure: _materialOptions,
      examples: [
        'thulium learn-materials',
        'thulium learn-materials list --course-id COURSE_ID',
        'thulium learn-materials download --course-id COURSE_ID --file-id FILE_ID -o material.pdf',
      ],
    );
    materials.addSubcommand(
      _ActionCommand(
        'list',
        'List material metadata as YAML; defaults to up to 200 files per course.',
        operations.materials,
        configure: _materialOptions,
      ),
    );
    materials.addSubcommand(
      _ActionCommand(
        'download',
        'Download all pages of the PDF representation.',
        operations.downloadMaterial,
        configure: _downloadOptions,
        examples: [
          'thulium learn-materials download --course-id COURSE_ID --file-id FILE_ID -o material.pdf',
        ],
      ),
    );
    addCommand(materials);
    final cover = _ActionCommand(
      'learn-materials-cover',
      'Download the first-page PDF cover preview.',
      null,
      category: 'Learn',
      configure: (parser) => _downloadOptions(parser, cover: true),
      examples: [
        'thulium learn-materials-cover --course-id COURSE_ID --file-id FILE_ID -o cover.pdf',
      ],
    );
    cover.addSubcommand(
      _ActionCommand(
        'download',
        'Download the first-page PDF cover preview.',
        (options) => operations.downloadMaterial(options, cover: true),
        configure: (parser) => _downloadOptions(parser, cover: true),
      ),
    );
    addCommand(cover);
  }

  final void Function(String) writeLine;

  @override
  String get usageFooter =>
      'Examples:\n  thulium login\n  thulium learn-materials --course-id COURSE_ID\n  thulium help learn-materials download';

  @override
  void printUsage() => writeLine(usage);

  @override
  ArgResults parse(Iterable<String> args) {
    final arguments = args.toList();
    final parsed = super.parse(arguments);
    final command = parsed.command;
    // Only supply an implicit operation when no explicit/unknown subcommand
    // or help request is present. args remains responsible for all dispatch.
    if (command != null &&
        command.command == null &&
        command.rest.isEmpty &&
        !parsed.flag('help') &&
        !command.flag('help')) {
      final implicit = {
        'learn-materials': 'list',
        'learn-materials-cover': 'download',
        'session': '--help',
      }[command.name];
      if (implicit != null) return super.parse([...arguments, implicit]);
    }
    return parsed;
  }
}

typedef _Action = Future<void> Function(Map<String, dynamic> options);

class _ActionCommand extends Command<void> {
  _ActionCommand(
    this.name,
    this.description,
    this.action, {
    this.category = '',
    void Function(ArgParser)? configure,
    this.examples = const [],
  }) {
    configure?.call(argParser);
  }

  @override
  final String name;
  @override
  final String description;
  @override
  final String category;
  @override
  bool get takesArguments => false;

  final _Action? action;
  final List<String> examples;

  @override
  String? get usageFooter => examples.isEmpty
      ? null
      : 'Examples:\n${examples.map((example) => '  $example').join('\n')}';

  @override
  void printUsage() => (runner! as ThuliumCommandRunner).writeLine(usage);

  @override
  Future<void> run() async {
    final options = <String, dynamic>{};
    // Preserve parent flags used before a subcommand; explicitly supplied leaf
    // options take precedence, otherwise use the parent's supplied value.
    final lineage = <Command<void>>[];
    for (Command<void>? node = this; node != null; node = node.parent) {
      lineage.insert(0, node);
    }
    for (final node in lineage) {
      final results = node.argResults!;
      for (final key in results.options) {
        if (!options.containsKey(key) || results.wasParsed(key)) {
          options[key] = results[key];
        }
      }
    }
    try {
      await action!(options);
    } on FormatException catch (error) {
      usageException(error.message);
    }
  }
}

void _verbose(ArgParser parser) =>
    parser.addFlag('verbose', help: 'Print safe request diagnostics.');

void _catalogOptions(ArgParser parser) {
  parser.addOption(
    'semester',
    abbr: 's',
    valueHelp: 'ID',
    help: 'Academic semester ID (defaults to the current semester).',
  );
  _verbose(parser);
  parser.addFlag(
    'refresh',
    help: 'Fetch the latest course catalog instead of using the cache.',
  );
}

void _materialOptions(ArgParser parser) {
  _catalogOptions(parser);
  parser.addOption(
    'course-id',
    valueHelp: 'ID',
    help: 'List only this course from the semester catalog.',
  );
  parser.addOption(
    'size',
    valueHelp: 'COUNT',
    defaultsTo: '200',
    help: 'Maximum materials requested per course; not a total count.',
  );
}

void _downloadOptions(ArgParser parser, {bool cover = false}) {
  parser.addOption(
    'file-id',
    valueHelp: 'ID',
    help: 'Required. File ID from the material list.',
  );
  parser.addOption(
    'course-id',
    valueHelp: 'ID',
    help: 'Required. Course ID that owns the file.',
  );
  parser.addOption(
    'output',
    abbr: 'o',
    valueHelp: 'PATH',
    help: 'Destination (defaults to FILE_ID${cover ? '-cover' : ''}.pdf).',
  );
  parser.addFlag(
    'force',
    negatable: false,
    help: 'Replace an existing output file.',
  );
  _verbose(parser);
}
