#pragma once

class Application;
class BLEServer;
class BLEService;
class BLEAdvertising;

class BLE_ESPServer
{
private:
  BLEServer *m_ble_server;
  BLEService *m_ble_service;
  BLEAdvertising *m_ble_advertising;
  bool service_on;

public:
  Application *application;
  explicit BLE_ESPServer(Application *);
  bool updated_credentials;
  void begin();
  void stop();
  void reset_status();
  void start();
  bool stop_waiting();
};