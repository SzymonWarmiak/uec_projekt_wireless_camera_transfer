#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <Preferences.h>
#include "esp_system.h"
#include "driver/spi_slave.h"

#define LED_PIN 8

const char* setup_ssid = "Robot_jezdzik";
const char* setup_password = "jezdzik123";
const char* station_hostname = "jezdzik-station";
const int udp_port = 1234;

WiFiUDP udp;

#define GPIO_MOSI 6
#define GPIO_MISO 5
#define GPIO_SCLK 4
#define GPIO_CS   7
#define SPI_BUFFER_SIZE 76800

// Jeden bufor wideo (bez assemble_buf = oszczednosc ~76 KB DRAM).
WORD_ALIGNED_ATTR uint8_t frame_buf[SPI_BUFFER_SIZE];
// Tylko transakcja CTRL (32 bity = 4 bajty). NIGDY nie podlaczac tego bufora
// do transakcji FRAME (76800 B) - DMA zapisze 76 KB i zcrashuje ESP.
WORD_ALIGNED_ATTR uint8_t mosi_hdr[4];

static spi_slave_transaction_t esp2_ctrl_t;
static spi_slave_transaction_t esp2_frame_t;

static uint16_t current_seq = 0;
static bool chunk_received[75] = {false};

static volatile uint8_t pending_buttons = 0;
static volatile bool pending_buttons_valid = false;
static IPAddress esp1_ip;
static uint16_t esp1_port = udp_port;

struct WifiConfig {
    String ssid;
    String password;
    String station_ip;
};

static void clear_pending_wifi_config() {
    Preferences prefs;
    if (!prefs.begin("wifi_switch", false))
        return;
    prefs.clear();
    prefs.end();
}

static bool save_pending_wifi_config(const WifiConfig& cfg) {
    Preferences prefs;
    if (!prefs.begin("wifi_switch", false))
        return false;
    bool ok = prefs.putBool("pending", true) &&
              prefs.putString("ssid", cfg.ssid) > 0 &&
              prefs.putString("pass", cfg.password) >= 0 &&
              prefs.putString("ip", cfg.station_ip) >= 0;
    prefs.end();
    return ok;
}

static bool load_pending_wifi_config(WifiConfig& cfg) {
    Preferences prefs;
    if (!prefs.begin("wifi_switch", false))
        return false;

    bool pending = prefs.getBool("pending", false);
    if (!pending) {
        prefs.end();
        return false;
    }

    cfg.ssid = prefs.getString("ssid", "");
    cfg.password = prefs.getString("pass", "");
    cfg.station_ip = prefs.getString("ip", "AUTO");
    prefs.clear();
    prefs.end();
    return cfg.ssid.length() > 0;
}

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
    Serial.printf("%s role=esp_station mac=%s chip=%08X\n",
                  prefix, WiFi.macAddress().c_str(), (uint32_t)ESP.getEfuseMac());
}

static void start_setup_ap() {
    WiFi.persistent(false);
    WiFi.setAutoReconnect(false);
    WiFi.disconnect(true, true);
    WiFi.softAPdisconnect(true);
    WiFi.mode(WIFI_OFF);
    delay(200);
    WiFi.mode(WIFI_AP);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);
    WiFi.softAP(setup_ssid, setup_password);
    print_wifi_identity("ESP ID");
    Serial.printf("Robot_jezdzik AP: SSID=%s haslo=%s IP=%s\n",
                  setup_ssid, setup_password, WiFi.softAPIP().toString().c_str());
}

