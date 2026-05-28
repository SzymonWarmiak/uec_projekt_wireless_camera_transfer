#include "spi_slave.h"
#include "driver/spi_slave.h"

#define GPIO_MOSI 6
#define GPIO_MISO 5
#define GPIO_SCLK 4
#define GPIO_CS   7

#define SPI_BUFFER_SIZE 76800

WORD_ALIGNED_ATTR uint8_t recvbuf[SPI_BUFFER_SIZE];
WORD_ALIGNED_ATTR uint8_t sendbuf[SPI_BUFFER_SIZE];

spi_slave_transaction_t t;
uint32_t spi_transactions = 0;
uint32_t spi_bytes_received = 0;

void spi_slave_task(void *pvParameters) {
    while(1) {
        spi_slave_transaction_t* ret_t;
        if (spi_slave_get_trans_result(SPI2_HOST, &ret_t, portMAX_DELAY) == ESP_OK) {
            spi_transactions++;
            spi_bytes_received += SPI_BUFFER_SIZE;
            spi_slave_queue_trans(SPI2_HOST, &t, portMAX_DELAY); 
        }
    }
}

void init_spi_slave() {
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
    
    memset(&t, 0, sizeof(t));
    t.length = SPI_BUFFER_SIZE * 8;
    t.tx_buffer = sendbuf;
    t.rx_buffer = recvbuf;
    spi_slave_queue_trans(SPI2_HOST, &t, portMAX_DELAY);
    
    xTaskCreate(spi_slave_task, "spi_task", 4096, NULL, 24, NULL);
}

uint32_t get_spi_transaction_count() {
    return spi_transactions;
}

uint32_t get_spi_bytes_received() {
    return spi_bytes_received;
}

const uint8_t* get_spi_buffer() {
    return recvbuf;
}

void set_spi_reply_word(uint16_t word) {
    // Basys1 odczytuje 2 pierwsze bajty podczas transakcji SPI (rx_byte_cnt 0..1)
    // Wysyłamy MSB najpierw, żeby pasowało do istniejącego mapowania w basys_1/rtl/top.sv.
    sendbuf[0] = (uint8_t)((word >> 8) & 0xFF);
    sendbuf[1] = (uint8_t)(word & 0xFF);
}