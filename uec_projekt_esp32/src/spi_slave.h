#ifndef SPI_SLAVE_LOCAL_H
#define SPI_SLAVE_LOCAL_H

#include <Arduino.h>

void init_spi_slave();
uint16_t get_switch_states();
void set_led_states(uint16_t leds);
void set_servo_command(uint8_t command);
uint32_t get_spi_transaction_count();
uint32_t get_spi_bytes_received();
const uint8_t* get_spi_buffer();

#endif
