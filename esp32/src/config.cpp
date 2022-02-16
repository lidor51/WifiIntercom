#include "config.h"
#include <Arduino.h>
#include <WiFi.h>

// We use a one byte header to tell the other devices who is sending the data and to
// whom it is supposed to be delivered.
// The target could be any of the relevent ESP32 ports, meaning  15, 17 or 21.
// so the upper 3 bit are left to identify the sender.
// REMEMBER TO CHANGE THIS FOR EACH ESP32 THAT WE COMPILE.
uint8_t transport_header[TRANSPORT_HEADER_SIZE] = {ID_MY_ESP << 2};

// i2s config for using the internal ADC
i2s_config_t i2s_adc_config = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX | I2S_MODE_ADC_BUILT_IN),
    .sample_rate = SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_MIC_CHANNEL,
    .communication_format = I2S_COMM_FORMAT_I2S_LSB,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 4,
    .dma_buf_len = 64,
    .use_apll = false,
    .tx_desc_auto_clear = false,
    .fixed_mclk = 0};

// i2s config for reading from I2S
i2s_config_t i2s_mic_Config = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT,
    .channel_format = I2S_MIC_CHANNEL,
    .communication_format = I2S_COMM_FORMAT_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 4,
    .dma_buf_len = 64,
    .use_apll = false,
    .tx_desc_auto_clear = false,
    .fixed_mclk = 0};

// i2s microphone pins
i2s_pin_config_t i2s_mic_pins = {
    .bck_io_num = I2S_MIC_SERIAL_CLOCK,
    .ws_io_num = I2S_MIC_LEFT_RIGHT_CLOCK,
    .data_out_num = I2S_PIN_NO_CHANGE,
    .data_in_num = I2S_MIC_SERIAL_DATA};

// i2s speaker pins
i2s_pin_config_t i2s_speaker_pins = {
    .bck_io_num = I2S_SPEAKER_SERIAL_CLOCK,
    .ws_io_num = I2S_SPEAKER_LEFT_RIGHT_CLOCK,
    .data_out_num = I2S_SPEAKER_SERIAL_DATA,
    .data_in_num = I2S_PIN_NO_CHANGE};

int target_to_pin(const uint8_t target) {
    switch(target) {
        case ID_OTHER_ESP:
            return GPIO_TRANSMIT_BUTTON_ESP;
        case ID_APP:
            return GPIO_TRANSMIT_BUTTON_APP;
        case ID_BROADCAST:
            return GPIO_TRANSMIT_BUTTON_BROADCAST;
        default:
            Serial.printf("Error - bad target! %d\n", target);
            return -1;
    }
}

// led functionality
typedef struct {
    int R;
    int G;
    int B;
} rgb_colors_t;

rgb_colors_t device_colors[COLOR_ID_MAX] {
    [COLOR_ID_ESP1]      = {.R = 200, .G = 0, .B = 0},
    [COLOR_ID_ESP2]      = {.R = 0, .G = 200, .B = 0},
    [COLOR_ID_APP]       = {.R = 0, .G = 0, .B = 200},
    [COLOR_ID_WIFI]      = {.R = 200, .G = 0, .B = 0},
    [COLOR_ID_CONNECTED] = {.R = 0, .G = 255, .B = 0},
    [COLOR_ID_BLUETOOTH] = {.R = 0, .G = 0, .B = 255},
};

void setup_led(void) {
  // Configure LED PWM functionalities.
  ledcSetup(0, 5000, 8);
  ledcSetup(1, 5000, 8);
  ledcSetup(2, 5000, 8);

  // Attach RGB pins.
  ledcAttachPin(PIN_RED, 0);
  ledcAttachPin(PIN_GREEN, 1);
  ledcAttachPin(PIN_BLUE, 2);

  device_colors[ID_MY_ESP]    = {.R = 0, .G = 200, .B = 0};
  device_colors[ID_OTHER_ESP] = {.R = 200, .G = 0, .B = 0};
}

static void changeColor(int R, int G, int B){
  // Display color pattern on the module.
  ledcWrite(0, R);
  ledcWrite(1, G);
  ledcWrite(2, B);

  // Serial.printf("Color: rgb(%d, %d, %d)\n", R, G, B);
}

void turn_led_on(int color_id) {
    if (color_id >= COLOR_ID_MAX) {
        Serial.printf("invalid color_id : %d\n", color_id);
        return;
    }

    // Serial.printf("device_id : %d\n", color_id);
    rgb_colors_t rgb = device_colors[color_id];
    changeColor(rgb.R, rgb.G, rgb.B);
}

void update_device_colors(int device_id, int new_r, int new_g, int new_b) {
    Serial.printf("update_device_colors(%d, %d, %d, %d)\n", device_id, new_r, new_g, new_b);
    if (device_id >= ID_MAX) {
        Serial.printf("invalid device_id : %d\n", device_id);
        return;
    }

    device_colors[device_id].R = new_r;
    device_colors[device_id].G = new_g;
    device_colors[device_id].B = new_b;
}

void turn_led_off(void) {
    changeColor(0, 0, 0);
}
