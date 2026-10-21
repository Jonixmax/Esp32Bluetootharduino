#include <Wire.h>
#include <Adafruit_SSD1306.h>
#include <BLEDevice.h>
#include <BLEServer.h>

// --- CONFIGURACIÓN DE PINES Y CONSTANTES ---
#define LED_TRAZO    32  // LED que parpadea rápido al recibir coordenadas
#define LED_BORRADO  33  // LED que se enciende medio segundo al borrar todo
// UUIDs únicos para la conexión Bluetooth (Servicio y Característica)
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Inicialización de la pantalla OLED (Resolución 128x64, usando I2C)
Adafruit_SSD1306 display(128, 64, &Wire, -1);

// --- VARIABLES GLOBALES ---
int prevX = -1, prevY = -1;             // Guardan la última posición del dedo en la app
unsigned long tTrazo = 0, tBorrado = 0; // Temporizadores para apagar los LEDs sin usar delay()

// 'volatile' indica al compilador que esta variable cambia dentro de una interrupción/callback
volatile bool actualizarPantalla = false;

// --- CLASE PARA MANEJAR LA RECEPCIÓN BLUETOOTH ---
class EscucharBLE : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    String msg = c->getValue().c_str(); // Extraer el texto recibido desde el celular
    char cmd; int x, y;

    // Comando 'C' (Clear): Limpiar la pantalla
    if (msg[0] == 'C') {
      display.clearDisplay();
      digitalWrite(LED_BORRADO, HIGH); // Encender el LED indicador de borrado
      tBorrado = millis();             // Registrar el momento exacto en que se encendió
    }
    // Comandos 'S' (Start) o 'D' (Draw): Recibir coordenadas
    // sscanf extrae el formato "Letra,X,Y" y verifica que leyó correctamente los 3 datos
    else if (sscanf(msg.c_str(), "%c,%d,%d", &cmd, &x, &y) == 3 && (cmd == 'S' || cmd == 'D')) {
      
      if (cmd == 'S') { 
        // Si es un trazo nuevo ('S'), igualamos el punto anterior al actual (dibuja un punto inicial)
        prevX = x; prevY = y; 
      }  
      
      // Dibujar la línea en la memoria de la pantalla desde el punto anterior al nuevo
      display.drawLine(prevX, prevY, x, y, SSD1306_WHITE);
      
      // Guardar las coordenadas actuales para que sean el "punto anterior" del siguiente paquete
      prevX = x; prevY = y;
      
      digitalWrite(LED_TRAZO, HIGH); // Encender el LED indicador de recepción de datos
      tTrazo = millis();             // Registrar el momento exacto en que se encendió
    }
    else return;  // Si recibimos basura o un mensaje no válido, salimos inmediatamente

    // Avisarle a la función loop() que hay información nueva lista para ser mostrada
    actualizarPantalla = true;  
  }
};

// --- CONFIGURACIÓN INICIAL ---
void setup() {
  
  pinMode(LED_TRAZO, OUTPUT);
  pinMode(LED_BORRADO, OUTPUT);
  Wire.begin();
  Wire.setClock(400000); 

  
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();
  display.display();

  // --- LEVANTAR EL SERVIDOR BLUETOOTH ---
  BLEDevice::init("ESP32_OLED_BLE"); // Nombre con el que aparecerá en el celular
  BLEService *servicio = BLEDevice::createServer()->createService(SERVICE_UUID);
  
  // Crear el "buzón" para recibir datos, permitiendo escritura con y sin respuesta
  BLECharacteristic *caract = servicio->createCharacteristic(
    CHAR_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);

  // Asignar nuestra clase para escuchar cada vez que llegue un mensaje al buzón
  caract->setCallbacks(new EscucharBLE());
  servicio->start();
  
  // Activar la señalización para que la app de Flutter pueda encontrar el ESP32
  BLEDevice::getAdvertising()->start();
}


void loop() {
  // 1. DIBUJO NO BLOQUEANTE: Solo enviamos datos a la pantalla si el Bluetooth recibió algo
  if (actualizarPantalla) {
    actualizarPantalla = false; // Reiniciar la bandera
    display.display();          // Plasmar los cambios de memoria en la pantalla física
  }
  
  // 2. TEMPORIZADORES DE LEDS: Apagar los LEDs cuando pase su tiempo límite
  // Así evitamos usar delay(), lo que causaría cortes o lentitud en el trazo de dibujo
  if (millis() - tTrazo   > 150) digitalWrite(LED_TRAZO, LOW);   // Apagar a los 150ms
  if (millis() - tBorrado > 500) digitalWrite(LED_BORRADO, LOW); // Apagar a los 500ms
  
  // Pequeño respiro para la estabilidad del procesador
  delay(10);
}