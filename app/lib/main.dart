import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'constants.dart';
import 'headers.dart';
import 'block_picker.dart';
import 'package:flutter_blue/flutter_blue.dart';

bool recording = false;

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiFi Intercom',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blueGrey,
      ),
      home: const HomePage(title: 'WiFi Intercom'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

const int tSampleRate = 16000;
typedef _Fn = void Function();


class _HomePageState extends State<HomePage> {
  static const int _minDt = 1; // sec
  int _listenTo = ID_FREE;
  var _lastTimestamp = DateTime.now().millisecondsSinceEpoch;
  int _target = -1;
  void _broadcast() {
    _cast(ID_BROADCAST);
  }

  void _esp1() {
    _esp(ID_ESP1);
  }

  void _esp2() {
    _esp(ID_ESP2);
  }

  void _esp(int target) {
    _cast(target);
  }

  void _cast(int target) {
    setState(() {
      _target = target;
    });
    // can't record when someone is talking, or when not enough time has passed.
    if (_listenTo > ID_FREE || (DateTime.now().millisecondsSinceEpoch - _lastTimestamp) < (_minDt * 1000)) {
      const snackBar = SnackBar(content: Text("You can't record while someone else is speaking ..."));
      print(_listenTo);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
    else {
      _listenTo = ID_FREE; //TODO: maybe update somewhere else, so we can update constantly the speaker text.
      recording = true;
      //Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (context) =>
          RecordingPage(title: 'WiFi Intercom', target: target)));
    }
  }

  bool _shouldListen(int sender, int target) {
    var ts = DateTime.now().millisecondsSinceEpoch;
    //print('$sender $target');
    if (sender != ID_APP && (target == ID_APP || target == ID_BROADCAST) && (sender == _listenTo || (ts - _lastTimestamp) >= (_minDt * 1000))) {
      bool changeState = sender != _listenTo;
      _listenTo = sender;
      _lastTimestamp = ts;
      if (changeState) { //TODO: check if setState in listen affect latency (although it's should be only in first packet from new device).
        setState(() {});
      }
      //print('listening to ' + sender.toString());
      return true;
    }
    return false;
  }

  Future<void> _updateLineIsFree() async {
      var ts = DateTime.now().millisecondsSinceEpoch;
      if (!recording && _listenTo != ID_FREE && (ts - _lastTimestamp) >= (_minDt * 1000)) {
        setState(() {
        _listenTo = ID_FREE;
        print('Line is Free');
        });
      }
  }

  void _popup_menu(item) {
    if (item == 1) { // colors
      _listenTo = ID_FREE; //TODO: decide if keep listening when configuring. maybe use recording = true.
      //Navigator.of(context).pop();
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ColorConfigPage()));
      //Navigator.push(context, MaterialPageRoute(builder: (context) => ConfigPage()));
    } else { // wifi
      print('WiFi selected (item = $item)');
      Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => WiFiConfigPage()));
    }
  }


  FlutterSoundPlayer? _mPlayer = FlutterSoundPlayer();
  bool _isInited = false;

  Future<void> init() async {
    await _mPlayer!.openAudioSession(
      device: AudioDevice.blueToothA2DP,
      audioFlags: allowHeadset | allowEarPiece | allowBlueToothA2DP,
      category: SessionCategory.playAndRecord,
    );
  }

  @override
  void initState() {
    super.initState();
    // Be careful : openAudioSession return a Future.
    // Do not access your FlutterSoundPlayer or FlutterSoundRecorder before the completion of the Future
    init().then((value) {
      setState(() {
        _isInited = true;
      });
      listen();
      new Timer.periodic(Duration(milliseconds: 1), (Timer t) => _updateLineIsFree());
    });
  }

  Future<void> release() async {
    await stopPlayer();
    await _mPlayer!.closeAudioSession();
    _mPlayer = null;
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }


  Future<void>? stopPlayer() {
    if (_mPlayer != null) {
      return _mPlayer!.stopPlayer();
    }
    return null;
  }

  Future<void> listen() async {
    //assert(_isInited);
    print('Listening');

    await _mPlayer!.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: tSampleRate,
    );

    await RawDatagramSocket.bind(InternetAddress.anyIPv4, UDP_PORT).then((RawDatagramSocket udpSocket) {
      udpSocket.broadcastEnabled = true;
      udpSocket.listen((e) {
          Datagram? dg = udpSocket.receive();
          if (dg != null && _listenTo >= ID_FREE && !recording) {
            int sender = getSenderFromHeader(dg.data[0]);
            int target = getTargetFromHeader(dg.data[0]);
            if (_shouldListen(sender, target)) {
              var localBuff = dataTo16Bit(dg.data);
              _mPlayer?.foodSink?.add(FoodData(localBuff)); //dg.data.sublist(1, dg.data.length - 1)); //TODO: use buffer.data! if client is PC; use localBuff if client is ESP.
            }
          } else {
            print('recording is $recording');
          }
      });
    });
  }

  Uint8List dataTo16Bit(Uint8List data){
    var num_samples = (data.lengthInBytes - 1);
    var local_buff = Uint8List(num_samples * 2);
    var sample_16bit;

    for (var i = 0; i < num_samples; i++) {
      sample_16bit = (data[i] ^ 0x80) >> 5;
      local_buff[2*i] = sample_16bit & 0xff;
      local_buff[2*i + 1] = (sample_16bit & 0xff00) >> 8;
    }

    return local_buff;
  }

  Future<void> stop() async {
    if (_mPlayer != null) {
      await _mPlayer!.stopPlayer();
    }
  }

  _Fn? getRecFn() {
    if (!_isInited) {
      return null;
    }
    return recording ? stop : listen;
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _cast method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the HomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        //automaticallyImplyLeading: false,
        actions: <Widget>[
          PopupMenuButton<int>(
            enabled: true,
            onSelected: (item) => _popup_menu(item),
            itemBuilder: (context) => [
              PopupMenuItem<int>(
                enabled: true,
                value: 1,
                child: Text('Colors'),
              ),
              PopupMenuItem<int>(
                enabled: true,
                value: 2,
                child: Text('WiFi'),
              ),
            ])
          ],
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Speaker:',
            ),
            Text(
              _listenTo == ID_FREE ? 'Line is Free' : _listenTo == ID_ESP1 ? 'Orange Intercom' : 'White Intercom',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FloatingActionButton(
              onPressed: _esp1,
              tooltip: 'Orange Intercom',
              backgroundColor: Colors.orangeAccent,
              child: Icon(Icons.wifi_calling),
              heroTag: 'esp1',
            ),
            FloatingActionButton(
              onPressed: _broadcast,
              tooltip: 'Broadcast',
              backgroundColor: Colors.blue,
              child: Icon(Icons.speaker_phone),
              heroTag: 'broadcast',
            ),
            FloatingActionButton(
              onPressed: _esp2,
              tooltip: 'White Intercom',
              backgroundColor: Colors.grey,
              child: Icon(Icons.wifi_calling),
              heroTag: 'esp2',
            ),
          ],
        ),
      ),

    );
  }
}

