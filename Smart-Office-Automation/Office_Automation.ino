/*
  ============================================================================
  ESP32 Smart Office Automation (Access Point mode) - FOR THE FABRICATED PCB
  ============================================================================
  Auto behavior (ALL auto actions require the room to be OCCUPIED):
    - PIR sensor  -> room occupied / empty (with a hold time after motion)
    - DHT11       -> temperature + humidity, shown on OLED + webpage
    - Fan turns ON automatically only if room is occupied AND temp > TEMP_ON_C
    - Light turns ON automatically only if room is occupied AND it's dark
    - If the room is empty, fan and light are auto-turned OFF regardless of
      temperature/darkness (no point cooling/lighting an empty room)
  Manual override:
    - LIGHT_BTN / FAN_BTN toggle that channel and lock it to manual mode.
      Hold ~2s to hand it back to auto. Debounced (30ms) for reliable presses.
    - Webpage at http://192.168.4.1/ can also force ON / OFF / AUTO.
  Wi-Fi:
    - ESP32 creates its own Access Point (SmartOffice_ESP32 / office1234).

  RELAY LOGIC: ACTIVE-HIGH (matches your PCB's Q2/Q4 transistor + relay circuit)
    - GPIO HIGH -> relay energized / ON
    - GPIO LOW  -> relay de-energized / OFF

  PIN MAP (from final schematics: ESP32 main / output / power sheets):
    GPIO4   -> DHT11 data           (J12)
    GPIO21  -> I2C SDA              (OLED, J4)
    GPIO22  -> I2C SCL              (OLED, J4)
    GPIO34  -> LDR_ADC (analog in)  (R8/R9 divider)
    GPIO32  -> LIGHT_BTN            (J7, active LOW w/ internal pullup)
    GPIO33  -> FAN_BTN              (J8, active LOW w/ internal pullup)
    GPIO26  -> RELAY1 -> Q2 -> K1 -> J9   = FAN
    GPIO25  -> RELAY2 -> Q4 -> K3 -> J13  = LIGHT
    GPIO13  -> PIR_OUT               (J3, active HIGH on motion)
  ============================================================================
*/

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>

const char* AP_SSID = "SmartOffice_ESP32";
const char* AP_PASS = "office1234";

const float   TEMP_ON_C        = 28.0;
const float   TEMP_OFF_C       = 26.5;
const int     DARK_THRESHOLD   = 1500;
const int     BRIGHT_THRESHOLD = 1900;
const unsigned long OCCUPIED_HOLD_MS = 15000;
const unsigned long LONG_PRESS_MS    = 2000;
const unsigned long DEBOUNCE_MS      = 30;

#define PIN_DHT        4
#define PIN_SDA        21
#define PIN_SCL        22
#define PIN_LDR        34
#define PIN_LIGHT_BTN  32
#define PIN_FAN_BTN    33
#define PIN_RELAY_FAN  26
#define PIN_RELAY_LIGHT 25
#define PIN_PIR        13

#define DHTTYPE DHT11
DHT dht(PIN_DHT, DHTTYPE);

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_ADDR 0x3C
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

WebServer server(80);

enum Mode { AUTO, MANUAL };

bool fanState = false;
bool lightState = false;
Mode fanMode = AUTO;
Mode lightMode = AUTO;

float temperature = NAN;
float humidity = NAN;
int   ldrValue = 0;
bool  occupied = false;
unsigned long lastMotionMs = 0;

unsigned long lastDhtReadMs = 0;
const unsigned long DHT_INTERVAL_MS = 2500;

bool lightRawLast = HIGH, fanRawLast = HIGH;
bool lightBtnLast = HIGH, fanBtnLast = HIGH;
unsigned long lightDebounceMs = 0, fanDebounceMs = 0;
unsigned long lightBtnDownMs = 0, fanBtnDownMs = 0;
bool lightLongHandled = false, fanLongHandled = false;
bool lightPrevStable = HIGH, fanPrevStable = HIGH;

void setFan(bool on) {
  fanState = on;
  digitalWrite(PIN_RELAY_FAN, on ? HIGH : LOW);   // ACTIVE-HIGH
}

