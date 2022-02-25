import 'dart:ffi';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'constants.dart';
import 'headers.dart';

const List<Color> colors = [
  Color.fromRGBO(200, 0, 0, 1), //red
  // Colors.pink,
  Color.fromRGBO(200, 0, 200, 1), //purple
  //Colors.deepPurple,
  //Colors.indigo,
  Color.fromRGBO(0, 0, 200, 1), //blue
  //Colors.lightBlue,
  //Colors.cyan,
  //Colors.teal,
  Color.fromRGBO(0, 200, 0, 1), //green
  //Colors.lightGreen,
  //Colors.lime,
  //Colors.yellow,
  //Colors.amber,
  //Colors.orange,
  //Colors.deepOrange,
  //Colors.brown,
  //Color.fromRGBO(255, 255, 255, 1), //white
  //Colors.blueGrey,
  Colors.black,
];

class BlockColorPickerFlutter extends StatefulWidget {
  BlockColorPickerFlutter({
    Key? key,
    required this.deviceId,
    required this.thisESPColor,
    required this.otherESPColor,
    required this.appColor,
    required this.onColorChanged,
    required this.pickerColors,
    required this.onColorsChanged,
    required this.colorHistory,
  }) : super(key: key);

  final int deviceId;
  Color thisESPColor;
  Color otherESPColor;
  Color appColor;
  final ValueChanged<Color> onColorChanged;
  final List<Color> pickerColors;
  final ValueChanged<List<Color>> onColorsChanged;
  final List<Color> colorHistory;

  @override
  State<BlockColorPickerFlutter> createState() => _BlockColorPickerFlutterState();
}

class _BlockColorPickerFlutterState extends State<BlockColorPickerFlutter> {
  int _portraitCrossAxisCount = 4;
  int _landscapeCrossAxisCount = 5;
  double _borderRadius = 30;
  double _blurRadius = 5;
  double _iconSize = 24;
  bool _doOnce = true;

  void updateThisEspColor(Color color) {
    setState(() {
      widget.thisESPColor = color;
    });
  }

  void updateOtherESPColor(Color color) {
    {
      setState(() {
        widget.otherESPColor = color;
      });
    }
  }

  void updateAPPColor(Color color) {
    {
      setState(() {
        widget.appColor = color;
      });
    }
  }

  void save(int deviceId, Color color, int colorOfDeviceId) {
    int wait = 250; //ms
    var configurationPacket = createRGBPacket(deviceId, color.red, color.green, color.blue, colorOfDeviceId);
    var DESTINATION_ADDRESS = InternetAddress(IP);
    RawDatagramSocket.bind(InternetAddress.anyIPv4, UDP_PORT).then((
        RawDatagramSocket udpSocket) {
      udpSocket.broadcastEnabled = true;
      udpSocket.send(configurationPacket, DESTINATION_ADDRESS, UDP_PORT); //use buffer.data! if client is PC; use localBuff if client is ESP.
      udpSocket.close();
      sleep(Duration(milliseconds: wait));
    });
  }

  void saveAll() { //TODO: also save on smarthpone to be persistent..
    for (int i = 0; i < 2; i++) {
      if (i == widget.deviceId || widget.deviceId == ID_BROADCAST) {
        save(i, widget.thisESPColor, i);
        save(i, widget.otherESPColor, 1 - i); // save other esp color.
        save(i, widget.appColor, ID_APP); // save app color.
      }
    }
    writeConfig(widget.deviceId, widget.thisESPColor, widget.otherESPColor, widget.appColor);
  }

  Future<bool> isConfigFileExist(int id) async {
    final path = await _localPath;
    var configFilePath ='$path/config$id.config';
    return File(configFilePath).exists();
  }

  Future<void> writeConfig(int id, Color color1, Color color2, Color color3) async {
    print('WRITE $id');
    final file = await _localFile(id);
    final List<int> colors = [color1.value, color2.value, color3.value];
    print(colors);
    // Write the file
    file.writeAsStringSync('$colors');
  }

  void initConfigColors(int id) {
    print('Init Config $id');
    isConfigFileExist(id).then((res) async {
      if (!res) {
        writeConfig(id, Color.fromRGBO(200, 0, 0, 1), Color.fromRGBO(0, 200, 0, 1), Color.fromRGBO(0, 0, 200, 1));
        print('!res');
      }
      else {
        await readConfig(id).then((colors) {
          print('else ${colors[1].green}');
          widget.thisESPColor  = colors[0];
          widget.otherESPColor = colors[1];
          widget.appColor      = colors[2];
          setState(() {});
        });
      }
    });
  }

