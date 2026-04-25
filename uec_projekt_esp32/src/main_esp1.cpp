#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include "spi_slave.h"

#define LED_PIN 8 // Pin wbudowanej diody LED

const char* ssid = "ESP_VIDEO_TX";     // Sieć nadawana przez ESP1
const char* pass = "video_stream";     // Hasło do sieci ESP1 (min. 8 znaków)
const int udp_port = 1234;

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
    digitalWrite(LED_PIN, HIGH); // Świeci ciągle podczas oczekiwania

    Serial.println("\n--- ESP1: Nadajnik Wideo (Tylko SPI -> UDP) ---");
    WiFi.setSleep(WIFI_PS_NONE);
    WiFi.mode(WIFI_AP);
    WiFi.setTxPower(WIFI_POWER_8_5dBm); // Obniżenie mocy sygnału dla stabilności
    WiFi.softAP(ssid, pass);            // Uruchomienie Access Pointa
    
    Serial.print("\nAccess Point uruchomiony! IP ESP1 (Nadajnika): ");
    Serial.println(WiFi.softAPIP());

    udp.begin(udp_port);
    init_spi_slave();
}

void loop() {
    unsigned long current_time = millis();
    static unsigned long last_debug_print = 0;

    // Co 1 sekunde wypisujemy status komunikacji SPI w celach diagnostycznych
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

    // Strumieniowanie obrazu zsynchronizowane z odbiorem nowych klatek po SPI
    static uint32_t last_spi_count = 0;
    uint32_t current_spi_count = get_spi_transaction_count();

    if (streaming && (current_spi_count != last_spi_count)) {
        const uint8_t* buf = get_spi_buffer();
        
        // Wysyłanie 75 fragmentów po 1024 bajty
        for (int i = 0; i < 75; i++) {
            udp.beginPacket(target_ip, target_port);
            udp.write((uint8_t)i);
            udp.write(buf + i * 1024, 1024);
            udp.endPacket();
            
            // Wi-Fi potrzebuje chwili na opróżnienie buforów sprzętowych (uniknięcie Error 12)
            if ((i & 1) == 1) {
                delay(1); // Przerwa 1ms co 2 pakiety
            } else {
                yield();  // Oddanie reszty czasu procesora do obsługi stosu Wi-Fi w tle
            }
        }
        
        // Ostatni pakiet 2-bajtowy
        udp.beginPacket(target_ip, target_port);
        udp.write((uint8_t)75);
        udp.write(buf + 76800, 2);
        udp.endPacket();
        
        last_spi_count = current_spi_count;
    }
    
    // Szybkie miganie diodą (ok. 10 Hz) podczas udanej komunikacji
    static bool led_state = false;
    if (streaming) {
        if (current_time - last_led_toggle > 50) {
            led_state = !led_state;
            digitalWrite(LED_PIN, led_state ? HIGH : LOW);
            last_led_toggle = current_time;
        }
    } else {
        digitalWrite(LED_PIN, HIGH); // Świeci ciągle, gdy brak transmisji
    }
}