import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const TamagotchiApp());
}

class TamagotchiApp extends StatelessWidget {
  const TamagotchiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tamagotchi ESP32',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({Key? key}) : super(key: key);

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  BluetoothDevice? dispositivoESP32;
  BluetoothCharacteristic? caracteristicaControl;
  
  bool conectado = false;
  bool buscando = false;
  DateTime tiempoUltimaSacudida = DateTime.now();

  // UUIDs exactos de tu ESP32
  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _pedirPermisos();
    _escucharSacudidas(); // Iniciamos el sensor de movimiento
  }

  // --- 1. LÓGICA DEL ACELERÓMETRO (SACUDIDAS) ---
  void _escucharSacudidas() {
    // userAccelerometerEventStream ignora la gravedad, solo lee el movimiento de tu mano
    userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      // Calculamos la fuerza total del movimiento usando el Teorema de Pitágoras
      double fuerza = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Si la fuerza es mayor a 15 (sacudida fuerte)
      if (fuerza > 15.0) {
        // Verificamos que hayan pasado al menos 3 segundos desde la última vez
        if (DateTime.now().difference(tiempoUltimaSacudida).inSeconds >= 3) {
          tiempoUltimaSacudida = DateTime.now();
          print("¡Sacudida detectada!");
          _marearESP32();
        }
      }
    });
  }

  void _marearESP32() {
    if (conectado && caracteristicaControl != null) {
      List<int> bytes = utf8.encode("M\n"); // Enviamos la M de Mareo
      caracteristicaControl!.write(bytes, withoutResponse: true);
    }
  }

  // --- 2. LÓGICA DE BLUETOOTH ---
  Future<void> _pedirPermisos() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    _iniciarEscaneo();
  }

  void _iniciarEscaneo() {
    setState(() => buscando = true);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Buscamos el nuevo nombre que le pusimos al código de la carita
        if (r.device.advName == "ESP32_CARITA") {
          FlutterBluePlus.stopScan();
          _conectar(r.device);
          break;
        }
      }
    });
  }

  Future<void> _conectar(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      dispositivoESP32 = device;
      conectado = true;
      buscando = false;
    });

    List<BluetoothService> servicios = await device.discoverServices();
    for (BluetoothService s in servicios) {
      if (s.uuid.toString() == serviceUuid) {
        for (BluetoothCharacteristic c in s.characteristics) {
          if (c.uuid.toString() == charUuid) {
            caracteristicaControl = c;
            break;
          }
        }
      }
    }
  }

  // --- 3. INTERFAZ GRÁFICA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tamagotchi ESP32'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: conectado
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.vibration, size: 100, color: Colors.deepPurple),
                  SizedBox(height: 20),
                  Text(
                    "¡Conectado!\nAgita tu celular fuerte\npara marearlo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : buscando
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text("Buscando a ESP32_CARITA..."),
                    ],
                  )
                : ElevatedButton(
                    onPressed: _iniciarEscaneo,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
                    child: const Text("Buscar de nuevo", style: TextStyle(fontSize: 20)),
                  ),
      ),
    );
  }
}