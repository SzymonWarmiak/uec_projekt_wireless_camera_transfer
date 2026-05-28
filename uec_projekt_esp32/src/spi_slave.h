#ifndef SPI_SLAVE_LOCAL_H
#define SPI_SLAVE_LOCAL_H

#include <Arduino.h>

void init_spi_slave();
uint16_t get_switch_states();
uint32_t get_spi_transaction_count();
uint32_t get_spi_bytes_received();
const uint8_t* get_spi_buffer();
void set_spi_reply_word(uint16_t word);

#endif