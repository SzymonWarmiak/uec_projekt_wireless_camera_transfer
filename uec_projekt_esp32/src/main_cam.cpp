#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include "spi_slave.h"

#define LED_PIN 8

const char* setup_ssid = "Robot_jezdzik";
const char* setup_password = "jezdzik123";
const char* cam_hostname = "jezdzik-cam";
const int udp_port = 1234;

WiFiUDP udp;

IPAddress target_ip;
uint16_t target_port = 0;
bool streaming = false;
unsigned long last_led_toggle = 0;
unsigned long last_hello = 0;
static uint16_t frame_seq = 0;
static uint32_t last_spi_count = 0;
static bool force_frame_send = false;

static bool parse_config_command(const char* req, String& ssid, String& password,
                                 String& station_ip) {
    String text(req);
    if (!text.startsWith("CFG\n"))
        return false;

    int p0 = 4;
    int p1 = text.indexOf('\n', p0);
    int p2 = p1 < 0 ? -1 : text.indexOf('\n', p1 + 1);
    int p3 = p2 < 0 ? -1 : text.indexOf('\n', p2 + 1);
    if (p1 < 0 || p2 < 0)
        return false;

    ssid = text.substring(p0, p1);
    password = text.substring(p1 + 1, p2);
    station_ip = p3 < 0 ? text.substring(p2 + 1) : text.substring(p2 + 1, p3);
    ssid.trim();
    password.trim();
    station_ip.trim();
    return ssid.length() > 0;
}

static bool is_auto_ip(const String& value) {
    return value.length() == 0 || value.equalsIgnoreCase("AUTO");
}

static bool is_setup_network_ip(const IPAddress& ip) {
    return ip[0] == 192 && ip[1] == 168 && ip[2] == 4;
}

static IPAddress broadcast_for(IPAddress ip, IPAddress subnet) {
    return IPAddress(ip[0] | ~subnet[0], ip[1] | ~subnet[1],
                     ip[2] | ~subnet[2], ip[3] | ~subnet[3]);
}

static void print_wifi_identity(const char* prefix) {
    Serial.printf("%s role=esp_cam mac=%s chip=%08X\n",
                  prefix, WiFi.macAddress().c_str(), (uint32_t)ESP.getEfuseMac());
}

static bool connect_wifi_sta(const char* ssid, const char* password, int attempts) {
    WiFi.disconnect(true, true);
    WiFi.mode(WIFI_OFF);
    delay(250);
    WiFi.mode(WIFI_STA);
    WiFi.setHostname(cam_hostname);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);
    IPAddress empty_ip(0, 0, 0, 0);
    WiFi.config(empty_ip, empty_ip, empty_ip);

    Serial.print("Rozlaczam ESP cam ze starego Wi-Fi");
    for (int i = 0; i < 20 && WiFi.status() == WL_CONNECTED; i++) {
        delay(100);
        Serial.print(".");
    }
    Serial.println();

    WiFi.begin(ssid, password);
    Serial.printf("Laczenie z Wi-Fi: %s", ssid);
    for (int i = 0; i < attempts &&
                    (WiFi.status() != WL_CONNECTED ||
                     (uint32_t)WiFi.localIP() == 0);
         i++) {
        delay(500);
        Serial.print(".");
    }
    if (WiFi.status() != WL_CONNECTED || (uint32_t)WiFi.localIP() == 0) {
        Serial.println("\nNie udalo sie polaczyc.");
        return false;
    }
    Serial.print("\nPolaczono. IP ESP cam: ");
    Serial.println(WiFi.localIP());
    print_wifi_identity("ESP ID");
    return true;
}

static void connect_setup_wifi() {
    while (!connect_wifi_sta(setup_ssid, setup_password, 30)) {
        delay(1000);
    }
}

static void handle_basys_led_byte(uint8_t value) {
    uint8_t nibble = value & 0x0F;
    uint8_t encoded = (uint8_t)((nibble << 4) | nibble);
    set_spi_reply_word((uint16_t)(((uint16_t)encoded << 8) | encoded));
    Serial.printf("[SPI MISO->Basys] L298N ctrl nibble=0x%X\n", nibble);
}

static void send_hello(IPAddress ip, uint16_t port) {
    udp.beginPacket(ip, port);
    udp.write((const uint8_t*)"cam", 3);
    udp.endPacket();
}

