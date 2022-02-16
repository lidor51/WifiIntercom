import 'dart:typed_data';

import 'constants.dart';

int createHeader(bool isConfig, int target) {
  var header = 0;
  if (isConfig) {
    header |= 0x80;
  }

  header |= (target % 4);
  header |= (ID_APP << 2);

  return header;
}

int getSenderFromHeader(int header) {
  return (header & 0xc) >> 2;
}

int getTargetFromHeader(int header) {
  return header & 3; //TODO: implement
}

Uint8List createRGBPacket(int target, int r, int g, int b, int deviceID) {
  var packet = Uint8List(5);
  packet[0] = createHeader(true, target);
  packet[1] = (deviceID % 4);
  packet[2] = (r % 256);
  packet[3] = (g % 256);
  packet[4] = (b % 256);

  return packet;
}

String getESPName(int deviceId) {
  // todo: define the names
  switch (deviceId) {
    case 0:
      return 'ESP0';
    case 1:
      return 'ESP1';
    default:
      return 'unknown name';
  }
}