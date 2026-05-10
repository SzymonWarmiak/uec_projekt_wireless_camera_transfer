#include <Arduino.h>
#include <Ps3Controller.h>
#include <WiFi.h>
#include <esp_now.h>

namespace {

constexpr uint8_t kLedPin = 2;
constexpr uint8_t kStationLeftOutPin = 17;
constexpr uint8_t kStationRightOutPin = 16;
constexpr uint8_t kStationUartTxPin = 4;
constexpr uint32_t kStationUartBaud = 115200;
constexpr unsigned long kTxIntervalMs = 20;
constexpr unsigned long kBlinkIntervalMs = 120;
constexpr unsigned long kStationPositionTxIntervalMs = 50;

const uint8_t kEspNowBroadcastAddr[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};

// If the PS3 pad is paired to a fixed host address, put it here.
// Leave empty to use this ESP32 Bluetooth address and pair the pad to it.
constexpr char kPs3HostMac[] = "a4:c3:f0:e3:9a:c1";

struct __attribute__((packed)) ServoMessage {
    uint8_t magic;
    uint8_t command;
};

struct __attribute__((packed)) ServoStatusMessage {
    uint8_t magic;
    uint8_t position;
    uint8_t direction;
};

uint8_t servoCommand = 0;
uint8_t servoPosition = 33;
uint8_t servoDirection = 0;
uint8_t lastSentCommand = 0xff;
unsigned long lastTxMs = 0;
unsigned long lastStationPositionTxMs = 0;
unsigned long lastBlinkMs = 0;
uint8_t connectBlinksLeft = 0;
bool ledState = false;
bool wasConnected = false;
unsigned long lastStatusPrintMs = 0;
bool espNowReady = false;

uint8_t readCommandFromPad() {
    const bool leftPressed = Ps3.data.button.left;
    const bool rightPressed = Ps3.data.button.right;

    if (leftPressed && !rightPressed) {
        return 1;
    }
    if (rightPressed && !leftPressed) {
        return 2;
    }
    return 0;
}

void notifyPadData() {
    servoCommand = readCommandFromPad();
}

void onPadConnect() {
    Serial.println("PS3 pad connected.");
}

void sendStationPosition(bool force = false) {
    const unsigned long now = millis();
    if (!force && (now - lastStationPositionTxMs) < kStationPositionTxIntervalMs) {
        return;
    }

    Serial2.write(0xa5);
    Serial2.write(servoPosition);
    Serial2.write(servoDirection);
    lastStationPositionTxMs = now;
}

void onEspNowRecv(const uint8_t *macAddr, const uint8_t *data, int dataLen) {
    (void)macAddr;

    if (dataLen != sizeof(ServoStatusMessage)) return;

    ServoStatusMessage msg;
    memcpy(&msg, data, sizeof(msg));
    if (msg.magic != 'P' || msg.position > 67 || msg.direction > 2) return;

    servoPosition = msg.position;
    servoDirection = msg.direction;
    sendStationPosition(true);
}

void initEspNow() {
    WiFi.mode(WIFI_STA);
    WiFi.setSleep(true);

    if (esp_now_init() != ESP_OK) {
        Serial.println("ESP-NOW init failed on ESP_PS3");
        return;
    }

    esp_now_peer_info_t peer = {};
    memcpy(peer.peer_addr, kEspNowBroadcastAddr, sizeof(kEspNowBroadcastAddr));
    peer.channel = 0;
    peer.encrypt = false;

    if (!esp_now_is_peer_exist(kEspNowBroadcastAddr)) {
        esp_err_t err = esp_now_add_peer(&peer);
        if (err != ESP_OK) {
            Serial.printf("ESP-NOW add broadcast peer failed: %d\n", err);
            return;
        }
    }

    espNowReady = true;
    esp_now_register_recv_cb(onEspNowRecv);
    Serial.println("ESP-NOW ready on ESP_PS3.");
}

void sendServoCommand(bool force = false) {
    const unsigned long now = millis();
    if (!force && servoCommand == lastSentCommand && (now - lastTxMs) < kTxIntervalMs) {
        return;
    }
    if (!force && (now - lastTxMs) < kTxIntervalMs) {
        return;
    }

    if (espNowReady) {
        ServoMessage msg = {'S', servoCommand};
        esp_err_t err = esp_now_send(kEspNowBroadcastAddr,
                                     reinterpret_cast<const uint8_t*>(&msg),
                                     sizeof(msg));
        if (err != ESP_OK) {
            Serial.printf("ESP-NOW -> ESP_CAM_SERVO command=%u failed: %d\n", servoCommand, err);
        }
    }

    digitalWrite(kStationLeftOutPin, servoCommand == 1 ? HIGH : LOW);
    digitalWrite(kStationRightOutPin, servoCommand == 2 ? HIGH : LOW);

    if (servoCommand != lastSentCommand || force) {
        Serial.printf("Servo command=%u (ESP-NOW + station GPIO)\n", servoCommand);
    }
    lastSentCommand = servoCommand;
    lastTxMs = now;
}

void serviceConnectionLed() {
    const bool connected = Ps3.isConnected();

    if (connected && !wasConnected) {
        connectBlinksLeft = 6;
        lastBlinkMs = 0;
    } else if (!connected && wasConnected) {
        servoCommand = 0;
        sendServoCommand(true);
        connectBlinksLeft = 0;
        ledState = false;
        digitalWrite(kLedPin, LOW);
    }
    wasConnected = connected;

    if (connectBlinksLeft == 0) {
        if (connected) {
            digitalWrite(kLedPin, HIGH);
        }
        return;
    }

    const unsigned long now = millis();
    if (now - lastBlinkMs >= kBlinkIntervalMs) {
        lastBlinkMs = now;
        ledState = !ledState;
        digitalWrite(kLedPin, ledState ? HIGH : LOW);
        --connectBlinksLeft;
    }
}

} // namespace

