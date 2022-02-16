#pragma once

class I2SOutput;
class I2SSampler;
class Transport;
class OutputBuffer;
class IndicatorLed;
class BLE_ESPServer;

class Application
{
private:
  I2SSampler *m_input;
  Transport *m_transport;
  OutputBuffer *m_output_buffer;
  uint8_t m_last_sender;
  BLE_ESPServer *m_ble_server;
  unsigned long m_last_sender_packet_time;
  void connect_to_wifi();
  void get_wifi_credentials_from_bluetooth();
  void start_ble_server();

public:
  I2SOutput *m_output;
  Application();
  void begin();
  void loop();
  bool keep_playing();
  bool is_for_me(const uint8_t header);
  String m_wifi_ssid;
  String m_wifi_pswd;
};