static bool connect_config_wifi(const WifiConfig& cfg) {
    WiFi.persistent(false);
    WiFi.setAutoReconnect(false);

    Serial.printf("ESP station przed zmiana: mode=%d status=%d ssid=%s ip=%s\n",
                  (int)WiFi.getMode(), (int)WiFi.status(), WiFi.SSID().c_str(),
                  WiFi.localIP().toString().c_str());

    WiFi.disconnect(true, true);
    WiFi.softAPdisconnect(true);

    Serial.print("Rozlaczam ESP station ze starego Wi-Fi");
    for (int i = 0; i < 30 && WiFi.status() == WL_CONNECTED; i++) {
        delay(100);
        Serial.print(".");
    }
    Serial.printf("\nPo rozlaczeniu: status=%d ssid=%s ip=%s\n",
                  (int)WiFi.status(), WiFi.SSID().c_str(),
                  WiFi.localIP().toString().c_str());

    WiFi.mode(WIFI_OFF);
    delay(800);
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(false);
    WiFi.setHostname(station_hostname);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);

    IPAddress local_ip;
    if (!is_auto_ip(cfg.station_ip) && local_ip.fromString(cfg.station_ip) &&
        !is_setup_network_ip(local_ip)) {
        IPAddress gateway(local_ip[0], local_ip[1], local_ip[2], 1);
        IPAddress subnet(255, 255, 255, 0);
        WiFi.config(local_ip, gateway, subnet, gateway);
        Serial.print("Statyczne IP ESP station: ");
        Serial.println(local_ip);
    } else {
        IPAddress empty_ip(0, 0, 0, 0);
        WiFi.config(empty_ip, empty_ip, empty_ip);
        Serial.println("ESP station uzywa DHCP.");
    }

    WiFi.begin(cfg.ssid.c_str(), cfg.password.c_str());
    Serial.printf("Laczenie ESP station z Wi-Fi: %s", cfg.ssid.c_str());
    for (int i = 0; i < 30 &&
                    (WiFi.status() != WL_CONNECTED ||
                     (uint32_t)WiFi.localIP() == 0);
         i++) {
        delay(500);
        Serial.print(".");
    }
    if (WiFi.status() != WL_CONNECTED || (uint32_t)WiFi.localIP() == 0) {
        Serial.println("\nNie udalo sie polaczyc. Wracam do Robot_jezdzik.");
        return false;
    }

    Serial.print("\nPolaczono ESP station. IP: ");
    Serial.println(WiFi.localIP());
    Serial.printf("ESP station po zmianie: status=%d ssid=%s ip=%s\n",
                  (int)WiFi.status(), WiFi.SSID().c_str(),
                  WiFi.localIP().toString().c_str());
    WiFi.setAutoReconnect(true);
    print_wifi_identity("ESP ID");
    Serial.println("Robot_jezdzik wylaczone.");
    return true;
}

static void send_start_packet(IPAddress target_ip) {
    udp.beginPacket(target_ip, udp_port);
    udp.write((const uint8_t*)"start", 5);
    udp.endPacket();
}

static void send_control_packet(IPAddress target_ip, uint8_t buttons) {
    udp.beginPacket(target_ip, udp_port);
    udp.write((uint8_t)0xC0);
    udp.write((uint8_t)(buttons & 0x0F));
    udp.endPacket();
}

static void send_config_packet(IPAddress target_ip, const char* req) {
    udp.beginPacket(target_ip, udp_port);
    udp.write((const uint8_t*)req, strlen(req));
    udp.endPacket();
}

static void request_camera_stream() {
    if ((uint32_t)esp1_ip != 0) {
        send_start_packet(esp1_ip);
        return;
    }

    wifi_mode_t mode = WiFi.getMode();
    if (mode == WIFI_AP || mode == WIFI_AP_STA) {
        IPAddress ap_ip = WiFi.softAPIP();
        send_start_packet(broadcast_for(ap_ip, IPAddress(255, 255, 255, 0)));
        for (uint8_t host = 2; host <= 4; host++) {
            send_start_packet(IPAddress(ap_ip[0], ap_ip[1], ap_ip[2], host));
        }
        return;
    }

    if ((mode == WIFI_STA || mode == WIFI_AP_STA) && WiFi.status() == WL_CONNECTED) {
        send_start_packet(broadcast_for(WiFi.localIP(), WiFi.subnetMask()));
    }
}

