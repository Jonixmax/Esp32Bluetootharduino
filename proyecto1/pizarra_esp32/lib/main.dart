import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui'; 

void main() {
  runApp(const PizarraBLEApp());
}

class PizarraBLEApp extends StatelessWidget {
  const PizarraBLEApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizarra ESP32',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PizarraScreen(),
    );
  }
}

class PizarraScreen extends StatefulWidget {
  const PizarraScreen({Key? key}) : super(key: key);

  @override
  State<PizarraScreen> createState() => _PizarraScreenState();
}

class _PizarraScreenState extends State<PizarraScreen> {
  BluetoothDevice? esp32Device;
  BluetoothCharacteristic? drawCharacteristic;
  bool isConnected = false;
  bool isScanning = false;

  // Lista para guardar los puntos y que no se borren de la pantalla del celular
  List<Offset?> _puntos = [];

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    _startScan();
  }

  void _startScan() {
    setState(() => isScanning = true);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.advName == "ESP32_OLED_BLE") {
          FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      esp32Device = device;
      isConnected = true;
      isScanning = false;
    });

    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == serviceUuid) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString() == charUuid) {
            drawCharacteristic = c;
            break;
          }
        }
      }
    }
  }

  void _sendCommand(String command) {
    if (drawCharacteristic != null) {
      List<int> bytes = utf8.encode(command);
      drawCharacteristic!.write(bytes, withoutResponse: true);
    }
  }

  void _limpiarPantalla() {
    setState(() {
      _puntos.clear(); // Borra el dibujo en el celular
    });
    _sendCommand("C\n"); // Borra el dibujo en la OLED
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    setState(() {
      _puntos.add(details.localPosition); 
    });
    int x = ((details.localPosition.dx / size.width) * 127).round();
    int y = ((details.localPosition.dy / size.height) * 63).round();
    _sendCommand("S,$x,$y\n");
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    setState(() {
      _puntos.add(details.localPosition); 
    });
    int x = ((details.localPosition.dx / size.width) * 127).round();
    int y = ((details.localPosition.dy / size.height) * 63).round();
    _sendCommand("D,$x,$y\n");
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _puntos.add(null); // Evita que se unan líneas separadas
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected ? 'Conectado a ESP32' : (isScanning ? 'Buscando...' : 'Desconectado')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _limpiarPantalla, 
          )
        ],
      ),
      body: isConnected
          ? LayoutBuilder(
              builder: (context, constraints) {
                Size canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (details) => _handlePanStart(details, canvasSize),
                  onPanUpdate: (details) => _handlePanUpdate(details, canvasSize),
                  onPanEnd: _handlePanEnd, 
                  child: Container(
                    color: Colors.black, 
                    width: double.infinity,
                    height: double.infinity,
                    // Aquí el lienzo usa la lista fresca para no borrar el dibujo
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: DibujoPainter(puntos: List.from(_puntos)),
                    ),
                  ),
                );
              },
            )
          : Center(
              child: isScanning
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _startScan,
                      child: const Text("Escanear de nuevo"),
                    ),
            ),
    );
  }
}

// ==========================================
// CLASE QUE DIBUJA LA LÍNEA BLANCA EN LA APP
// ==========================================
class DibujoPainter extends CustomPainter {
  List<Offset?> puntos;

  DibujoPainter({required this.puntos});

  @override
  void paint(Canvas canvas, Size size) {
    Paint lapiz = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (int i = 0; i < puntos.length - 1; i++) {
      if (puntos[i] != null && puntos[i + 1] != null) {
        canvas.drawLine(puntos[i]!, puntos[i + 1]!, lapiz);
      } else if (puntos[i] != null && puntos[i + 1] == null) {
        canvas.drawPoints(PointMode.points, [puntos[i]!], lapiz);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DibujoPainter oldDelegate) {
    return true; 
  }
}