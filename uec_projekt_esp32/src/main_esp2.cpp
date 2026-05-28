#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include "driver/spi_slave.h"

#define LED_PIN 8

const char* ssid = "ESP_VIDEO_TX";
const char* password = "video_stream";
const int udp_port = 1234;

WiFiUDP udp; 

#define GPIO_MOSI 6
#define GPIO_MISO 5
#define GPIO_SCLK 4
#define GPIO_CS   7
#define SPI_BUFFER_SIZE 76800

WORD_ALIGNED_ATTR uint8_t frame_buf[SPI_BUFFER_SIZE];
WORD_ALIGNED_ATTR uint8_t assemble_buf[SPI_BUFFER_SIZE];
WORD_ALIGNED_ATTR uint8_t spi_rx_hdr[2];
static spi_slave_transaction_t esp2_ctrl_t;
static spi_slave_transaction_t esp2_frame_t;

static uint16_t current_seq = 0;
static bool chunk_received[75] = {false};

static volatile uint8_t pending_buttons = 0;
static volatile bool pending_buttons_valid = false;

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
    while(1) {
        spi_slave_transaction_t* ret_t;
        if (spi_slave_get_trans_result(SPI2_HOST, &ret_t, portMAX_DELAY) == ESP_OK) {
            if (ret_t == &esp2_ctrl_t) {
                // Basys2 wysyła stan przycisków w transakcji kontrolnej (2 bajty MOSI)
                // Format słowa (MSB first): [15:4]=0, [3]=btnR, [2]=btnL, [1]=btnD, [0]=btnU
                uint16_t buttons_word = ((uint16_t)spi_rx_hdr[0] << 8) | (uint16_t)spi_rx_hdr[1];
                uint8_t buttons_nibble = (uint8_t)(buttons_word & 0x0F);
                static uint8_t last_buttons = 0xFF;

                if (buttons_nibble != last_buttons) {
                    pending_buttons = buttons_nibble;
                    pending_buttons_valid = true;
                    last_buttons = buttons_nibble;
                }
            } else if (ret_t == &esp2_frame_t) {
                // Po zakończeniu transferu ramki, kolejkowanie następnego cyklu: CTRL -> FRAME
                spi_slave_queue_trans(SPI2_HOST, &esp2_ctrl_t, portMAX_DELAY);
                spi_slave_queue_trans(SPI2_HOST, &esp2_frame_t, portMAX_DELAY);
            }
        }
    }
}

void setup() {
    Serial.begin(115200);
    delay(2000);
    Serial.println("\n--- START ESP32 NR 2 (Station) ---");
    WiFi.setSleep(WIFI_PS_NONE);
    
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

    // Transakcja kontrolna: 2 bajty (tylko RX MOSI)
    memset(&esp2_ctrl_t, 0, sizeof(esp2_ctrl_t));
    esp2_ctrl_t.length = 16;
    esp2_ctrl_t.tx_buffer = NULL;
    esp2_ctrl_t.rx_buffer = spi_rx_hdr;

    // Transakcja ramki: 76800 bajtów (TX wideo, RX niepotrzebny)
    memset(&esp2_frame_t, 0, sizeof(esp2_frame_t));
    esp2_frame_t.length = SPI_BUFFER_SIZE * 8;
    esp2_frame_t.tx_buffer = frame_buf;
    esp2_frame_t.rx_buffer = NULL;

    // Kolejkujemy startowy cykl: CTRL -> FRAME
    spi_slave_queue_trans(SPI2_HOST, &esp2_ctrl_t, portMAX_DELAY);
    spi_slave_queue_trans(SPI2_HOST, &esp2_frame_t, portMAX_DELAY);
    
    xTaskCreate(spi_tx_task, "spi_tx_task", 4096, NULL, 24, NULL);

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);
    Serial.print("Laczenie z Wi-Fi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.print("\nPolaczono z Twoja siecia! IP ESP2: ");
    Serial.println(WiFi.localIP());

    udp.begin(udp_port);
}

void loop() {
    unsigned long current_time = millis();
    static unsigned long last_req = 0;
    static unsigned long last_led_toggle = 0;
    static unsigned long last_broadcast = 0;
    static bool seq_initialized = false;
    static IPAddress esp1_ip;
    static uint16_t esp1_port = udp_port;

    if (current_time - last_req > 500) {
        if (current_time - last_broadcast > 500) {
            IPAddress myIP = WiFi.localIP();
            IPAddress subnet = WiFi.subnetMask();
            IPAddress bcastIP(myIP[0] | ~subnet[0], myIP[1] | ~subnet[1], myIP[2] | ~subnet[2], myIP[3] | ~subnet[3]);
            
            udp.beginPacket(bcastIP, udp_port);
            udp.write((const uint8_t*)"start", 5);
            udp.endPacket();
            last_broadcast = current_time;
            Serial.printf("Szukam ESP1 w sieci... (Wysylam Broadcast na: %s)\n", bcastIP.toString().c_str());
        }
    }

    int packetSize;
    bool data_received = false;

    while ((packetSize = udp.parsePacket()) > 0) {
        data_received = true;
        esp1_ip = udp.remoteIP();
        esp1_port = udp.remotePort();
        
        // Expected UDP payload: [seq_lo][seq_hi][chunk_id][1024 bytes]
        if (packetSize == 1027) {
            uint8_t seq_lo = udp.read();
            uint8_t seq_hi = udp.read();
            uint16_t seq = (uint16_t)seq_lo | ((uint16_t)seq_hi << 8);
            uint8_t chunk_id = udp.read();
            if (chunk_id < 75) {
                udp.read(assemble_buf + chunk_id * 1024, 1024);
                if (!seq_initialized) {
                    reset_chunk_state(seq);
                    seq_initialized = true;
                } else if (seq != current_seq) {
                    // New frame started (or we lost packets) -> start assembling new one
                    reset_chunk_state(seq);
                }

                chunk_received[chunk_id] = true;
                if (all_chunks_received()) {
                    memcpy(frame_buf, assemble_buf, SPI_BUFFER_SIZE);
                }
            }
        } else {
            udp.flush();
        }
    }

    if (pending_buttons_valid && (uint32_t)esp1_ip != 0 && esp1_port != 0) {
        // Pakiet kontrolny: [0xC0][buttons_nibble]
        udp.beginPacket(esp1_ip, esp1_port);
        udp.write((uint8_t)0xC0);
        udp.write((uint8_t)(pending_buttons & 0x0F));
        udp.endPacket();
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