static void send_link_hello() {
    if (WiFi.status() != WL_CONNECTED)
        return;

    if (streaming && target_port != 0) {
        send_hello(target_ip, target_port);
        return;
    }

    IPAddress local_ip = WiFi.localIP();
    IPAddress target = is_setup_network_ip(local_ip)
        ? IPAddress(192, 168, 4, 1)
        : broadcast_for(local_ip, WiFi.subnetMask());
    send_hello(target, udp_port);
}

static void start_stream_to(IPAddress ip, uint16_t port) {
    target_ip = ip;
    target_port = port;
    streaming = true;
    force_frame_send = true;
    last_hello = 0;
    Serial.printf("Stream -> %s:%u\n", target_ip.toString().c_str(), target_port);
}

static void refresh_stream_to(IPAddress ip, uint16_t port) {
    if (!streaming || (uint32_t)target_ip != (uint32_t)ip || target_port != port) {
        start_stream_to(ip, port);
    } else {
        force_frame_send = true;
        send_hello(target_ip, target_port);
    }
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
        if (b0 == 0xC0) {
            handle_basys_led_byte(b1);
            refresh_stream_to(udp.remoteIP(), udp.remotePort());
        }
        return;
    }

    char req[192] = {0};
    int n = udp.read((uint8_t*)req, sizeof(req) - 1);
    udp.flush();
    if (n <= 0)
        return;

    String new_ssid;
    String new_password;
    String new_station_ip;
    if (parse_config_command(req, new_ssid, new_password, new_station_ip)) {
        IPAddress reply_ip = udp.remoteIP();
        uint16_t reply_port = udp.remotePort();
        for (int i = 0; i < 3; i++) {
            udp.beginPacket(reply_ip, reply_port);
            udp.write((const uint8_t*)"CFG_OK", 6);
            udp.endPacket();
            delay(40);
        }

        streaming = false;
        target_port = 0;
        target_ip = IPAddress();
        force_frame_send = false;
        Serial.printf("Przelaczam ESP cam na Wi-Fi: %s\n", new_ssid.c_str());
        if (connect_wifi_sta(new_ssid.c_str(), new_password.c_str(), 30)) {
            IPAddress station_ip;
            udp.stop();
            udp.begin(udp_port);
            last_hello = 0;
            if (!is_auto_ip(new_station_ip) && station_ip.fromString(new_station_ip) &&
                !is_setup_network_ip(station_ip)) {
                start_stream_to(station_ip, udp_port);
            } else {
                Serial.println("Czekam na start streamu od ESP station.");
                for (int i = 0; i < 10; i++) {
                    send_link_hello();
                    delay(120);
                }
            }
        } else {
            Serial.println("Wracam do Robot_jezdzik.");
            connect_setup_wifi();
            udp.stop();
            udp.begin(udp_port);
            last_hello = 0;
        }
    } else if (strncmp(req, "RESET_SETUP", 11) == 0) {
        streaming = false;
        target_port = 0;
        target_ip = IPAddress();
        force_frame_send = false;
        Serial.println("ESP cam wraca do Robot_jezdzik.");
        connect_setup_wifi();
        udp.stop();
        udp.begin(udp_port);
        last_hello = 0;
    } else if (strncmp(req, "start", 5) == 0) {
        start_stream_to(udp.remoteIP(), udp.remotePort());
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

    Serial.println("\n--- ESP cam: SPI wideo + SPI MISO sterowanie L298N IN1..IN4 ---");
    Serial.println("UDP: start | stop | led <0-15> | 1 bajt = nibble kierunku");
    Serial.println("USB: cyfra hex 0-F lub 1/2/4/8 (IN1..IN4)");

    WiFi.setSleep(WIFI_PS_NONE);
    print_wifi_identity("ESP ID");
    set_spi_reply_word(0);
    init_spi_slave();
    connect_setup_wifi();
    udp.begin(udp_port);
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

    if (current_time - last_hello > 500) {
        send_link_hello();
        last_hello = current_time;
    }

    uint32_t current_spi_count = get_spi_transaction_count();

    if (streaming && WiFi.status() == WL_CONNECTED &&
        (force_frame_send || current_spi_count != last_spi_count)) {
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

            int controlPacketSize = udp.parsePacket();
            if (controlPacketSize > 0)
                handle_udp_command(controlPacketSize);
        }
        last_spi_count = current_spi_count;
        force_frame_send = false;
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
