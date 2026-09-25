import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

import 'controller.dart';
import 'desktop/model.dart';
import 'event.dart';
import 'interface.dart';
import 'method.dart';
import 'root_module_control.dart';

class RootCore extends CoreHandlerInterface {
  static final RootCore instance = RootCore();

  final RootModuleControl _module = RootModuleControl();

  Future<bool> get isRunning async =>
      await _module.isEnabled && await _module.status();
  final Map<String, Completer<CoreMethodResponse>> _pending = {};
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  int _nextId = 0;
  final String _sessionId = base64Url.encode(
    List<int>.generate(12, (_) => Random.secure().nextInt(256)),
  );
  int _revision = 0;
  bool _closed = false;

  Future<void> _ensureToken() async {
    final home = await appPath.homeDirPath;
    final file = File('$home/root-control-token');
    if (await file.exists()) return;
    final random = Random.secure();
    final token = List<int>.generate(32, (_) => random.nextInt(256));
    await file.writeAsString(base64Url.encode(token), flush: true);
    await Process.run('chmod', ['600', file.path]);
  }

  @override
  Future<CoreLifecycleResult> start() async {
    if (_closed) throw StateError('Core is closed');
    final revision = ++_revision;
    if (_socket != null) {
      return CoreLifecycleResult(
        revision: revision,
        outcome: CoreLifecycleOutcome.coalesced,
      );
    }
    await CoreController.ensureHomeDir();
    await CoreController.initGeo();
    await _ensureToken();
    await _module.configure();
    await _module.start();
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      17901,
      timeout: const Duration(seconds: 8),
    );
    try {
      final home = await appPath.homeDirPath;
      _sendFrame(
        socket,
        utf8.encode(
          (await File('$home/root-control-token').readAsString()).trim(),
        ),
      );
      _socket = socket;
      _subscription = socket.listen(
        (bytes) {
          if (identical(_socket, socket)) _receive(bytes);
        },
        onDone: () => _disconnected(socket),
        onError: (Object error) => _disconnected(socket),
      );
      await invokeMethod<bool>(
        method: CoreMethod.getIsInit,
        timeout: const Duration(seconds: 8),
      );
      return CoreLifecycleResult(
        revision: revision,
        outcome: CoreLifecycleOutcome.applied,
      );
    } catch (_) {
      _disconnected(socket);
      rethrow;
    }
  }

  @override
  Future<CoreLifecycleResult> restart() async {
    _disconnected();
    await _module.restart();
    return start();
  }

  @override
  Future<CoreLifecycleResult> stop() async {
    final revision = ++_revision;
    _disconnected();
    await _module.stop();
    return CoreLifecycleResult(
      revision: revision,
      outcome: CoreLifecycleOutcome.applied,
    );
  }

  @override
  Future<CoreLifecycleResult> close() async {
    _closed = true;
    _disconnected();
    return CoreLifecycleResult(
      revision: ++_revision,
      outcome: CoreLifecycleOutcome.applied,
    );
  }

  @override
  Future<bool> startListener() async {
    final started = await super.startListener();
    if (started) {
      try {
        await _module.enable();
      } catch (_) {
        await super.stopListener();
        rethrow;
      }
    }
    return started;
  }

  @override
  Future<bool> stopListener() async {
    await _module.disable();
    try {
      final stopped = await super.stopListener();
      if (!stopped) await _module.enable();
      return stopped;
    } catch (_) {
      await _module.enable();
      rethrow;
    }
  }

  // Network suspension is temporary and must not erase the boot preference.
  Future<bool> suspendListener() => super.stopListener();

  Future<bool> resumeListener() => super.startListener();

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    final socket = _socket;
    if (socket == null) throw StateError('Root core is disconnected');
    final id = '$_sessionId-${++_nextId}';
    final pending = Completer<CoreMethodResponse>();
    _pending[id] = pending;
    try {
      _sendFrame(
        socket,
        utf8.encode(
          json.encode(
            CoreMethodCall(id: id, method: method, arguments: arguments),
          ),
        ),
      );
      final response = await pending.future.timeout(
        timeout ?? const Duration(minutes: 3),
      );
      return response.unwrap<T>();
    } finally {
      _pending.remove(id);
    }
  }

  void _sendFrame(Socket socket, List<int> data) {
    final header = ByteData(4)..setUint32(0, data.length, Endian.little);
    socket.add(header.buffer.asUint8List());
    socket.add(data);
  }

  void _receive(Uint8List bytes) {
    _buffer.add(bytes);
    final data = _buffer.takeBytes();
    var offset = 0;
    while (data.length - offset >= 4) {
      final size = ByteData.sublistView(
        data,
        offset,
        offset + 4,
      ).getUint32(0, Endian.little);
      if (size > 64 * 1024 * 1024) {
        _disconnected();
        return;
      }
      if (data.length - offset - 4 < size) break;
      offset += 4;
      Object? payload;
      try {
        payload = json.decode(
          utf8.decode(data.sublist(offset, offset + size)),
        );
      } catch (_) {
        _disconnected();
        return;
      }
      offset += size;
      if (payload is! Map) continue;
      final frame = Map<String, Object?>.from(payload);
      if (frame['method'] == 'message') {
        for (final event in coreEventsFromData(frame['arguments'])) {
          coreEventManager.sendEvent(event);
        }
      } else {
        final response = CoreMethodResponse.fromJson(frame);
        final pending = _pending[response.id];
        if (pending != null && !pending.isCompleted) pending.complete(response);
      }
    }
    if (offset < data.length) _buffer.add(data.sublist(offset));
  }

  void _disconnected([Socket? source]) {
    final socket = _socket;
    if (socket == null || (source != null && !identical(socket, source))) {
      return;
    }
    _socket = null;
    _buffer.takeBytes();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    _subscription = null;
    socket.destroy();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Root core disconnected'));
      }
    }
    _pending.clear();
    if (!_closed) {
      coreEventManager.sendEvent(
        const CoreEvent(
          type: CoreEventType.crash,
          data: 'Root core disconnected',
        ),
      );
    }
  }
}