  Widget pickerLayoutBuilder(BuildContext context, List<Color> colors, PickerItem child) {
    Orientation orientation = MediaQuery.of(context).orientation;

    return SizedBox(
      width: 300,
      height: orientation == Orientation.portrait ? 240 : 120,
      child: GridView.count(
        crossAxisCount: orientation == Orientation.portrait ? _portraitCrossAxisCount : _landscapeCrossAxisCount,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        children: [for (Color color in colors) child(color)],
      ),
    );
  }

  Widget pickerItemBuilder(Color color, bool isCurrentColor, void Function() changeColor) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_borderRadius),
        color: color,
        boxShadow: color == Colors.white ? [BoxShadow(color: Colors.grey.withOpacity(0.8), offset: const Offset(1, 2), blurRadius: _blurRadius)] : [BoxShadow(color: color.withOpacity(0.8), offset: const Offset(1, 2), blurRadius: _blurRadius)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: changeColor,
          borderRadius: BorderRadius.circular(_borderRadius),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isCurrentColor ? 1 : 0,
            child: Icon(
              Icons.done,
              size: _iconSize,
              color: useWhiteForeground(color) ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override void initState() {
    super.initState();
    initConfigColors(widget.deviceId);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Select a color'),
                      content: SingleChildScrollView(
                        child: BlockPicker(
                          pickerColor: widget.thisESPColor,
                          onColorChanged: updateThisEspColor,
                          availableColors: widget.colorHistory.isNotEmpty ? widget.colorHistory : colors,
                          layoutBuilder: pickerLayoutBuilder,
                          itemBuilder: pickerItemBuilder,
                        ),
                      ),
                    );
                  },
                );
              },
              child: Text(
                widget.deviceId == ID_BROADCAST ? "Orange ESP" : 'This ESP Color',
                style: TextStyle(color: useWhiteForeground(widget.thisESPColor) ? Colors.white : Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                primary: widget.thisESPColor,
                shadowColor: widget.thisESPColor.withOpacity(1),
                elevation: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Select a color'),
                      content: SingleChildScrollView(
                        child: BlockPicker(
                          pickerColor: widget.otherESPColor,
                          onColorChanged: updateOtherESPColor,
                          availableColors: widget.colorHistory.isNotEmpty ? widget.colorHistory : colors,
                          layoutBuilder: pickerLayoutBuilder,
                          itemBuilder: pickerItemBuilder,
                        ),
                      ),
                    );
                  },
                );
              },
              child: Text(
                widget.deviceId == ID_BROADCAST ? "White ESP" : 'Other ESP Color',
                style: TextStyle(color: useWhiteForeground(widget.otherESPColor) ? Colors.white : Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                primary: widget.otherESPColor,
                shadowColor: widget.otherESPColor.withOpacity(1),
                elevation: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Select a color'),
                      content: SingleChildScrollView(
                        child: BlockPicker(
                          pickerColor: widget.appColor,
                          onColorChanged: updateAPPColor,
                          availableColors: widget.colorHistory.isNotEmpty ? widget.colorHistory : colors,
                          layoutBuilder: pickerLayoutBuilder,
                          itemBuilder: pickerItemBuilder,
                        ),
                      ),
                    );
                  },
                );
              },
              child: Text(
                'App Color',
                style: TextStyle(color: useWhiteForeground(widget.appColor) ? Colors.white : Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                primary: widget.appColor,
                shadowColor: widget.appColor.withOpacity(1),
                elevation: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: saveAll,
              child: Text(
                'Save',
                style: TextStyle(color: useWhiteForeground(Colors.blueGrey) ? Colors.white : Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                primary: Colors.blueGrey,
                shadowColor: Colors.blueGrey.withOpacity(1),
                elevation: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();

  return directory.path;
}

Future<File> _localFile(int id) async {
  final path = await _localPath;
  return File('$path/config-$id.config');
}

Future<List<Color>> readConfig(int id) async {
  print('READ $id');
  final file = await _localFile(id);
  try {

    // Read the file
    final contents = file.readAsStringSync();
    var colors_values = json.decode(contents);
    var thisESPColor = Color(colors_values[0]);
    var otherESPColor = Color(colors_values[1]);
    var appColor = Color(colors_values[2]);
    print('try success ${appColor.blue}');
    return [thisESPColor, otherESPColor, appColor];
  } catch (e) {
    // If encountering an error, return 0
    print('catch');
    try {
      await file.delete();
    } catch (e) {
      // pss
    }
    return [Color.fromRGBO(200, 0, 0, 1), Color.fromRGBO(0, 200, 0, 1), Color.fromRGBO(0, 0, 200, 1)];
  }
}