static void send_control_to_camera(uint8_t buttons) {
    if ((uint32_t)esp1_ip != 0) {
        send_control_packet(esp1_ip, buttons);
        return;
    }

    wifi_mode_t mode = WiFi.getMode();
    if (mode == WIFI_AP || mode == WIFI_AP_STA) {
        IPAddress ap_ip = WiFi.softAPIP();
        send_control_packet(broadcast_for(ap_ip, IPAddress(255, 255, 255, 0)), buttons);
        for (uint8_t host = 2; host <= 4; host++) {
            send_control_packet(IPAddress(ap_ip[0], ap_ip[1], ap_ip[2], host), buttons);
        }
        return;
    }

    if ((mode == WIFI_STA || mode == WIFI_AP_STA) && WiFi.status() == WL_CONNECTED) {
        send_control_packet(broadcast_for(WiFi.localIP(), WiFi.subnetMask()), buttons);
    }
}

static void forward_control_now(uint8_t buttons) {
    send_control_to_camera(buttons);
    if ((uint32_t)esp1_ip != 0) {
        Serial.printf("[UDP TX -> %s:%u] CTRL nibble=0x%X\n",
                      esp1_ip.toString().c_str(), esp1_port, buttons);
    } else {
        Serial.printf("[UDP TX broadcast] CTRL nibble=0x%X\n", buttons);
    }
}

static void forward_config_to_camera(const char* req) {
    if ((uint32_t)esp1_ip != 0) {
        send_config_packet(esp1_ip, req);
    }

    wifi_mode_t mode = WiFi.getMode();
    if (mode == WIFI_AP || mode == WIFI_AP_STA) {
        IPAddress ap_ip = WiFi.softAPIP();
        send_config_packet(broadcast_for(ap_ip, IPAddress(255, 255, 255, 0)), req);
        for (uint8_t host = 2; host <= 4; host++) {
            send_config_packet(IPAddress(ap_ip[0], ap_ip[1], ap_ip[2], host), req);
        }
        return;
    }

    if ((mode == WIFI_STA || mode == WIFI_AP_STA) && WiFi.status() == WL_CONNECTED) {
        send_config_packet(broadcast_for(WiFi.localIP(), WiFi.subnetMask()), req);
    }
}

static bool forward_config_to_camera_until_ack(const char* req) {
    unsigned long start = millis();
    while (millis() - start < 3500) {
        forward_config_to_camera(req);

        unsigned long wait_start = millis();
        while (millis() - wait_start < 160) {
            int packetSize = udp.parsePacket();
            if (packetSize <= 0) {
                delay(10);
                continue;
            }

            char reply[32] = {0};
            int n = udp.read((uint8_t*)reply, sizeof(reply) - 1);
            udp.flush();
            if (n > 0 && strncmp(reply, "CFG_OK", 6) == 0) {
                esp1_ip = udp.remoteIP();
                esp1_port = udp.remotePort();
                Serial.printf("ESP cam potwierdzil CFG: %s:%u\n",
                              esp1_ip.toString().c_str(), esp1_port);
                return true;
            }
        }
    }

    Serial.println("Brak CFG_OK z ESP cam.");
    return false;
}

static inline void reset_chunk_state(uint16_t new_seq) {
    current_seq = new_seq;
    for (int i = 0; i < 75; i++) chunk_received[i] = false;
}

static inline bool all_chunks_received() {
    for (int i = 0; i < 75; i++) {
        if (!chunk_received[i]) return false;
    }
    return true;
}

void spi_tx_task(void *pvParameters) {
    static uint8_t last_buttons = 0xFF;
    static uint32_t ctrl_dbg_cnt = 0;

    while (1) {
        spi_slave_transaction_t* ret_t;
        if (spi_slave_get_trans_result(SPI2_HOST, &ret_t, portMAX_DELAY) != ESP_OK) {
            continue;
        }

        if (ret_t == &esp2_ctrl_t) {
            uint16_t buttons_word = ((uint16_t)mosi_hdr[0] << 8) | (uint16_t)mosi_hdr[1];
            uint16_t marker       = ((uint16_t)mosi_hdr[2] << 8) | (uint16_t)mosi_hdr[3];
            uint8_t buttons_nibble = (uint8_t)(buttons_word & 0x0F);
            bool marker_ok = (marker == 0xCAFE);

            ctrl_dbg_cnt++;
            if ((ctrl_dbg_cnt % 64) == 0) {
                Serial.printf("[CTRL #%lu] mosi=%02X %02X %02X %02X marker=0x%04X(%s) nibble=0x%X\n",
                              (unsigned long)ctrl_dbg_cnt,
                              mosi_hdr[0], mosi_hdr[1], mosi_hdr[2], mosi_hdr[3],
                              marker, marker_ok ? "OK" : "BAD", buttons_nibble);
            }

            if (marker_ok && buttons_nibble != last_buttons) {
                pending_buttons = buttons_nibble;
                pending_buttons_valid = true;
                last_buttons = buttons_nibble;
                Serial.printf("[BTN CHANGE] -> 0x%X\n", buttons_nibble);
            }
        } else if (ret_t == &esp2_frame_t) {
            // Kolejny cykl: najpierw CTRL (32 bity), potem FRAME (tylko TX wideo).
            spi_slave_queue_trans(SPI2_HOST, &esp2_ctrl_t, portMAX_DELAY);
            spi_slave_queue_trans(SPI2_HOST, &esp2_frame_t, portMAX_DELAY);
        }
    }
}