class RecordingPage extends StatefulWidget {
  const RecordingPage({Key? key, required this.title, required this.target}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final int target;

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}


class _RecordingPageState extends State<RecordingPage> {
  void _stop() {
    recording = false;
    Navigator.of(context).pop(context);
    //Navigator.of(context).push(MaterialPageRoute(builder: (context) => HomePage(title: 'WiFi Intercom')));
  }

  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  bool _mRecorderIsInited = false;
  String? _mPath;
  StreamSubscription? _mRecordingDataSubscription;

  Future<void> _openRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _mRecorder!.openAudioSession();
    setState(() {
      _mRecorderIsInited = true;
    });
  }

  @override
  void initState() {
    super.initState();
    // Be careful : openAudioSession return a Future.
    // Do not access your FlutterSoundPlayer or FlutterSoundRecorder before the completion of the Future
    _openRecorder();
  }

  Future<void> release() async {
    await stopRecorder();
    await _mRecorder!.closeAudioSession();
    _mRecorder = null;
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  Future<IOSink> createFile() async {
    var tempDir = await getTemporaryDirectory();
    _mPath = '${tempDir.path}/flutter_sound_example.pcm';
    var outputFile = File(_mPath!);
    if (outputFile.existsSync()) {
      await outputFile.delete();
    }
    return outputFile.openWrite();
  }

  Future<void> record() async {
    //assert(_mRecorderIsInited);
    //var sink = await createFile();
    var recordingDataController = StreamController<Food>();
    _mRecordingDataSubscription =
        recordingDataController.stream.listen((buffer) {
          if (buffer is FoodData) {
            var localBuff = Uint8List((buffer.data!.lengthInBytes ~/ 2) + 1);

            // buffer.data! is 16bit (in big endian), and we want to convert it to 8bit
            // we need to bit flip the MSB bit to adapt to the ESP code
            for (var i = 0; i < localBuff.lengthInBytes - 1; i++) {
              localBuff[i + 1] = buffer.data![i*2 + 1] ^ 0x80;
            }

            var DESTINATION_ADDRESS = InternetAddress(IP);
            localBuff[0] = createHeader(false, widget.target);
            RawDatagramSocket.bind(InternetAddress.anyIPv4, UDP_PORT).then((
                RawDatagramSocket udpSocket) {
              udpSocket.broadcastEnabled = true;
              udpSocket.send(localBuff, DESTINATION_ADDRESS, UDP_PORT); //TODO: use buffer.data! if client is PC; use localBuff if client is ESP.
              udpSocket.close();
            });
          }
        });
    await _mRecorder!.startRecorder(
      toStream: recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: tSampleRate,
    );
    setState(() {});
  }

  Future<void> stopRecorder() async {
    await _mRecorder!.stopRecorder();
    if (_mRecordingDataSubscription != null) {
      await _mRecordingDataSubscription!.cancel();
      _mRecordingDataSubscription = null;
    }
  }

  _Fn? getRecorderFn() {
    if (!_mRecorderIsInited) {
      return null;
    }
    return _mRecorder!.isStopped
        ? record
        : () {
      stopRecorder().then((value) => setState(() {}));
    };
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _cast method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    //compute(__send, widget.port);
    record();
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the HomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        //Text(widget.title),
      ),
      body: Center(
        child: FlatButton(
          color: Colors.redAccent,
          textColor: Colors.white,
          onPressed: _stop,
          child: Text('STOP'),
        ),
      ),
    );
  }
}

