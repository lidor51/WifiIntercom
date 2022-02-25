#include <Arduino.h>
#include <driver/i2s.h>
#include <WiFi.h>
// #include <BluetoothSerial.h>

#include "Application.h"
#include "BLE_ESPServer.h"
#include "../lib/audio_input/I2SMEMSSampler.h"
#include "../lib/audio_output/I2SOutput.h"
#include "../lib/transport/UdpTransport.h"
#include "../lib/audio_output/OutputBuffer.h"
#include "config.h"

static void application_task(void *param)
{
  // delegate onto the application
  Application *application = reinterpret_cast<Application *>(param);
  application->loop();
}

Application::Application()
{
  m_output_buffer = new OutputBuffer(300 * 16);
  m_input = new I2SMEMSSampler(I2S_NUM_0, i2s_mic_pins, i2s_mic_Config,128);
  m_output = new I2SOutput(I2S_NUM_0, i2s_speaker_pins);
  m_transport = new UdpTransport(m_output_buffer);
  m_ble_server = nullptr; // this will get set only if needed

  m_transport->set_header(TRANSPORT_HEADER_SIZE,transport_header);

  if (I2S_SPEAKER_SD_PIN != -1)
  {
    pinMode(I2S_SPEAKER_SD_PIN, OUTPUT);
  }

  m_wifi_ssid = WIFI_SSID;
  m_wifi_pswd = WIFI_PSWD;
}

void Application::start_ble_server() {
  if (this->m_ble_server == nullptr) {
    this->m_ble_server = new BLE_ESPServer(this);
    this->m_ble_server->begin();
  } else {
    this->m_ble_server->start();
  }
}

void Application::get_wifi_credentials_from_bluetooth() {
  turn_led_on(COLOR_ID_BLUETOOTH);
  if (!this->m_ble_server)
    this->start_ble_server();
  while(!(this->m_ble_server->stop_waiting())) {
    turn_led_off();
    delay(250);
    turn_led_on(COLOR_ID_BLUETOOTH);
    delay(250);
  }
  Serial.printf("new WiFi credentials: ssid: %s, password: %s\n", this->m_wifi_ssid.c_str(), this->m_wifi_pswd.c_str());
  this->m_ble_server->stop();
}

