import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bridgefy/bridgefy.dart';
import 'package:uuid/uuid.dart';

import 'mlog.dart';

class BridgefyUtils implements BridgefyDelegate {
  BridgefyUtils._();
  static final BridgefyUtils _instance = BridgefyUtils._();

  factory BridgefyUtils() {

    return _instance;
  }

  ///events
  static const syncDataToIpadEvent = 'sync data to ipad';
  static const requestDataEvent = 'request data from ipad';
  static const responseDataEvent = 'response data from ipad';
  static const sendMessageEvent = 'send message to special client';

  static final _ipadUUid = const Uuid().v4();
  static final _clientUUid = const Uuid().v4();
  static const _apkKey = '40a8483d-c2ec-4749-9b09-a85c6957f95e';

  final _bridgefy = Bridgefy();

  bool isInitSdk = false;
  bool isServiceStart = false;
  String? currentUserId;
  String _currentMessageId = "";
  Completer<bool>? _sendMessageProcess;

  Future<List<String>> get listCurrentConnectionPeers =>
      _bridgefy.connectedPeers;

  ///list current user id connected
  final List<String> _currentUsers = [];

  ///clients connected to my node
  ///[clients]
  ///[_currentUsers]
  List<String> get clients {
    return _currentUsers..remove(currentUserId);
  }

  StreamController<FormData>? _controller;

  Future<void> initSdk() async {
    ///start init
    isInitSdk = await _bridgefy.isInitialized;
    if (!isInitSdk) {
      ///start init
      await _bridgefy.initialize(
        apiKey: _apkKey,
        delegate: this,
      );
      isInitSdk = await _bridgefy.isInitialized;
    }
  }

  ///start init ipad server
  Future<void> initIpadServer() async {
    try {
      await _checkHasSessionAndTerminateAndStart();

      ///start service
      await _bridgefy.start(userId: _ipadUUid);
      currentUserId = await _bridgefy.currentUserID;

      _controller ??= StreamController.broadcast();
      isInitSdk = await _bridgefy.isInitialized;

      mLog.message("current user id :$currentUserId");
    } catch (e, t) {
      mLog.error(error: e, t: t);
    }
  }

  ///start init client
  Future<void> initClient() async {
    try {
      await _checkHasSessionAndTerminateAndStart();

      ///start service
      await _bridgefy.start(userId: _clientUUid);
      currentUserId = await _bridgefy.currentUserID;

      _controller ??= StreamController.broadcast();
      isInitSdk = await _bridgefy.isInitialized;

      mLog.message("current user id :$currentUserId");
    } catch (e, t) {
      mLog.error(error: e, t: t);
    }
  }

  ///end session
  Future<void> _checkHasSessionAndTerminate() async {
    try {
      await _bridgefy.destroySession();
      isInitSdk = false;
    } catch (_) {
      mLog.message("not found session");
    }
  }

  ///end session and start
  Future<void> _checkHasSessionAndTerminateAndStart() async {
    try {
      await _bridgefy.destroySession();
      isInitSdk = false;

      await initSdk();
    } catch (_) {
      mLog.message("not found session and starting");
      if(!(await _bridgefy.isInitialized)){
        await initSdk();
      }
    }
  }

  ///after disconnect call this method for start service
  ///for client
  Future<void> reStartService() async {
    isInitSdk = await _bridgefy.isInitialized;
    await _checkHasSessionAndTerminateAndStart();

    ///start service
    await _bridgefy.start(userId: _clientUUid);
    currentUserId = await _bridgefy.currentUserID;

    _controller ??= StreamController.broadcast();
  }

  ///check connect with ipad server
  // Future<bool> _isFoundIpadInConnect() async {
  //   final conn = await _bridgefy.connectedPeers;
  //
  //   bool isFound = false;
  //   await Future.forEach(
  //     conn,
  //     (con) {
  //       isFound = con == _ipadUUid;
  //     },
  //   );
  //
  //   return isFound;
  // }

  ///send data to ipad server
  Future<bool?> sendDataToIpad({required String data}) async {
    assert(isInitSdk, "bridgefy sdk not init");
    assert(isServiceStart, "service not start");

    // final isFoundIpad = await _isFoundIpadInConnect();
    // assert(isFoundIpad, "not found ipad server connect");

    try {
      final request = FormData(
        from: currentUserId ?? '',
        data: data,
        to: 'ipad server',
        event: syncDataToIpadEvent,
      );

      _sendMessageProcess = Completer();
      _currentMessageId = await _bridgefy.send(
        data: request.toJson,
        transmissionMode: BridgefyTransmissionMode(
          type: BridgefyTransmissionModeType.p2p,
          uuid: _ipadUUid,
        ),
      );
    } catch (_) {
      _sendMessageProcess?.complete(false);
    }

    return await _sendMessageProcess?.future;
  }