void setup() {
    Serial.begin(115200);
    delay(2000);
    Serial.println("\n--- START ESP32 NR 2 (Station) ---");
    WiFi.persistent(false);
    WiFi.setSleep(WIFI_PS_NONE);
    print_wifi_identity("ESP ID");
    esp_reset_reason_t reset_reason = esp_reset_reason();
    Serial.printf("Reset reason=%d\n", (int)reset_reason);

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);

    spi_bus_config_t buscfg;
    memset(&buscfg, 0, sizeof(buscfg));
    buscfg.mosi_io_num = GPIO_MOSI;
    buscfg.miso_io_num = GPIO_MISO;
    buscfg.sclk_io_num = GPIO_SCLK;
    buscfg.quadwp_io_num = -1;
    buscfg.quadhd_io_num = -1;
    buscfg.max_transfer_sz = SPI_BUFFER_SIZE * 2;

    spi_slave_interface_config_t slvcfg;
    memset(&slvcfg, 0, sizeof(slvcfg));
    slvcfg.spics_io_num = GPIO_CS;
    slvcfg.flags = 0;
    slvcfg.queue_size = 2;
    slvcfg.mode = 0;

    #ifndef SPI_DMA_CH_AUTO
    #define SPI_DMA_CH_AUTO 3
    #endif

    spi_slave_initialize(SPI2_HOST, &buscfg, &slvcfg, SPI_DMA_CH_AUTO);

    memset(&esp2_ctrl_t, 0, sizeof(esp2_ctrl_t));
    esp2_ctrl_t.length = 32;
    esp2_ctrl_t.tx_buffer = NULL;
    esp2_ctrl_t.rx_buffer = mosi_hdr;

    memset(&esp2_frame_t, 0, sizeof(esp2_frame_t));
    esp2_frame_t.length = SPI_BUFFER_SIZE * 8;
    esp2_frame_t.tx_buffer = frame_buf;
    esp2_frame_t.rx_buffer = NULL;

    spi_slave_queue_trans(SPI2_HOST, &esp2_ctrl_t, portMAX_DELAY);
    spi_slave_queue_trans(SPI2_HOST, &esp2_frame_t, portMAX_DELAY);

    xTaskCreate(spi_tx_task, "spi_tx_task", 4096, NULL, 24, NULL);

    WifiConfig pending_cfg;
    bool has_pending = load_pending_wifi_config(pending_cfg);
    if (has_pending) {
        Serial.printf("Restart po CFG: lacze ESP station z Wi-Fi: %s\n",
                      pending_cfg.ssid.c_str());
        if (!connect_config_wifi(pending_cfg)) {
            start_setup_ap();
        }
    } else {
        start_setup_ap();
    }
    udp.begin(udp_port);
}