class ColorConfigPage extends StatefulWidget {
  const ColorConfigPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ColorConfigPageState();
}

class _ColorConfigPageState extends State<ColorConfigPage> {
  bool lightTheme = true;
  Color currentColor = Colors.blueGrey;
  List<Color> currentColors = [Colors.yellow, Colors.green];
  List<Color> colorHistory = [];

  void doNothing(Color color) => setState(() => currentColor = color);
  void changeColor(Color color) => setState(() => currentColor = color);
  void changeColors(List<Color> colors) => setState(() => currentColors = colors);

  @override
  Widget build(BuildContext context) {
    final foregroundColor = useWhiteForeground(currentColor) ? Colors.white : Colors.black;
    return AnimatedTheme(
      data: lightTheme ? ThemeData.light() : ThemeData.dark(),
      child: Builder(builder: (context) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Config Colors'),
              backgroundColor: currentColor,
              foregroundColor: foregroundColor,
              bottom: TabBar(
                labelColor: foregroundColor,
                tabs: const <Widget>[
                  Tab(text: 'Orange ESP'),
                  Tab(text: 'White ESP'),
                  Tab(text: 'All'),
                ],
              ),
            ),
            body: TabBarView(
              children: <Widget>[
                BlockColorPickerFlutter(
                  deviceId: ID_ESP1,
                  thisESPColor: Color.fromRGBO(255, 0, 0, 1),
                  otherESPColor: Color.fromRGBO(0, 255, 0, 1),
                  appColor: Color.fromRGBO(0, 0, 255, 1),
                  onColorChanged: doNothing,
                  pickerColors: currentColors,
                  onColorsChanged: changeColors,
                  colorHistory: colorHistory,
                ),
                BlockColorPickerFlutter(
                  deviceId: ID_ESP2,
                  thisESPColor: Color.fromRGBO(0, 255, 0, 1),
                  otherESPColor: Color.fromRGBO(255, 0, 0, 1),
                  appColor: Color.fromRGBO(0, 0, 255, 1),
                  onColorChanged: doNothing,
                  pickerColors: currentColors,
                  onColorsChanged: changeColors,
                  colorHistory: colorHistory,
                ),
                BlockColorPickerFlutter(
                  deviceId: ID_BROADCAST,
                  thisESPColor: Color.fromRGBO(255, 0, 0, 1),
                  otherESPColor: Color.fromRGBO(0, 255, 0, 1),
                  appColor: Color.fromRGBO(0, 0, 255, 1),
                  onColorChanged: doNothing,
                  pickerColors: currentColors,
                  onColorsChanged: changeColors,
                  colorHistory: colorHistory,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class WiFiConfigPage extends StatefulWidget {
  const WiFiConfigPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _WiFiConfigPageState();
}

class _WiFiConfigPageState extends State<WiFiConfigPage> {
  bool lightTheme = true;
  Color currentColor = Colors.blueGrey;
  String _ssid = 'dummy_ssid';
  String _password = 'dummy_password';
  String _helpString = '';
  int _deviceId = 0;
  var flutterBlue = FlutterBlue.instance;
  final Set<BluetoothDevice> _devicesSet = <BluetoothDevice>{};

  void sendWiFiCredentials_1() { _deviceId = 0; sendWiFiCredentials(); }
  void sendWiFiCredentials_2() { _deviceId = 1; sendWiFiCredentials(); }

  @override
  void initState() {
    super.initState();
    flutterBlue.connectedDevices.asStream().listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        print('added ${device.name}, id = ${device.id} _devicesSet.length = ${_devicesSet.length}');
        _devicesSet.add(device);
      }
    });

    // print the devices that are discovered
    flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        print('added ${result.device.name}, id = ${result.device.id} _devicesSet.length = ${_devicesSet.length}');
        _devicesSet.add(result.device);
      }
    });
    flutterBlue.startScan(timeout: Duration(seconds: 4));
  }