void setup() {
    Serial.begin(115200);
    delay(1000);

    pinMode(kLedPin, OUTPUT);
    pinMode(kStationLeftOutPin, OUTPUT);
    pinMode(kStationRightOutPin, OUTPUT);
    digitalWrite(kLedPin, LOW);
    digitalWrite(kStationLeftOutPin, LOW);
    digitalWrite(kStationRightOutPin, LOW);
    Serial2.begin(kStationUartBaud, SERIAL_8N1, -1, kStationUartTxPin);

    Ps3.attach(notifyPadData);
    Ps3.attachOnConnect(onPadConnect);
    if (strlen(kPs3HostMac) > 0) {
        Ps3.begin(kPs3HostMac);
    } else {
        Ps3.begin();
    }

    Serial.println("\n--- ESP_PS3: PS3 pad -> ESP_CAM_SERVO ESP-NOW ---");
    Serial.print("PS3 host MAC used by ESP32: ");
    Serial.println(strlen(kPs3HostMac) > 0 ? kPs3HostMac : Ps3.getAddress());
    Serial.println("Controls: D-pad left/right only.");
    Serial.println("Servo commands are sent directly to ESP_CAM_SERVO over ESP-NOW.");
    Serial.println("Station GPIO outputs: D17/GPIO17=left, D16/GPIO16=right.");
    Serial.println("Station UART position output: D4/GPIO4=position TX, 115200 baud.");

    initEspNow();
}

void loop() {
    const unsigned long now = millis();

    serviceConnectionLed();

    if (Ps3.isConnected()) {
        servoCommand = readCommandFromPad();
    } else {
        servoCommand = 0;
    }

    sendServoCommand();
    sendStationPosition();

    if (now - lastStatusPrintMs >= 1000) {
        lastStatusPrintMs = now;
        Serial.printf("PS3 status: %s, command=%u, servo_pos=%u, servo_dir=%u\n",
                      Ps3.isConnected() ? "connected" : "not connected",
                      servoCommand,
                      servoPosition,
                      servoDirection);
    }

    delay(1);
}
