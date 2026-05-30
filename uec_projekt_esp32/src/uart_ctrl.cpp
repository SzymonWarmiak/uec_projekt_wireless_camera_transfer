#include "uart_ctrl.h"

static HardwareSerial CtrlUart(1);

// Bajt 0x0A = bity 1010 na LED[3:0] Basys (LD3..LD0)
static const uint8_t UART_LED_PATTERN = 0x0A;

void init_uart_ctrl() {
    CtrlUart.begin(9600, SERIAL_8N1, UART_CTRL_RX, UART_CTRL_TX);
}

void uart_send_led_pattern(void) {
    CtrlUart.write(UART_LED_PATTERN);
}

void uart_send_ctrl_nibble(uint8_t nibble) {
    CtrlUart.write((uint8_t)(nibble & 0x0F));
}

void uart_send_led_byte(uint8_t value) {
    CtrlUart.write(value);
}