  @override
  void dispose() {
    _devicesSet.clear();
    super.dispose();
  }

  void sendWiFiCredentials() async { // todo: verify this
    setState(() {_helpString = 'Sending WiFi credentials to ESP$_deviceId';});
    // wait for the scan to finish
    await flutterBlue.stopScan();

    _devicesSet.forEach((device) async {
      if (device.name == getESPName(_deviceId)) {
        // connect to the device and send the messages
        try {
          await device.connect();
          var services = await device.discoverServices();
          services.forEach((service) {
            print('\tdevice ${device.id} ${device.name} - service ${service.uuid}');
            // use this link as guide https://randomnerdtutorials.com/esp32-ble-server-client/
            if (service.uuid == Guid(ESP32_BLE_SERVICE)) {
              var sent = 0;
              service.characteristics.forEach((char) async {
                print('\t\tservice ${service.uuid} - char ${char.uuid} write = ${char.properties.write} read = ${char.properties.read}');
                if (char.uuid == Guid(SSID_CHARACTERISTIC) && char.properties.write) {
                  var text = _ssid + ' ' + _password + ' ';
                  await char.write(utf8.encode(text));
                  sent++;
                }
                if (sent == 2) {
                  setState(() {_helpString = 'Sent WiFi credentials to ESP$_deviceId';});
                  await device.disconnect();
                  return;
                }
              });
            }
          });
          await device.disconnect();
        } catch (e) {
          print('failed connecting to ${device.name}');
          await device.disconnect(); // disconnect just in case
        }
      }
    });
    setState(() {_helpString = 'Failed sending WiFi credentials to ESP$_deviceId';});
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = useWhiteForeground(currentColor) ? Colors.white : Colors.black;
    return AnimatedTheme(
      data: lightTheme ? ThemeData.light() : ThemeData.dark(),
      child: Builder(builder: (context) {
        return DefaultTabController(
          length: 1,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Config WiFi'),
              backgroundColor: currentColor,
              foregroundColor: foregroundColor,
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: TextField(
                    onChanged: (text) {_ssid = text;},
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter SSID',
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: TextField(
                    obscureText: true,
                    onChanged: (text) {_password = text;},
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter Password',
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    FloatingActionButton(
                      onPressed: sendWiFiCredentials_1,
                      tooltip: 'Orange Intercom',
                      backgroundColor: Colors.orangeAccent,
                      child: Icon(Icons.send),
                      heroTag: 'esp1',
                    ),
                    FloatingActionButton(
                      onPressed: sendWiFiCredentials_2,
                      tooltip: 'White Intercom',
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.send),
                      heroTag: 'esp2',
                    ),
                  ],
                ),
                Text(_helpString
                  //todo - change text style
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
