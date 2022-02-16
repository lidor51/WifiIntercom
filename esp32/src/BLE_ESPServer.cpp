#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <Arduino.h>

#include "config.h"
#include "BLE_ESPServer.h"
#include "Application.h"

class CredentialsReceivedCallbacks: public BLECharacteristicCallbacks {
    BLE_ESPServer *ble;

    void onWrite(BLECharacteristic *pCharWriteState) {
        uint8_t *inputValues = pCharWriteState->getData();
        ble->application->m_wifi_ssid = "";
        ble->application->m_wifi_pswd = "";

        while(true){
          char letter = *(inputValues++);
          if (letter == ' ')
            break;
          ble->application->m_wifi_ssid += letter;
        }

        while(true){
          char letter = *(inputValues++);
          if (letter == ' ')
            break;
          ble->application->m_wifi_pswd += letter;
        }

        Serial.printf("got ssid: %s, got pswd: %s\n",
                      ble->application->m_wifi_ssid.c_str(),
                      ble->application->m_wifi_pswd.c_str());
        ble->updated_credentials = true;
    }

public:
    explicit CredentialsReceivedCallbacks(BLE_ESPServer *ble) : BLECharacteristicCallbacks() {
      this->ble = ble;
    } 
};

BLE_ESPServer::BLE_ESPServer(Application *app) {
  this->application = app;
  this->m_ble_service = nullptr;
  this->m_ble_advertising = nullptr;
  this->m_ble_server = nullptr;
  this->updated_credentials = false;
  this->service_on = false;
}

void BLE_ESPServer::begin() {
  Serial.printf("ble_begin\n");
  if (this->m_ble_service) {
    // we did the begin already, just start the service and return
    if (!this->service_on) {
      this->m_ble_service->start();
      this->service_on = true;
    }
    return;
  }

  BLEDevice::init(ESPName);
  Serial.printf("init finished\n");

  this->m_ble_server = BLEDevice::createServer();
  Serial.printf("Server created\n");

  this->m_ble_service = this->m_ble_server->createService(ESP32_BLE_SERVICE);
  Serial.printf("serviceCreate finished\n");

  BLECharacteristic *credentials_char = m_ble_service->createCharacteristic(CREDENTIALS_CHARACTERISTIC,
                                                                    BLECharacteristic::PROPERTY_WRITE);
  credentials_char->setCallbacks(new CredentialsReceivedCallbacks(this));

  // now we can start the ble server
  m_ble_service->start();
  Serial.printf("ble_service started\n");

  this->m_ble_advertising = BLEDevice::getAdvertising();
  this->m_ble_advertising->addServiceUUID(ESP32_BLE_SERVICE);
  this->m_ble_advertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.printf("advertizing\n");

  this->service_on = true;
}

void BLE_ESPServer::reset_status() {
  this->updated_credentials = false;
}

bool BLE_ESPServer::stop_waiting() {
  return updated_credentials;
}

void BLE_ESPServer::stop() {
  this->reset_status();
  if (this->service_on) {
    BLEDevice::stopAdvertising();
    this->m_ble_service->stop();
    this->m_ble_server->removeService(this->m_ble_service);
    BLEDevice::deinit(true);
  }
  this->m_ble_service = nullptr;
  this->service_on = false;
}

void BLE_ESPServer::start() {
  Serial.printf("ble_Start\n");
  if (!this->service_on) {
    this->m_ble_service->start();
    this->service_on = true;
  }
}
