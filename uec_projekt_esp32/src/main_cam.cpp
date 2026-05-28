#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include "spi_slave.h"

#define LED_PIN 8

const char* ssid = "ESP_VIDEO_TX";
const char* pass = "video_stream";
const int udp_port = 1234;

WiFiUDP udp;

IPAddress target_ip;
uint16_t target_port = 0;
bool streaming = false;
unsigned long last_frame_time = 0;
unsigned long last_led_toggle = 0;
static uint16_t frame_seq = 0;

void setup() {
    Serial.begin(115200);
    delay(2000);
    
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);

    Serial.println("\n--- ESP1: Nadajnik Wideo (Tylko SPI -> UDP) ---");
    WiFi.setSleep(WIFI_PS_NONE);
    WiFi.mode(WIFI_AP);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);
    WiFi.softAP(ssid, pass);
    
    Serial.print("\nAccess Point uruchomiony! IP ESP1 (Nadajnika): ");
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
        // Pakiet kontrolny: [0xC0][buttons_nibble] (bit0=U, bit1=R, bit2=D, bit3=L)
        if (packetSize == 2) {
            uint8_t hdr = udp.read();
            uint8_t buttons = udp.read();
            udp.flush();
            if (hdr == 0xC0) {
                set_spi_reply_word((uint16_t)(buttons & 0x0F));
                Serial.printf("[UDP RX CTRL] hdr=0x%02X nibble=0x%X\n", hdr, buttons & 0x0F);
            } else {
                Serial.printf("[UDP RX 2B BAD HDR] hdr=0x%02X data=0x%02X\n", hdr, buttons);
            }
        } else {
            uint8_t req[16] = {0};
            udp.read(req, 15);
            udp.flush();

            if (strncmp((char*)req, "start", 5) == 0) {
                target_ip = udp.remoteIP();
                target_port = udp.remotePort();
                if (!streaming) {
                    Serial.printf("Rozpoczęto strumieniowanie obrazu do: %s:%d\n", target_ip.toString().c_str(), target_port);
                }
                streaming = true;
            }
            else if (strncmp((char*)req, "stop", 4) == 0) {
                streaming = false;
                Serial.println("Zatrzymano strumieniowanie.");
            }
        }
    }

    static uint32_t last_spi_count = 0;
    uint32_t current_spi_count = get_spi_transaction_count();

    if (streaming && (current_spi_count != last_spi_count)) {
        const uint8_t* buf = get_spi_buffer();
        frame_seq++;
        
        for (int i = 0; i < 75; i++) {
            udp.beginPacket(target_ip, target_port);
            // UDP header: [frame_seq_lo][frame_seq_hi][chunk_id]
            udp.write((uint8_t)(frame_seq & 0xFF));
            udp.write((uint8_t)((frame_seq >> 8) & 0xFF));
            udp.write((uint8_t)i);
            udp.write(buf + i * 1024, 1024);
            udp.endPacket();
            
            if ((i & 1) == 1) {
                delay(1);
            } else {
                yield();
            }
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