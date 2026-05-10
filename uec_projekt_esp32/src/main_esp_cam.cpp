#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include "spi_slave.h"

#define LED_PIN 8

const char* ssid = "ESP_VIDEO_TX";
const char* pass = "video_stream";
const int udp_port = 1234;
static constexpr int kFrameBytes = 76803;
static constexpr int kUdpChunkBytes = 1024;
static constexpr int kFullChunks = kFrameBytes / kUdpChunkBytes;
static constexpr int kLastChunkBytes = kFrameBytes - (kFullChunks * kUdpChunkBytes);

WiFiUDP udp;

IPAddress target_ip;
uint16_t target_port = 0;
bool streaming = false;
unsigned long last_frame_time = 0;
unsigned long last_led_toggle = 0;

void setup() {
    Serial.begin(115200);
    delay(2000);
    
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);

    Serial.println("\n--- ESP_CAM: Nadajnik Wideo (Tylko SPI -> UDP) ---");
    WiFi.setSleep(WIFI_PS_NONE);
    WiFi.mode(WIFI_AP);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);
    WiFi.softAP(ssid, pass);
    
    Serial.print("\nAccess Point uruchomiony! IP ESP_CAM (Nadajnika): ");
    Serial.println(WiFi.softAPIP());

    udp.begin(udp_port);
    init_spi_slave();
}

void loop() {
    unsigned long current_time = millis();
    static unsigned long last_debug_print = 0;

    if (current_time - last_debug_print > 1000) {
        uint32_t spi_count = get_spi_transaction_count();
        Serial.printf("[DEBUG] Odebrane pelne ramki SPI z Basys3: %u\n", spi_count);
        last_debug_print = current_time;
    }

    int packetSize = udp.parsePacket();
    if (packetSize > 0) {
        char req[16] = {0};
        udp.read(req, 15);
        udp.flush();

        if (strncmp(req, "start", 5) == 0) {
            target_ip = udp.remoteIP();
            target_port = udp.remotePort();
            if (!streaming) {
                Serial.printf("Rozpoczęto strumieniowanie obrazu do: %s:%d\n", target_ip.toString().c_str(), target_port);
            }
            streaming = true;
        }
        else if (strncmp(req, "stop", 4) == 0) {
            streaming = false;
            Serial.println("Zatrzymano strumieniowanie.");
        }
    }

    static uint32_t last_spi_count = 0;
    uint32_t current_spi_count = get_spi_transaction_count();

    if (streaming && (current_spi_count != last_spi_count)) {
        const uint8_t* buf = get_spi_buffer();
        
        for (int i = 0; i < kFullChunks; i++) {
            udp.beginPacket(target_ip, target_port);
            udp.write((uint8_t)i);
            udp.write(buf + i * kUdpChunkBytes, kUdpChunkBytes);
            udp.endPacket();
            
            if ((i & 1) == 1) {
                delay(1);
            } else {
                yield();
            }
        }
        
        if (kLastChunkBytes > 0) {
            udp.beginPacket(target_ip, target_port);
            udp.write((uint8_t)kFullChunks);
            udp.write(buf + kFullChunks * kUdpChunkBytes, kLastChunkBytes);
            udp.endPacket();
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
