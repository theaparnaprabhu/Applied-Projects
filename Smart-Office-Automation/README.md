# Smart Office Automation PCB

A custom ESP32-based PCB that automates office environment control — lighting, temperature 
monitoring, and occupancy detection — with a web dashboard for real-time monitoring and control.

## Features

- **Occupancy Detection** — Automatically detects when the office is in use (e.g. via PIR/motion sensor)
- **Lighting Control** — Automatically switches lighting based on occupancy and/or ambient light levels using LDR
- **Temperature Monitoring** — Reads and logs ambient temperature in real time using DHT11 sensor
- **Web Dashboard** — Live monitoring and manual override via a browser-based interface
- **ESP32-Powered** — Wi-Fi enabled, no external gateway or hub required

## Hardware

| Component | Details |
|---|---|
| MCU | ESP32 |
| Sensors | Temperature sensor, occupancy/PIR sensor |
| Actuators | Relay/MOSFET-driven lighting output |
| PCB Design Tool | KiCad |

## Firmware

Written in C/C++ using the Arduino/ESP-IDF framework. Handles:
- Sensor polling (temperature, occupancy)
- Lighting control logic
- Wi-Fi connectivity and web server hosting for the dashboard


## Web Dashboard

The ESP32 hosts a lightweight web dashboard accessible over the local network, showing:
- Current temperature
- Occupancy status (occupied / vacant)
- Lighting state (on/off, and manual override toggle)


## Getting Started

### Hardware Setup
1. Fabricate the PCB using the files provided
2. Solder components per the BOM
3. Power the board via [power source]

### Accessing the Dashboard
1. After flashing and powering on, the ESP32 starts broadcasting a Wi-Fi network
2. On your phone or laptop, connect to this Wi-Fi network
3. Open a browser and navigate to the ESP32's AP IP address (default: `192.168.4.1`)
4. The dashboard loads, showing live sensor data and controls
5. Options for Auto mode and Manual mode are provided in the dashboard for efficient functioning
