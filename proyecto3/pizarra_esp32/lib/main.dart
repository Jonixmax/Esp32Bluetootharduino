import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MatrizBLEApp());
}

class MatrizBLEApp extends StatelessWidget {
  const MatrizBLEApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matriz ESP32',
      theme: ThemeData(
        brightness: Brightness.dark, // Tema oscuro para resaltar los "LEDs"
        primarySwatch: Colors.red,
      ),
      home: const PantallaMatriz(),
    );
  }
}

class PantallaMatriz extends StatefulWidget {
  const PantallaMatriz({Key? key}) : super(key: key);

  @override
  State<PantallaMatriz> createState() => _PantallaMatrizState();
}

class _PantallaMatrizState extends State<PantallaMatriz> {
  BluetoothDevice? dispositivoESP32;
  BluetoothCharacteristic? caracteristicaControl;
  
  bool conectado = false;
  bool buscando = false;

  // Estado de los 64 LEDs (Falso = Apagado, Verdadero = Encendido)
  // Es una matriz de 8 filas y 8 columnas
  List<List<bool>> matrizLeds = List.generate(8, (_) => List.generate(8, (_) => false));

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _pedirPermisos();
  }

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
        // Buscamos el nombre configurado en el código de la matriz
        if (r.device.advName == "ESP32_MATRIZ") {
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

  void _enviarComando(String comando) {
    if (conectado && caracteristicaControl != null) {
      List<int> bytes = utf8.encode(comando);
      caracteristicaControl!.write(bytes, withoutResponse: true);
    }
  }

  // --- ACCIONES DE LOS BOTONES ---

  void _tocarLed(int fila, int columna) {
    setState(() {
      matrizLeds[fila][columna] = !matrizLeds[fila][columna];
    });
    
    int estado = matrizLeds[fila][columna] ? 1 : 0;
    // Envía: P,columna,fila,estado
    _enviarComando("P,$columna,$fila,$estado\n");
  }

  void _limpiarMatriz() {
    setState(() {
      matrizLeds = List.generate(8, (_) => List.generate(8, (_) => false));
    });
    _enviarComando("C\n");
  }

  void _dibujarCorazon() {
    // Dibujo del corazón en binario para actualizar la pantalla del celular
    List<String> mapaCorazon = [
      '01100110',
      '11111111',
      '11111111',
      '11111111',
      '01111110',
      '00111100',
      '00011000',
      '00000000'
    ];

    setState(() {
      for (int f = 0; f < 8; f++) {
        for (int c = 0; c < 8; c++) {
          matrizLeds[f][c] = mapaCorazon[f][c] == '1';
        }
      }
    });
    _enviarComando("H\n");
  }

  // --- INTERFAZ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(conectado ? 'Matriz Conectada' : (buscando ? 'Buscando...' : 'Desconectado')),
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: conectado
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cuadrícula 8x8
                  Container(
                    width: 320, // Tamaño fijo para mantener la proporción cuadrada
                    height: 320,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade800, width: 4),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), // Desactiva el scroll interior
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: 64,
                      itemBuilder: (context, index) {
                        int fila = index ~/ 8;
                        int columna = index % 8;
                        bool encendido = matrizLeds[fila][columna];

                        return GestureDetector(
                          onTap: () => _tocarLed(fila, columna),
                          child: Container(
                            decoration: BoxDecoration(
                              color: encendido ? Colors.red : Colors.grey.shade900,
                              shape: BoxShape.circle,
                              boxShadow: encendido
                                  ? [const BoxShadow(color: Colors.redAccent, blurRadius: 4, spreadRadius: 1)]
                                  : [],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Botones rápidos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text("Borrar"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        onPressed: _limpiarMatriz,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.favorite, color: Colors.white),
                        label: const Text("Corazón"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        onPressed: _dibujarCorazon,
                      ),
                    ],
                  )
                ],
              )
            : buscando
                ? const CircularProgressIndicator(color: Colors.redAccent)
                : ElevatedButton(
                    onPressed: _iniciarEscaneo,
                    child: const Text("Conectar a la Matriz"),
                  ),
      ),
    );
  }
}