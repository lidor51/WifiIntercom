
// Devices ID
//const int ID_RECORDING   = -2;
const int ID_FREE       = -1;
const int ID_ESP1       = 0;
const int ID_ESP2       = 1;
const int ID_APP        = 2;
const int ID_BROADCAST  = 3;

// udp configurations
const int UDP_PORT = 8888;
const String IP = '255.255.255.255'; //multicast '239.255.255.250'

const String ESP32_BLE_SERVICE       = '5daf4da4-860f-11ec-a8a3-0242ac120002';
const String SSID_CHARACTERISTIC     = '802267c2-860f-11ec-a8a3-0242ac120002';
const String PASSWORD_CHARACTERISTIC = '8ae63986-860f-11ec-a8a3-0242ac120002';