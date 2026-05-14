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
static spi_slave_transaction_t esp2_spi_t;

void spi_tx_task(void *pvParameters) {
    while(1) {
        spi_slave_transaction_t* ret_t;
        if (spi_slave_get_trans_result(SPI2_HOST, &ret_t, portMAX_DELAY) == ESP_OK) {
            spi_slave_queue_trans(SPI2_HOST, &esp2_spi_t, portMAX_DELAY); 
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
    slvcfg.queue_size = 1;
    slvcfg.mode = 0;

    #ifndef SPI_DMA_CH_AUTO
    #define SPI_DMA_CH_AUTO 3
    #endif

    spi_slave_initialize(SPI2_HOST, &buscfg, &slvcfg, SPI_DMA_CH_AUTO);

    memset(&esp2_spi_t, 0, sizeof(esp2_spi_t));
    esp2_spi_t.length = SPI_BUFFER_SIZE * 8;
    esp2_spi_t.tx_buffer = frame_buf;
    esp2_spi_t.rx_buffer = NULL;
    spi_slave_queue_trans(SPI2_HOST, &esp2_spi_t, portMAX_DELAY);
    
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
        
        if (packetSize == 1025) {
            uint8_t chunk_id = udp.read();
            if (chunk_id < 75) {
                udp.read(assemble_buf + chunk_id * 1024, 1024);
                if (chunk_id == 74) {
                    memcpy(frame_buf, assemble_buf, SPI_BUFFER_SIZE);
                }
            }
        } else {
            udp.flush();
        }
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