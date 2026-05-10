#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include "driver/spi_slave.h"

#define LED_PIN 8

const char* ssid = "ESP_VIDEO_TX";
const char* password = "video_stream";
const int udp_port = 1234;
static constexpr int kFrameBytes = 76803;
static constexpr int kUdpChunkBytes = 1024;
static constexpr int kFullChunks = kFrameBytes / kUdpChunkBytes;
static constexpr int kLastChunkBytes = kFrameBytes - (kFullChunks * kUdpChunkBytes);

WiFiUDP udp; 

#define GPIO_MOSI 6
#define GPIO_MISO 5
#define GPIO_SCLK 4
#define GPIO_CS   7
#define SPI_BUFFER_SIZE 76803

WORD_ALIGNED_ATTR uint8_t frame_buf[SPI_BUFFER_SIZE];
WORD_ALIGNED_ATTR uint8_t assemble_buf[SPI_BUFFER_SIZE];
static spi_slave_transaction_t esp_station_spi_t;

void spi_tx_task(void *pvParameters) {
    while(1) {
        spi_slave_transaction_t* ret_t;
        if (spi_slave_get_trans_result(SPI2_HOST, &ret_t, portMAX_DELAY) == ESP_OK) {
            spi_slave_queue_trans(SPI2_HOST, &esp_station_spi_t, portMAX_DELAY); 
        }
    }
}

void send_control_broadcast(const uint8_t* data, size_t len) {
    IPAddress myIP = WiFi.localIP();
    IPAddress subnet = WiFi.subnetMask();
    IPAddress bcastIP(myIP[0] | ~subnet[0], myIP[1] | ~subnet[1], myIP[2] | ~subnet[2], myIP[3] | ~subnet[3]);

    udp.beginPacket(bcastIP, udp_port);
    udp.write(data, len);
    udp.endPacket();
}

void setup() {
    Serial.begin(115200);
    delay(2000);
    Serial.println("\n--- START ESP_STATION ---");
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
    slvcfg.queue_size = 1;
    slvcfg.mode = 0;

    #ifndef SPI_DMA_CH_AUTO
    #define SPI_DMA_CH_AUTO 3
    #endif

    spi_slave_initialize(SPI2_HOST, &buscfg, &slvcfg, SPI_DMA_CH_AUTO);

    memset(&esp_station_spi_t, 0, sizeof(esp_station_spi_t));
    memset(frame_buf, 0, sizeof(frame_buf));
    memset(assemble_buf, 0, sizeof(assemble_buf));
    esp_station_spi_t.length = SPI_BUFFER_SIZE * 8;
    esp_station_spi_t.tx_buffer = frame_buf;
    esp_station_spi_t.rx_buffer = NULL;
    spi_slave_queue_trans(SPI2_HOST, &esp_station_spi_t, portMAX_DELAY);
    
    xTaskCreate(spi_tx_task, "spi_tx_task", 4096, NULL, 24, NULL);

    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
    WiFi.setTxPower(WIFI_POWER_8_5dBm);
    Serial.print("Laczenie z Wi-Fi");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.print("\nPolaczono z Twoja siecia! IP ESP_STATION: ");
    Serial.println(WiFi.localIP());

    udp.begin(udp_port);
}

void loop() {
    unsigned long current_time = millis();
    static unsigned long last_req = 0;
    static unsigned long last_led_toggle = 0;
    static unsigned long last_broadcast = 0;
    static unsigned long last_status = 0;
    static unsigned long last_data_received = 0;

    if (current_time - last_req > 500) {
        if (current_time - last_broadcast > 500) {
            send_control_broadcast((const uint8_t*)"start", 5);
            last_broadcast = current_time;
        }
    }

    int packetSize;
    bool data_received = false;
    while ((packetSize = udp.parsePacket()) > 0) {
        data_received = true;
        
        if (packetSize == kUdpChunkBytes + 1) {
            uint8_t chunk_id = udp.read();
            if (chunk_id < kFullChunks) {
                const int chunk_offset = chunk_id * kUdpChunkBytes;
                udp.read(assemble_buf + chunk_offset, kUdpChunkBytes);
                memcpy(frame_buf + chunk_offset, assemble_buf + chunk_offset, kUdpChunkBytes);
            }
        } else if (packetSize == kLastChunkBytes + 1) {
            uint8_t chunk_id = udp.read();
            if (chunk_id == kFullChunks) {
                udp.read(assemble_buf + kFullChunks * kUdpChunkBytes, kLastChunkBytes);
                memcpy(frame_buf + kFullChunks * kUdpChunkBytes,
                       assemble_buf + kFullChunks * kUdpChunkBytes,
                       kLastChunkBytes);
            }
        } else {
            udp.flush();
        }
    }

    if (data_received) {
        last_req = current_time;
        last_data_received = current_time;
    }

    if (current_time - last_status > 1000) {
        last_status = current_time;
        Serial.printf("Video status: last_udp_age_ms=%lu\n",
                      last_data_received == 0 ? 0 : current_time - last_data_received);
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
