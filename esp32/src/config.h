#include <freertos/FreeRTOS.h>
#include <driver/i2s.h>

// WiFi credentials
#define WIFI_SSID "AndroidAP"
#define WIFI_PSWD "jocx4353"

// Devices ID
#define ID_ESP1      0
#define ID_ESP2      1
#define ID_APP       2
#define ID_BROADCAST 3
#define ID_MAX       4

// this ESP_ID
#define ID_MY_ESP     0
#define ID_OTHER_ESP  (1 - ID_MY_ESP)
#define ESPName (ID_MY_ESP == 0 ? "ESP0" : "ESP1")

int target_to_pin(const uint8_t target);

// RGB led handlers and settings
#define PIN_RED    4
#define PIN_GREEN  0
#define PIN_BLUE   2

void setup_led(void);
void turn_led_on(int device_id);
void update_device_colors(int device_id, int new_r, int new_b, int new_g);
void turn_led_off(void);

// led color devices
#define COLOR_ID_ESP1      ID_ESP1
#define COLOR_ID_ESP2      ID_ESP2
#define COLOR_ID_APP       ID_APP
#define COLOR_ID_WIFI      3
#define COLOR_ID_CONNECTED 4
#define COLOR_ID_BLUETOOTH 5

#define COLOR_ID_MAX       6 // keep this color id updated if adding new configurations

// sample rate for the system
#define SAMPLE_RATE 16000

// are you using an I2S microphone - comment this if you want to use an analog mic and ADC input
#define USE_I2S_MIC_INPUT 1

// I2S Microphone Settings

// Which channel is the I2S microphone on? I2S_CHANNEL_FMT_ONLY_LEFT or I2S_CHANNEL_FMT_ONLY_RIGHT
// Generally they will default to LEFT - but you may need to attach the L/R pin to GND
#define I2S_MIC_CHANNEL I2S_CHANNEL_FMT_ONLY_LEFT
// #define I2S_MIC_CHANNEL I2S_CHANNEL_FMT_ONLY_RIGHT
#define I2S_MIC_SERIAL_CLOCK GPIO_NUM_32
#define I2S_MIC_LEFT_RIGHT_CLOCK GPIO_NUM_25
#define I2S_MIC_SERIAL_DATA GPIO_NUM_33

// Analog Microphone Settings - ADC1_CHANNEL_7 is GPIO35
#define ADC_MIC_CHANNEL ADC1_CHANNEL_7

// speaker settings
#define USE_I2S_SPEAKER_OUTPUT
#define I2S_SPEAKER_SERIAL_CLOCK GPIO_NUM_27
#define I2S_SPEAKER_LEFT_RIGHT_CLOCK GPIO_NUM_14
#define I2S_SPEAKER_SERIAL_DATA GPIO_NUM_26
// Shutdown line if you have this wired up or -1 if you don't
#define I2S_SPEAKER_SD_PIN -1 //GPIO_NUM_22

// transmit buttons
#define GPIO_TRANSMIT_BUTTON_BROADCAST 5
#define GPIO_TRANSMIT_BUTTON_APP       17
#define GPIO_TRANSMIT_BUTTON_ESP       16
#define USE_BUTTONS true

// Which LED pin do you want to use? TinyPico LED or the builtin LED of a generic ESP32 board?
// Comment out this line to use the builtin LED of a generic ESP32 board
#define USE_LED_GENERIC

// Which transport do you want to use? ESP_NOW or UDP?
// comment out this line to use UDP
// #define USE_ESP_NOW

// On which wifi channel (1-11) should ESP-Now transmit? The default ESP-Now channel on ESP32 is channel 1
#define ESP_NOW_WIFI_CHANNEL 1


// Define exposed ports
#define UDP_PORT 8888 // the global walkie-talkie port.
// these are not used right now
#define UDP_PORT_ESP_OTHER (UDP_PORT + ESP_ID_OTHER) // other esp port.
#define UDP_PORT_APP UDP_PORT // app port.
#define MULTICAST_IP "239.255.255.250"

// bluethooth BLE services
#define ESP32_BLE_SERVICE              "5daf4da4-860f-11ec-a8a3-0242ac120002"
#define CREDENTIALS_CHARACTERISTIC     "802267c2-860f-11ec-a8a3-0242ac120002"

// In case all transport packets need a header (to avoid interference with other applications or walkie talkie sets), 
// specify TRANSPORT_HEADER_SIZE (the length in bytes of the header) in the next line, and define the transport header in config.cpp
#define TRANSPORT_HEADER_SIZE 1
extern uint8_t transport_header[TRANSPORT_HEADER_SIZE];


// i2s config for using the internal ADC
extern i2s_config_t i2s_adc_config;
// i2s config for reading from of I2S
extern i2s_config_t i2s_mic_Config;
// i2s microphone pins
extern i2s_pin_config_t i2s_mic_pins;
// i2s speaker pins
extern i2s_pin_config_t i2s_speaker_pins;
