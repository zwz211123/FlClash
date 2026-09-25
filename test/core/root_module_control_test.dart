import 'dart:io';

import 'package:fl_clash/core/root_module_control.dart';
import 'package:test/test.dart';

void main() {
  late RootModuleControl module;
  late List<String> commands;
  var exitCode = 0;
  var stdout = '';
  var stderr = '';

  setUp(() {
    module = RootModuleControl();
    commands = [];
    exitCode = 0;
    stdout = '';
    stderr = '';
    module.run = (executable, arguments) async {
      expect(executable, 'su');
      expect(arguments, hasLength(2));
      expect(arguments.first, '-c');
      commands.add(arguments.last);
      return ProcessResult(42, exitCode, stdout, stderr);
    };
  });

  test('status distinguishes a live daemon from an orderly stop', () async {
    expect(await module.status(), isTrue);
    exitCode = 1;
    stdout = 'stopped\n';
    expect(await module.status(), isFalse);
    expect(
      commands,
      everyElement('${RootModuleControl.executable} status'),
    );
  });

  test('status surfaces a failed root command', () async {
    exitCode = 1;
    stderr = 'permission denied';
    await expectLater(
      module.status(),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('permission denied'),
      )),
    );
  });

  test('start and stop operate the separate module', () async {
    await module.start();
    await module.stop();
    expect(commands, [
      '${RootModuleControl.executable} start',
      '${RootModuleControl.executable} stop',
    ]);
  });

  test('failed enable does not report success to the app', () async {
    exitCode = 1;
    stderr = 'root denied';
    await expectLater(
      module.enable(),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        contains('root denied'),
      )),
    );
    expect(commands.single, '${RootModuleControl.executable} enable');
  });

  test('restart, disable and configuration test use the module entrypoint', () async {
    await module.restart();
    await module.disable();
    await module.test();
    expect(commands, [
      '${RootModuleControl.executable} restart',
      '${RootModuleControl.executable} disable',
      '${RootModuleControl.executable} test',
    ]);
  });

  test('installation detection checks the executable as root', () async {
    expect(await module.isInstalled, isTrue);
    exitCode = 1;
    expect(await module.isInstalled, isFalse);
    expect(commands, everyElement('test -x ${RootModuleControl.executable}'));
  });

  test('boot preference is reported separately from process status', () async {
    exitCode = 1;
    expect(await module.isEnabled, isFalse);
    exitCode = 0;
    expect(await module.isEnabled, isTrue);
    expect(commands, everyElement('${RootModuleControl.executable} enabled'));
  });
}
