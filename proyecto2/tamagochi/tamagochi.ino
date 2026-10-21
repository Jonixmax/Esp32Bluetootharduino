#include <Wire.h>
#include <Adafruit_SSD1306.h>
#include <BLEDevice.h>
#include <BLEServer.h>

Adafruit_SSD1306 oled(128, 64, &Wire, -1);
bool mareado = false;
unsigned long t_mareo = 0;

class escuchar_ble : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) {
    if (c->getValue().c_str()[0] == 'M') { mareado = true; t_mareo = millis(); }
  }
};

// Función única que dibuja la cara según el número (0=Normal, 1=Lentes, 2=Dormido, 3=Mareado)
void dibujar(int cara) {
  oled.clearDisplay();
  oled.drawCircle(64, 32, 28, 1); // Cabeza base
  
  if (cara == 3) { 
// Ojos hipnotizados (Círculos concéntricos)
    oled.drawCircle(54, 25, 6, 1); oled.drawCircle(54, 25, 3, 1); oled.drawPixel(54, 25, 1);
    oled.drawCircle(74, 25, 6, 1); oled.drawCircle(74, 25, 3, 1); oled.drawPixel(74, 25, 1);
    oled.drawLine(54,40,60,44,1); oled.drawLine(60,44,68,38,1); oled.drawLine(68,38,74,42,1); // Boca chueca
  } else if (cara == 2) { 
    oled.drawFastHLine(50,26,8,1); oled.drawFastHLine(70,26,8,1); // Ojos cerrados
    oled.drawCircle(64,42,3,1); oled.setCursor(95,10); oled.print("Zzz"); // Boca y texto
  } else if (cara == 1) { 
    oled.fillRect(48,20,14,10,1); oled.fillRect(66,20,14,10,1); oled.drawFastHLine(62,22,4,1); // Lentes
    oled.drawFastHLine(58,42,12,1); // Sonrisa cool
  } else { 
    oled.fillCircle(54,25,4,1); oled.fillCircle(74,25,4,1); // Ojos normales
    oled.drawFastHLine(56,42,16,1); // Sonrisa
  }
  oled.display();
}

void setup() {
  pinMode(34, INPUT); pinMode(25, OUTPUT);
  Wire.begin(); Wire.setClock(400000);
  oled.begin(SSD1306_SWITCHCAPVCC, 0x3C); oled.setTextColor(1);

  BLEDevice::init("ESP32_CARITA");
  BLEServer *pSrv = BLEDevice::createServer();
  BLEService *pSvc = pSrv->createService("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  BLECharacteristic *pChr = pSvc->createCharacteristic(
    "beb5483e-36e1-4688-b7f5-ea07361b26a8", BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  pChr->setCallbacks(new escuchar_ble());
  pSvc->start(); pSrv->getAdvertising()->start();
}

void loop() {
  if (mareado) {
    dibujar(3);
    tone(25, random(500, 1500), 50); // Sonido errático
    if (millis() - t_mareo > 3000) mareado = false;
  } else {
    int luz = analogRead(34);
    // Operador ternario: si luz > 2500 manda 1 (lentes), si es < 800 manda 2 (dormido), si no manda 0 (normal)
    dibujar(luz > 2500 ? 1 : (luz < 800 ? 2 : 0));
  }
  delay(100);
}