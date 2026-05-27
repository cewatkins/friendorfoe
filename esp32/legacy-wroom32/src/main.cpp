#include <Arduino.h>

// Common on-board LED pin for many ESP32 dev boards; harmless if absent.
static const int kLedPin = 2;

void setup() {
  pinMode(kLedPin, OUTPUT);
  digitalWrite(kLedPin, LOW);

  Serial.begin(115200);
  delay(500);
  Serial.println("FoF legacy WROOM32 probe booted");
  Serial.println("Expect LED toggle every 500ms");
}

void loop() {
  static bool on = false;
  on = !on;
  digitalWrite(kLedPin, on ? HIGH : LOW);
  Serial.println(on ? "tick:on" : "tick:off");
  delay(500);
}