#define MAX_RETRY 2
void Application::connect_to_wifi() {
  int bluetooth_tries = 0;
start:
  bluetooth_tries++;
  int num_retries = 0;
  while(num_retries < MAX_RETRY) {
    WiFi.disconnect();
    Serial.printf("connecting to '%s' with password '%s'\n", m_wifi_ssid.c_str(), m_wifi_pswd.c_str());
    WiFi.mode(WIFI_STA);
    WiFi.begin(m_wifi_ssid.c_str(), m_wifi_pswd.c_str());
    int i = 0;
    while (WiFi.status() != WL_CONNECTED) {
      i++;
      Serial.print(".");
      if (i == 15) {
        num_retries++;
        Serial.print("\n");
        break;
      }
      delay(250);
      turn_led_on(COLOR_ID_WIFI);
      delay(250);
      turn_led_off();
    }
    if (WiFi.status() == WL_CONNECTED)
      break;
  }

  if (num_retries == MAX_RETRY) {
    if (bluetooth_tries == 2) {
      // The BLE library is a bit weird and does not allow to start the BLE server after deinit was called
      // so just restart the ESP. this is not the optimal design choice, but it works...
      ESP.restart();
    }
    Serial.printf("Failed connecting to WiFi, trying over bluetooth\n");
    get_wifi_credentials_from_bluetooth(); // this is waiting until got a message from the app
    goto start;
  } else {
    turn_led_on(COLOR_ID_CONNECTED);
    delay(1000);
    turn_led_off();
    WiFi.setSleep(WIFI_PS_NONE);
    Serial.printf("My IP Address is: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("My MAC Address is: %s\n", WiFi.macAddress().c_str());
  }
}

void Application::begin()
{
  Serial.println("Begin");
  // setup the RGB led
  setup_led();
  // setup Blutooth
  // bring up WiFi
  connect_to_wifi();
  // do any setup of the transport
  m_transport->begin();
  // setup the transmit buttons
  pinMode(GPIO_TRANSMIT_BUTTON_BROADCAST, INPUT_PULLUP);
  pinMode(GPIO_TRANSMIT_BUTTON_ESP, INPUT_PULLUP);
  pinMode(GPIO_TRANSMIT_BUTTON_APP, INPUT_PULLUP);
  // start off with i2S output running
  m_output->start(SAMPLE_RATE);
  // start the main task for the application
  TaskHandle_t task_handle;
  xTaskCreate(application_task, "application_task", 8192, this, 1, &task_handle);
}

bool Application::keep_playing()
{
  unsigned long now = millis();
  return (now - m_last_sender_packet_time) < 200;
}

bool Application::is_for_me(const uint8_t header) {
    uint8_t target = header & 0x3;
    uint8_t sender = (header & 0xc) >> 2;
    unsigned long now = millis();
    bool isSound = (header & 0x80) == 0;

    if ((target != ID_MY_ESP) && (target != ID_BROADCAST)) {
        Serial.printf("I'm not the target\n");
        return false;
    }

    // check if the sender is the one who speaks now
    if (isSound && this->m_last_sender != sender) {
      if (now - this->m_last_sender_packet_time < 1000) {
        Serial.printf("still listenning to %d, diff = %lu, target = %d\n", this->m_last_sender, now - this->m_last_sender_packet_time, sender);
        return false;
      }
    }

    if (isSound) {
      // update the sender state if it is a sound packet
      m_last_sender_packet_time = now;
      m_last_sender = sender;
    }

    return true;
}

// application task - coordinates everything
void Application::loop()
{
  Serial.println("Started loop");
  int16_t *samples = reinterpret_cast<int16_t *>(malloc(sizeof(int16_t) * 128));
  // continue forever
  while (true)
  {
      // Serial.printf("buttons: BROADCAST = %d, APP = %d, ESP2 = %d\n",
      //              digitalRead(GPIO_TRANSMIT_BUTTON_BROADCAST), digitalRead(GPIO_TRANSMIT_BUTTON_APP), digitalRead(GPIO_TRANSMIT_BUTTON_ESP));
    // do we need to start transmitting?
    if (USE_BUTTONS && (!digitalRead(GPIO_TRANSMIT_BUTTON_BROADCAST) || !digitalRead(GPIO_TRANSMIT_BUTTON_APP) || !digitalRead(GPIO_TRANSMIT_BUTTON_ESP))) {
      int target = ID_APP;
      if (!digitalRead(GPIO_TRANSMIT_BUTTON_ESP)) {
        target = ID_OTHER_ESP;
      }
      if (!digitalRead(GPIO_TRANSMIT_BUTTON_BROADCAST)) {
        target = ID_BROADCAST;
      }
      Serial.printf("Started transmitting to %d\n", target);
      turn_led_on(ID_MY_ESP);
      // stop the output as we're switching into transmit mode
      m_output->stop();
      // start the input to get samples from the microphone
      m_input->start();
      // transmit for at least 200 mili-seconds or while the button is pushed
      unsigned long start_time = millis();
      while (millis() - start_time < 200 || !digitalRead(target_to_pin(target))) {
        // read samples from the microphone
        int samples_read = m_input->read(samples, 128);
        // and send them over the transport
        for (int i = 0; i < samples_read; i++)
        {
          m_transport->add_sample(samples[i], target);
        }
      }
      m_transport->flush(target);
      // finished transmitting stop the input and start the output
      Serial.println("Finished transmitting");
      turn_led_off();
      m_input->stop();
      m_output->start(SAMPLE_RATE);
    }
    // while the transmit button is not pushed and 200 mili-seconds has not elapsed
    // Serial.print("Started Receiving ");
    digitalWrite(I2S_SPEAKER_SD_PIN, HIGH);
    while (keep_playing() && ((digitalRead(GPIO_TRANSMIT_BUTTON_BROADCAST) || 
                              digitalRead(GPIO_TRANSMIT_BUTTON_APP) || 
                              digitalRead(GPIO_TRANSMIT_BUTTON_ESP)))) {
      // read from the output buffer (which should be getting filled by the transport)
      m_output_buffer->remove_samples(samples, 128);
      // and send the samples to the speaker
      m_output->write(samples, 128);
    }
    digitalWrite(I2S_SPEAKER_SD_PIN, LOW);
    // Serial.println("Finished Receiving");
    turn_led_off();
  }
}
