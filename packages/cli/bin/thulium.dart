import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:thulium_cli/cli_auth_session_store.dart';
import 'package:thulium_cli/cli_command_runner.dart';

Future<void> main(List<String> arguments) async {
  try {
    await ThuliumCommandRunner().run(arguments);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  } on CliAuthStorageException catch (error) {
    stderr.writeln('Secure storage error: ${error.message}');
    stderr.writeln(
      'Make sure an operating system keyring is available and unlocked.',
    );
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 2;
  } catch (error) {
    stderr.writeln('Error: $error');
    exitCode = 1;
  }
}
