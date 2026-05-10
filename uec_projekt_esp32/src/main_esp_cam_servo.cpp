#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>

#define LED_PIN 2
#define GPIO_SERVO_LEFT 17
#define GPIO_SERVO_RIGHT 16

static constexpr unsigned long kServoUpdateIntervalMs = 20;
static constexpr unsigned long kStatusTxIntervalMs = 50;
static constexpr uint8_t kServoPosMin = 0;
static constexpr uint8_t kServoPosCenter = 33;
static constexpr uint8_t kServoPosMax = 67;

struct __attribute__((packed)) ServoMessage {
    uint8_t magic;
    uint8_t command;
};

struct __attribute__((packed)) ServoStatusMessage {
    uint8_t magic;
    uint8_t position;
    uint8_t direction;
};

namespace {

uint8_t lastCommand = 0xff;
uint8_t currentCommand = 0;
uint8_t servoPosition = kServoPosCenter;
unsigned long lastPacketMs = 0;
unsigned long lastServoUpdateMs = 0;
unsigned long lastStatusTxMs = 0;
bool espNowReady = false;

const uint8_t kEspNowBroadcastAddr[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};

void applyServoCommand(uint8_t command) {
    if (command > 3) command = 0;

    currentCommand = command;
    digitalWrite(GPIO_SERVO_LEFT, (command == 1 || command == 3) ? HIGH : LOW);
    digitalWrite(GPIO_SERVO_RIGHT, (command == 2 || command == 3) ? HIGH : LOW);
    digitalWrite(LED_PIN, command == 0 ? HIGH : LOW);

    if (command != lastCommand) {
        Serial.printf("ESP-NOW <- ESP_PS3 servo command=%u\n", command);
        lastCommand = command;
    }
}

void sendServoStatus(bool force = false) {
    const unsigned long now = millis();
    if (!espNowReady) return;
    if (!force && (now - lastStatusTxMs) < kStatusTxIntervalMs) return;

    const uint8_t direction = currentCommand == 1 ? 1 : currentCommand == 2 ? 2 : 0;
    ServoStatusMessage msg = {'P', servoPosition, direction};
    esp_now_send(kEspNowBroadcastAddr, reinterpret_cast<const uint8_t*>(&msg), sizeof(msg));
    lastStatusTxMs = now;
}

void onEspNowRecv(const uint8_t *macAddr, const uint8_t *data, int dataLen) {
    (void)macAddr;

    if (dataLen != sizeof(ServoMessage)) return;

    ServoMessage msg;
    memcpy(&msg, data, sizeof(msg));
    if (msg.magic != 'S' || msg.command > 2) return;

    lastPacketMs = millis();
    applyServoCommand(msg.command);
}

void updateServoPosition() {
    const unsigned long now = millis();
    if (now - lastServoUpdateMs < kServoUpdateIntervalMs) return;
    lastServoUpdateMs = now;

    const uint8_t oldPosition = servoPosition;
    if (currentCommand == 3) {
        servoPosition = kServoPosCenter;
    } else if (currentCommand == 1 && servoPosition > kServoPosMin) {
        --servoPosition;
    } else if (currentCommand == 2 && servoPosition < kServoPosMax) {
        ++servoPosition;
    }

    sendServoStatus(servoPosition != oldPosition);
}

} // namespace

void setup() {
    Serial.begin(115200);
    delay(1000);

    pinMode(LED_PIN, OUTPUT);
    pinMode(GPIO_SERVO_LEFT, OUTPUT);
    pinMode(GPIO_SERVO_RIGHT, OUTPUT);
    applyServoCommand(3);
    delay(700);
    applyServoCommand(0);

    WiFi.mode(WIFI_STA);
    WiFi.setSleep(false);

    if (esp_now_init() != ESP_OK) {
        Serial.println("ESP-NOW init failed on ESP_CAM_SERVO");
        return;
    }
    esp_now_register_recv_cb(onEspNowRecv);
    esp_now_peer_info_t peer = {};
    memcpy(peer.peer_addr, kEspNowBroadcastAddr, sizeof(kEspNowBroadcastAddr));
    peer.channel = 0;
    peer.encrypt = false;
    if (!esp_now_is_peer_exist(kEspNowBroadcastAddr)) {
        esp_now_add_peer(&peer);
    }
    espNowReady = true;
    sendServoStatus(true);

    Serial.println("\n--- ESP_CAM_SERVO: ESP-NOW servo receiver ---");
    Serial.printf("Outputs: left=GPIO%d, right=GPIO%d\n", GPIO_SERVO_LEFT, GPIO_SERVO_RIGHT);
    Serial.print("Wi-Fi MAC: ");
    Serial.println(WiFi.macAddress());
}

void loop() {
    const unsigned long now = millis();
    static unsigned long lastStatusMs = 0;

    if (lastPacketMs != 0 && now - lastPacketMs > 500) {
        applyServoCommand(0);
    }

    updateServoPosition();
    sendServoStatus();

    if (now - lastStatusMs >= 1000) {
        lastStatusMs = now;
        Serial.printf("ESP_CAM_SERVO status: command=%u position=%u last_age_ms=%lu\n",
                      lastCommand,
                      servoPosition,
                      lastPacketMs == 0 ? 0 : now - lastPacketMs);
    }
}
