#ifndef UART_CTRL_H
#define UART_CTRL_H

#include <Arduino.h>

// GPIO5 TX -> Basys JXADC pin 1 (XA1_P). SPI wideo tylko MOSI.
#define UART_CTRL_TX 5
#define UART_CTRL_RX 20

void init_uart_ctrl(void);
void uart_send_led_pattern(void);
void uart_send_ctrl_nibble(uint8_t nibble);
void uart_send_led_byte(uint8_t value);

#endif
