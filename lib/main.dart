import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bridgefy/bridgefy_utils.dart';
import 'package:flutter_bridgefy/mlog.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    bridgefyUtils.initSdk().then((value) => null);
    super.initState();

    scheduleMicrotask(receiverMessage);
  }

  @override
  void didChangeDependencies() async {
    final r = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan
    ].request();

    for (var element in r.values) {
      mLog.message("permission name: ${element.name}:${element.isGranted}");
    }
    super.didChangeDependencies();
  }

  ///
  void startIpadServer() async {
    await bridgefyUtils.initIpadServer();
  }

  ///start client scan
  void startClient() async {
    await bridgefyUtils.initClient();
  }

  ///disconnect
  void disConnected() {
    bridgefyUtils.release();
  }

  ///working only client
  void clientReConnect() {
    bridgefyUtils.reStartService();
  }

  ///receiver and check event
  void receiverMessage() {
    bridgefyUtils.subscriptionMessageAndEvents(
      syncData: (it) {
        ///sync data to ipad event
      },
      requestData: (it) {
        /// request data from ipad event
      },
      responseData: (it) {
        /// ipad send data to client event
        mLog.message('response data receiver: ${it.string}');
      },
      unknown: (it) {
        ///unknown event
      },
    );
  }

  ///receiver raw data without check event
  void receiverMessageNoEvent() {
    bridgefyUtils.receiverMessageEvent?.distinct().listen(
      (event) {
        ///raw message
      },
    );
  }

  ///send data to ipad server
  void syncDataToIpadServer({required String data}) async {
    await bridgefyUtils.sendDataToIpad(data: data);
    mLog.message("sync data to ipad complete");
  }

  void sendDataToClientById({
    required String data,
    required String event,
  }) async {
    ///list current client connected
    final peers = bridgefyUtils.clients;
    final toClientId = peers.firstOrNull;

    await bridgefyUtils.sendDataToSpecial(
      data: data,
      toClientId: toClientId ?? '',
      event: event,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '000',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // startClient();


          // sendDataToClientById(
          //   data: 'hello world send from client',
          //   event: BridgefyUtils.responseDataEvent,
          // );
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