void setLight(bool on) {
  lightState = on;
  digitalWrite(PIN_RELAY_LIGHT, on ? HIGH : LOW); // ACTIVE-HIGH
}

bool debouncedRead(int pin, bool &rawLast, unsigned long &debounceMs, bool &stableState) {
  bool raw = digitalRead(pin);
  if (raw != rawLast) debounceMs = millis();
  if (millis() - debounceMs > DEBOUNCE_MS) stableState = raw;
  rawLast = raw;
  return stableState;
}

void handleButton(bool reading, bool &lastState, unsigned long &downMs, bool &longHandled,
                   Mode &mode, bool &state, void (*setter)(bool)) {
  if (lastState == HIGH && reading == LOW) {
    downMs = millis();
    longHandled = false;
  }
  if (reading == LOW && !longHandled && (millis() - downMs > LONG_PRESS_MS)) {
    mode = AUTO;
    longHandled = true;
  }
  if (lastState == LOW && reading == HIGH) {
    unsigned long heldFor = millis() - downMs;
    if (heldFor < LONG_PRESS_MS) {
      mode = MANUAL;
      state = !state;
      setter(state);
    }
  }
  lastState = reading;
}

void readSensors() {
  if (digitalRead(PIN_PIR) == HIGH) lastMotionMs = millis();
  occupied = (millis() - lastMotionMs) < OCCUPIED_HOLD_MS;

  ldrValue = analogRead(PIN_LDR);

  if (millis() - lastDhtReadMs > DHT_INTERVAL_MS) {
    float h = dht.readHumidity();
    float t = dht.readTemperature();
    if (!isnan(h) && !isnan(t)) { humidity = h; temperature = t; }
    lastDhtReadMs = millis();
  }
}

void runAutoLogic() {
  if (fanMode == AUTO) {
    if (!occupied) {
      if (fanState) setFan(false);
    } else if (!isnan(temperature)) {
      if (!fanState && temperature > TEMP_ON_C) setFan(true);
      else if (fanState && temperature < TEMP_OFF_C) setFan(false);
    }
  }

  if (lightMode == AUTO) {
    if (!occupied) {
      if (lightState) setLight(false);
    } else {
      if (!lightState && ldrValue < DARK_THRESHOLD) setLight(true);
      else if (lightState && ldrValue > BRIGHT_THRESHOLD) setLight(false);
    }
  }
}

void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 0);
  display.print("Room: ");
  display.println(occupied ? "OCCUPIED" : "EMPTY");

  display.setCursor(0, 12);
  if (isnan(temperature)) display.println("Temp: --.- C");
  else { display.print("Temp: "); display.print(temperature, 1); display.println(" C"); }

  display.setCursor(0, 24);
  if (isnan(humidity)) display.println("Hum:  --.- %");
  else { display.print("Hum:  "); display.print(humidity, 1); display.println(" %"); }

  display.setCursor(0, 36);
  display.print("Light lvl: ");
  display.println(ldrValue);

  display.setCursor(0, 48);
  display.print("FAN:");
  display.print(fanState ? "ON " : "OFF");
  display.print(fanMode == AUTO ? "(A) " : "(M) ");
  display.print("LIGHT:");
  display.print(lightState ? "ON " : "OFF");
  display.print(lightMode == AUTO ? "(A)" : "(M)");

  display.setCursor(0, 56);
  display.print("AP: ");
  display.println(WiFi.softAPIP());

  display.display();
}

String modeStr(Mode m) { return m == AUTO ? "auto" : "manual"; }

void handleSetFan() {
  if (server.hasArg("state")) {
    String s = server.arg("state");
    if (s == "on")  { fanMode = MANUAL; setFan(true); }
    else if (s == "off") { fanMode = MANUAL; setFan(false); }
    else if (s == "auto") { fanMode = AUTO; }
  }
  server.sendHeader("Location", "/");
  server.send(303);
}