void loop() {
    unsigned long current_time = millis();
    static unsigned long last_req = 0;
    static unsigned long last_led_toggle = 0;
    static unsigned long last_broadcast = 0;
    static bool seq_initialized = false;

    if (current_time - last_req > 500) {
        if (current_time - last_broadcast > 500) {
            request_camera_stream();
            last_broadcast = current_time;
        }
    }

    int packetSize;
    bool data_received = false;

    while ((packetSize = udp.parsePacket()) > 0) {
        data_received = true;
        if (packetSize == 1027) {
            esp1_ip = udp.remoteIP();
            esp1_port = udp.remotePort();
            uint8_t seq_lo = udp.read();
            uint8_t seq_hi = udp.read();
            uint16_t seq = (uint16_t)seq_lo | ((uint16_t)seq_hi << 8);
            uint8_t chunk_id = udp.read();
            if (chunk_id < 75) {
                udp.read(frame_buf + chunk_id * 1024, 1024);
                if (!seq_initialized) {
                    reset_chunk_state(seq);
                    seq_initialized = true;
                } else if (seq != current_seq) {
                    reset_chunk_state(seq);
                }

                chunk_received[chunk_id] = true;
            }
        } else if (packetSize == 1) {
            pending_buttons = (uint8_t)(udp.read() & 0x0F);
            Serial.printf("[UDP RX APP] CTRL nibble=0x%X\n", pending_buttons);
            forward_control_now(pending_buttons);
            pending_buttons_valid = false;
        } else if (packetSize == 2) {
            uint8_t b0 = (uint8_t)udp.read();
            uint8_t b1 = (uint8_t)udp.read();
            if (b0 == 0xC0) {
                pending_buttons = (uint8_t)(b1 & 0x0F);
                Serial.printf("[UDP RX APP] CTRL nibble=0x%X\n", pending_buttons);
                forward_control_now(pending_buttons);
                pending_buttons_valid = false;
            }
        } else {
            char req[192] = {0};
            int n = udp.read((uint8_t*)req, sizeof(req) - 1);
            udp.flush();

            String new_ssid;
            String new_password;
            String new_station_ip;
            if (n > 0 && strncmp(req, "cam", 3) == 0) {
                esp1_ip = udp.remoteIP();
                esp1_port = udp.remotePort();
                Serial.printf("[CAM HELLO] %s:%u\n",
                              esp1_ip.toString().c_str(), esp1_port);
                send_start_packet(esp1_ip);
            } else if (n > 0 && strncmp(req, "RESET_SETUP", 11) == 0) {
                forward_config_to_camera("RESET_SETUP");
                esp1_ip = IPAddress();
                esp1_port = udp_port;
                start_setup_ap();
                udp.stop();
                udp.begin(udp_port);
                Serial.println("ESP station wrocil do Robot_jezdzik.");
            } else if (n > 0 && parse_config_command(req, new_ssid, new_password,
                                                     new_station_ip)) {
                IPAddress app_ip = udp.remoteIP();
                uint16_t app_port = udp.remotePort();
                bool cam_ack = forward_config_to_camera_until_ack(req);
                udp.beginPacket(app_ip, app_port);
                udp.write((const uint8_t*)(cam_ack ? "OK" : "NO_CAM_ACK"),
                          cam_ack ? 2 : 10);
                udp.endPacket();

                if (!cam_ack) {
                    Serial.println("Brak CFG_OK z cam, ale przelaczam station, zeby ESP nie zostaly w dwoch sieciach.");
                }

                WifiConfig cfg;
                cfg.ssid = new_ssid;
                cfg.password = new_password;
                cfg.station_ip = new_station_ip;

                Serial.printf("Zapisuje pending Wi-Fi dla ESP station: %s\n", cfg.ssid.c_str());
                if (!save_pending_wifi_config(cfg)) {
                    Serial.println("BLAD: nie udalo sie zapisac pending Wi-Fi.");
                    continue;
                }

                Serial.println("Restartuje ESP station programowo i po restarcie lacze z nowym Wi-Fi.");
                udp.stop();
                delay(400);
                ESP.restart();
            }
        }
    }

    if (pending_buttons_valid) {
        forward_control_now(pending_buttons);
        pending_buttons_valid = false;
    }

    if (data_received) {
        last_req = current_time;
    }

    static bool led_state = false;
    bool is_communicating = (current_time - last_req < 500);
    if (is_communicating) {
        if (current_time - last_led_toggle > 50) {
            led_state = !led_state;
            digitalWrite(LED_PIN, led_state ? HIGH : LOW);
            last_led_toggle = current_time;
        }
    } else {
        digitalWrite(LED_PIN, HIGH);
    }
}