  ///send data to special client in node peers
  ///[FormData]
  ///require to field
  Future<bool?> sendDataToSpecial({
    required String data,
    required String toClientId,
    required String event,
  }) async {
    assert(isInitSdk, "bridgefy sdk not init");
    assert(isServiceStart, "service not start");
    assert(toClientId.isNotEmpty, "not found special client uuid");
    assert(event.isNotEmpty, "not found event name");

    try {
      final request = FormData(
        from: currentUserId ?? '',
        data: data,
        event: event,
        to: toClientId,
      );

      _sendMessageProcess = Completer();
      _currentMessageId = await _bridgefy.send(
        data: request.toJson,
        transmissionMode: BridgefyTransmissionMode(
          type: BridgefyTransmissionModeType.p2p,
          uuid: request.to,
        ),
      );
    } catch (_) {
      _sendMessageProcess?.complete(false);
    }

    return await _sendMessageProcess?.future;
  }

  ///ipad server subscription message
  Stream<FormData>? get receiverMessageEvent => _controller?.stream;

  ///subscription receiver message from bridgefy sdk and check event and return special event data.
  ///[syncData] is [syncDataToIpadEvent]
  ///[requestData] is [requestDataEvent]
  ///[responseData] is [responseDataEvent]
  void subscriptionMessageAndEvents({
    required void Function(FormData it) syncData,
    required void Function(FormData it) requestData,
    required void Function(FormData it) responseData,
    required void Function(FormData it) unknown,
  }) {
    receiverMessageEvent?.distinct().listen(
          (event) {
        switch (event.event) {
          case syncDataToIpadEvent:
            syncData(event);
            break;
          case requestDataEvent:
            requestData(event);
            break;
          case responseDataEvent:
            requestData(event);
            break;
          default:
            unknown(event);
            break;
        }
      },
    );
  }

  ///disconnect
  ///and clear all instance
  void release() async {
    ///clear data
    _currentUsers.clear();
    await _controller?.close();
    _controller = null;
    isInitSdk = false;

    await _bridgefy.stop();

    try {
      ///disconnect session
      if (isServiceStart) {
        await _checkHasSessionAndTerminate();
        isServiceStart = false;
      }
    } catch (_) {}
  }

  @override
  void bridgefyDidConnect({required String userID}) {
    _currentUsers.add(userID);
  }

  @override
  void bridgefyDidDestroySession() {
    mLog.message('Bridgefy DestroySession');
  }

  @override
  void bridgefyDidDisconnect({required String userID}) {
    _currentUsers.remove(userID);
  }

  @override
  void bridgefyDidEstablishSecureConnection({required String userID}) {}

  @override
  void bridgefyDidFailSendingMessage({
    required String messageID,
    BridgefyError? error,
  }) {
    _sendMessageProcess?.complete(false);
    mLog.message('Bridgefy FailSendingMessage :${error?.message}');
  }

  @override
  void bridgefyDidFailToDestroySession() {}

  @override
  void bridgefyDidFailToEstablishSecureConnection({
    required String userID,
    required BridgefyError error,
  }) {
    mLog.error(error: error);
  }

  @override
  void bridgefyDidFailToStart({required BridgefyError error}) {
    mLog.error(error: error);
  }

  @override
  void bridgefyDidFailToStop({required BridgefyError error}) {}

  @override
  void bridgefyDidReceiveData({
    required Uint8List data,
    required String messageId,
    required BridgefyTransmissionMode transmissionMode,
  }) {
    ///receiver message
    if (data.isEmpty) return;
    _controller
      ?..sink
      ..add(FormData.fromBytes(data));
  }

  @override
  void bridgefyDidSendDataProgress({
    required String messageID,
    required int position,
    required int of,
  }) {}

  @override
  void bridgefyDidSendMessage({required String messageID}) {
    ///check send message success
    if (_currentMessageId == messageID) {
      _sendMessageProcess?.complete(true);
    }
  }

  @override
  void bridgefyDidStart({required String currentUserID}) {
    isServiceStart = true;
  }

  @override
  void bridgefyDidStop() {
    isServiceStart = false;
    mLog.message('Bridgefy Stop');
  }
}

final bridgefyUtils = BridgefyUtils();

class FormData {
  ///user id
  ///[from]
  final String from;

  /// json data
  /// [data]
  final String data;

  ///to connect peers id
  String to;

  ///event such as: sync data to ipad,request data from ipad,send data to special client.
  ///[event]
  final String event;

  FormData({
    required this.from,
    required this.data,
    this.to = "",
    required this.event,
  });

  factory FormData.fromBytes(Uint8List value) {
    final data = utf8.decode(value);
    final mJson = json.decode(data);

    return FormData(
      from: mJson['from'] ?? '',
      data: mJson['data'] ?? '',
      to: mJson['to'] ?? '',
      event: mJson['event'] ?? '',
    );
  }

  Uint8List get toJson {
    return utf8.encode(
      json.encode({
        'from': from,
        'data': data,
        'to': to,
        'event': event,
      }),
    );
  }
}