void handleSetLight() {
  if (server.hasArg("state")) {
    String s = server.arg("state");
    if (s == "on")  { lightMode = MANUAL; setLight(true); }
    else if (s == "off") { lightMode = MANUAL; setLight(false); }
    else if (s == "auto") { lightMode = AUTO; }
  }
  server.sendHeader("Location", "/");
  server.send(303);
}

void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<meta http-equiv='refresh' content='5'>";
  html += "<title>Smart Office</title><style>";
  html += "body{font-family:sans-serif;max-width:420px;margin:20px auto;padding:0 12px}";
  html += ".card{border:1px solid #ccc;border-radius:10px;padding:12px;margin:10px 0}";
  html += ".btn{display:inline-block;padding:8px 14px;margin:4px 4px 0 0;border-radius:6px;";
  html += "background:#eee;text-decoration:none;color:#000;border:1px solid #bbb}";
  html += ".on{background:#c8f7c5}.off{background:#f7c5c5}.auto{background:#c5d8f7}";
  html += "</style></head><body>";
  html += "<h2>Smart Office Automation</h2>";

  html += "<div class='card'><b>Room:</b> " + String(occupied ? "OCCUPIED" : "EMPTY") + "<br>";
  html += "<b>Temperature:</b> " + (isnan(temperature) ? String("--") : String(temperature, 1)) + " &deg;C<br>";
  html += "<b>Humidity:</b> " + (isnan(humidity) ? String("--") : String(humidity, 1)) + " %<br>";
  html += "<b>Light level (raw ADC):</b> " + String(ldrValue) + "</div>";

  html += "<div class='card'><b>Fan</b> - " + String(fanState ? "ON" : "OFF") + " (" + modeStr(fanMode) + ")<br>";
  html += "<a class='btn on' href='/fan?state=on'>ON</a>";
  html += "<a class='btn off' href='/fan?state=off'>OFF</a>";
  html += "<a class='btn auto' href='/fan?state=auto'>AUTO</a></div>";

  html += "<div class='card'><b>Light</b> - " + String(lightState ? "ON" : "OFF") + " (" + modeStr(lightMode) + ")<br>";
  html += "<a class='btn on' href='/light?state=on'>ON</a>";
  html += "<a class='btn off' href='/light?state=off'>OFF</a>";
  html += "<a class='btn auto' href='/light?state=auto'>AUTO</a></div>";

  html += "</body></html>";
  server.send(200, "text/html", html);
}

void setup() {
  Serial.begin(115200);

  pinMode(PIN_LIGHT_BTN, INPUT_PULLUP);
  pinMode(PIN_FAN_BTN, INPUT_PULLUP);
  pinMode(PIN_PIR, INPUT);
  pinMode(PIN_RELAY_FAN, OUTPUT);
  pinMode(PIN_RELAY_LIGHT, OUTPUT);
  setFan(false);
  setLight(false);

  dht.begin();
  delay(1500);
  humidity = dht.readHumidity();
  temperature = dht.readTemperature();

  Wire.begin(PIN_SDA, PIN_SCL);
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    Serial.println("OLED init failed - check wiring/address");
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 20);
  display.println("Starting up...");
  display.display();

  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.println("Access Point started.");
  Serial.println("SSID: " + String(AP_SSID));
  Serial.println("IP:   " + WiFi.softAPIP().toString());

  server.on("/", handleRoot);
  server.on("/fan", handleSetFan);
  server.on("/light", handleSetLight);
  server.begin();
}

void loop() {
  readSensors();

  bool lightReading = debouncedRead(PIN_LIGHT_BTN, lightRawLast, lightDebounceMs, lightBtnLast);
  bool fanReading   = debouncedRead(PIN_FAN_BTN, fanRawLast, fanDebounceMs, fanBtnLast);

  handleButton(lightReading, lightPrevStable, lightBtnDownMs, lightLongHandled, lightMode, lightState, setLight);
  handleButton(fanReading, fanPrevStable, fanBtnDownMs, fanLongHandled, fanMode, fanState, setFan);

  runAutoLogic();
  updateDisplay();

  server.handleClient();

  delay(50);
}
