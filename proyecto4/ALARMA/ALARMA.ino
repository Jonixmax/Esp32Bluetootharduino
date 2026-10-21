#include <BLEDevice.h>
#include <BLEServer.h>

bool armado = true, alarma = false;
BLECharacteristic *cNotif;

class escuchar : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) {
    char letra = c->getValue().c_str()[0];
    if (letra == 'D') { armado = false; alarma = false; } // D = Desarmar
    if (letra == 'A') { armado = true; }                  // A = Armar
  }
};

void setup() {
  pinMode(27, INPUT); // Sensor PIR
  pinMode(25, OUTPUT); // Buzzer
  pinMode(32, OUTPUT); // LED Verde
  pinMode(33, OUTPUT); // LED Rojo

  BLEDevice::init("ESP32_ALARMA");
  BLEServer *srv = BLEDevice::createServer();
  BLEService *svc = srv->createService("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  
  // 1. Canal para escuchar al celular
  BLECharacteristic *cEscribir = svc->createCharacteristic("beb5483e-36e1-4688-b7f5-ea07361b26a8", BLECharacteristic::PROPERTY_WRITE);
  cEscribir->setCallbacks(new escuchar());

  // 2. Canal para enviarle alertas al celular
  cNotif = svc->createCharacteristic("1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e", BLECharacteristic::PROPERTY_NOTIFY);

  svc->start();
  srv->getAdvertising()->start();
}

void loop() {
  if (!armado) {
    // Apagado total
    digitalWrite(32, 0); digitalWrite(33, 0); noTone(25);
  } else {
    // Si detecta movimiento (PIR manda un 1 o HIGH)
    if (digitalRead(27) == 1 && !alarma) {
      alarma = true;
      cNotif->setValue("X"); // Manda una 'X' al celular
      cNotif->notify();
    }
    
    if (alarma) {
      // Modo pánico: Sirena y LED rojo parpadeando
      digitalWrite(32, 0); digitalWrite(33, 1); tone(25, 1000); delay(150);
      digitalWrite(33, 0); tone(25, 2000); delay(150);
    } else {
      // Modo vigilancia: Solo LED verde fijo
      digitalWrite(32, 1); digitalWrite(33, 0); noTone(25); delay(100);
    }
  }
}