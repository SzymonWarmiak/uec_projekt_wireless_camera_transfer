#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include "spi_slave.h"
#include "uart_ctrl.h"

#define LED_PIN 8

const char* ssid = "ESP_VIDEO_TX";
const char* pass = "video_stream";
const int udp_port = 1234;

WiFiUDP udp;

IPAddress target_ip;
uint16_t target_port = 0;
bool streaming = false;
unsigned long last_led_toggle = 0;
static uint16_t frame_seq = 0;

static void handle_basys_led_byte(uint8_t value) {
    uart_send_led_byte(value);
    Serial.printf("[UART->Basys] L298N IN mask=0x%X\n", value & 0x0F);
}

static void poll_serial_led_commands(void) {
    while (Serial.available() > 0) {
        int c = Serial.read();
        if (c < 0)
            break;
        if (c >= '0' && c <= '9') {
            handle_basys_led_byte((uint8_t)(c - '0'));
        } else if (c >= 'a' && c <= 'f') {
            handle_basys_led_byte((uint8_t)(10 + (c - 'a')));
        } else if (c >= 'A' && c <= 'F') {
            handle_basys_led_byte((uint8_t)(10 + (c - 'A')));
        } else if (c == '1')
            handle_basys_led_byte(0x01);
        else if (c == '2')
            handle_basys_led_byte(0x02);
        else if (c == '4')
            handle_basys_led_byte(0x04);
        else if (c == '8')
            handle_basys_led_byte(0x08);
    }
}

static void handle_udp_command(int packetSize) {
    if (packetSize == 1) {
        handle_basys_led_byte((uint8_t)udp.read());
        return;
    }

    if (packetSize == 2) {
        uint8_t b0 = (uint8_t)udp.read();
        uint8_t b1 = (uint8_t)udp.read();
        if (b0 == 0xC0)
            handle_basys_led_byte(b1);
        return;
    }

    char req[16] = {0};
    int n = udp.read((uint8_t*)req, sizeof(req) - 1);
    udp.flush();
    if (n <= 0)
        return;

    if (strncmp(req, "start", 5) == 0) {
        target_ip = udp.remoteIP();
        target_port = udp.remotePort();
        streaming = true;
        Serial.printf("Stream -> %s:%u\n", target_ip.toString().c_str(), target_port);
    } else if (strncmp(req, "stop", 4) == 0) {
        streaming = false;
    } else if (strncmp(req, "led ", 4) == 0) {
        uint8_t v = (uint8_t)strtoul(req + 4, nullptr, 0);
        handle_basys_led_byte(v);
    }
}

void setup() {
    Serial.begin(115200);
    delay(2000);

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);

    Serial.println("\n--- ESP cam: SPI wideo (WiFi UDP) + UART -> L298N IN1..IN4 ---");
    Serial.println("UDP: start | stop | led <0-15> | 1 bajt = maska IN (JXADC 7..10)");
    Serial.println("USB: cyfra hex 0-F lub 1/2/4/8 (IN1..IN4)");

    WiFi.setSleep(WIFI_PS_NONE);
    WiFi.mode(WIFI_AP);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);
    WiFi.softAP(ssid, pass);
    Serial.println(WiFi.softAPIP());

    udp.begin(udp_port);
    init_spi_slave();
    init_uart_ctrl();
}

void loop() {
    unsigned long current_time = millis();
    static unsigned long last_debug = 0;

    poll_serial_led_commands();

    if (current_time - last_debug > 2000) {
        Serial.printf("[DEBUG] SPI frames=%u streaming=%d\n",
                      get_spi_transaction_count(), streaming ? 1 : 0);
        last_debug = current_time;
    }

    int packetSize = udp.parsePacket();
    if (packetSize > 0)
        handle_udp_command(packetSize);

    static uint32_t last_spi_count = 0;
    uint32_t current_spi_count = get_spi_transaction_count();

    if (streaming && (current_spi_count != last_spi_count)) {
        const uint8_t* buf = get_spi_buffer();
        frame_seq++;

        for (int i = 0; i < 75; i++) {
            udp.beginPacket(target_ip, target_port);
            udp.write((uint8_t)(frame_seq & 0xFF));
            udp.write((uint8_t)((frame_seq >> 8) & 0xFF));
            udp.write((uint8_t)i);
            udp.write(buf + i * 1024, 1024);
            udp.endPacket();
            if ((i & 1) == 1)
                delay(1);
            else
                yield();
        }
        last_spi_count = current_spi_count;
    }

    static bool led_state = false;
    if (streaming) {
        if (current_time - last_led_toggle > 50) {
            led_state = !led_state;
            digitalWrite(LED_PIN, led_state ? HIGH : LOW);
            last_led_toggle = current_time;
        }
    } else {
        digitalWrite(LED_PIN, HIGH);
    }
}
