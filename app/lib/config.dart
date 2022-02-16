import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();

  return directory.path;
}

Future<File> _localFile(int id) async {
  final path = await _localPath;
  return File('$path/config$id.config');
}

Future<bool> isConfigFileExist(int id) async {
  final path = await _localPath;
  var configFilePath ='$path/config$id.config';
  return File(configFilePath).exists();
}


Future<List<Color>> readConfig(int id) async {
  print('READ $id');
  final file = await _localFile(id);
  try {

    // Read the file
    final contents = file.readAsStringSync();
    var colors_values = json.decode(contents);
    final List<Color> colors = [Color(colors_values[0]), Color(colors_values[1]), Color(colors_values[2])];
    print(colors);

    return colors;
  } catch (e) {
    // If encountering an error, return 0
    print(e.toString());
    await file.delete();
    return [Colors.red, Colors.green, Colors.blue];
  }
}

Future<List<Color>> writeConfig(int id, Color color1, Color color2, Color color3) async {
  print('WRITE $id');
  final file = await _localFile(id);
  final List<int> colors = [color1.value, color2.value, color3.value];
  print(colors);
  // Write the file
  file.writeAsStringSync('$colors');
  return [color1, color2, color3];
}

List<Color> initConfigColors(int id) {
  print("Init Config $id");
  List<Color> colors = [Colors.red, Colors.green, Colors.blue];
  isConfigFileExist(id).then((res) {
    if (!res) {
      return writeConfig(id, Colors.red, Colors.green, Colors.blue);
    }
    else {
      readConfig(id).then((config) {
        print(config);
        return config;
      });
      return colors;
    }
  });
  return colors; //shouldn't get here.
}

List<List<Color>> initAllConfigs() {
  return [initConfigColors(ID_ESP1), initConfigColors(ID_ESP2), initConfigColors(ID_BROADCAST)];
}