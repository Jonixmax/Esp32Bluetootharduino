#include <LedControl.h>
#include <BLEDevice.h>
#include <BLEServer.h>

// Pines de la matriz: DIN(23), CLK(18), CS(5)
LedControl matriz = LedControl(23, 18, 5, 1);
const int pinBuzzer = 25; // Pin positivo del buzzer

// Dibujo del corazón
byte corazon[8] = {
  B01100110, B11111111, B11111111, B11111111,
  B01111110, B00111100, B00011000, B00000000
};

class escuchar_ble : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) {
    String msg = c->getValue().c_str();
    char cmd; int x, y, estado;
    
    // Suena un pequeño "Click" de confirmación por 30 milisegundos
    tone(pinBuzzer, 2000, 30); 

    if (msg[0] == 'C') {
      matriz.clearDisplay(0);
    } 
    else if (msg[0] == 'H') {
      for (int i = 0; i < 8; i++) matriz.setRow(0, i, corazon[i]);
    } 
    else if (sscanf(msg.c_str(), "%c,%d,%d,%d", &cmd, &x, &y, &estado) == 4) {
      if (cmd == 'P') matriz.setLed(0, y, x, estado == 1);
    }
  }
};

void setup() {
  pinMode(pinBuzzer, OUTPUT);

  // Configurar matriz
  matriz.shutdown(0, false);
  matriz.setIntensity(0, 5); // Brillo (0-15)
  matriz.clearDisplay(0);

  // Configurar Bluetooth
  BLEDevice::init("ESP32_MATRIZ");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  BLECharacteristic *pChar = pService->createCharacteristic(
    "beb5483e-36e1-4688-b7f5-ea07361b26a8", 
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  pChar->setCallbacks(new escuchar_ble());
  pService->start();
  pServer->getAdvertising()->start();
}

void loop() {
  delay(10);
}