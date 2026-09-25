import 'dart:io';

import 'package:fl_clash/common/path.dart';
import 'package:flutter/foundation.dart';

/// Commands for the separately installed root module. This is deliberately
/// independent of FlClash's backup, restore and profile storage.
class RootModuleControl {
  static const executable =
      '/data/adb/modules/flclash_root/bin/flclash-root';

  @visibleForTesting
  ProcessResult Function(String, List<String>) run = Process.run;

  Future<bool> get isInstalled async =>
      (await run('su', ['-c', 'test -x $executable'])).exitCode == 0;

  Future<void> configure() async {
    final path = await appPath.configFilePath;
    // The path is written by the app, never supplied as shell text by a user.
    // Keep it within this app's files directory before passing it to su.
    final home = await appPath.homeDirPath;
    if (path != '$home/config.yaml' ||
        !RegExp(
          r'^/data/(?:user/[0-9]+|data)/com\.follow\.clash(?:\.dev)?/files$',
        ).hasMatch(home)) {
      throw StateError('Unexpected FlClash config path: $path');
    }
    await _run('configure', argument: path);
  }

  Future<bool> status() async {
    final result = await _execute('status');
    if (result.exitCode == 0) return true;
    if (result.exitCode == 1 && result.stdout.toString().trim() == 'stopped') {
      return false;
    }
    throw StateError('Root module status failed: ${result.stderr}');
  }

  Future<void> start() => _run('start');

  Future<void> stop() => _run('stop');

  Future<void> restart() => _run('restart');

  Future<void> enable() => _run('enable');

  Future<void> disable() => _run('disable');

  Future<bool> get isEnabled async {
    final result = await _execute('enabled');
    return result.exitCode == 0;
  }

  Future<void> test() => _run('test');

  Future<void> _run(String action, {String? argument}) async {
    final result = await _execute(action, argument: argument);
    if (result.exitCode != 0) {
      throw StateError(
        'Root module $action failed: ${result.stderr.toString().trim()}',
      );
    }
  }

  Future<ProcessResult> _execute(String action, {String? argument}) {
    final command = argument == null
        ? '$executable $action'
        : '$executable $action $argument';
    return run('su', ['-c', command]);
  }
}
