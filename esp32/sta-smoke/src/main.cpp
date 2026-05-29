#include <Arduino.h>
#include <WiFi.h>

static const char *kSsid = "bpd2";
static const char *kPass = "bpdbpdbpd";

unsigned long lastPrintMs = 0;

void printWifiStatus() {
  wl_status_t st = WiFi.status();
  Serial.print("[sta-smoke] status=");
  Serial.print((int)st);
  if (st == WL_CONNECTED) {
    Serial.print(" ip=");
    Serial.print(WiFi.localIP());
    Serial.print(" rssi=");
    Serial.println(WiFi.RSSI());
  } else {
    Serial.println();
  }
}

void setup() {
  Serial.begin(115200);
  delay(400);
  Serial.println("\n[sta-smoke] boot");

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(false);

  Serial.print("[sta-smoke] connecting ssid=");
  Serial.println(kSsid);
  WiFi.begin(kSsid, kPass);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(300);
    Serial.print('.');
  }
  Serial.println();
  printWifiStatus();
}

void loop() {
  if (millis() - lastPrintMs > 3000) {
    lastPrintMs = millis();
    printWifiStatus();
  }
  delay(50);
}
