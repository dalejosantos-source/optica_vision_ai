import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error detectando cámaras: $e');
  }
  runApp(const OpticaVisionApp());
}

class OpticaVisionApp extends StatelessWidget {
  const OpticaVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Óptica Vision AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF00B4D8),
        scaffoldBackgroundColor: const Color(0xFF0D131A),
      ),
      home: const EyewearClassifierScreen(),
    );
  }
}

class OpticalRecommendation {
  final String categoryTitle;
  final String summary;
  final List<String> idealFaceShapes;
  final String frameStyle;
  final List<CatalogItem> catalogSuggestions;

  const OpticalRecommendation({
    required this.categoryTitle,
    required this.summary,
    required this.idealFaceShapes,
    required this.frameStyle,
    required this.catalogSuggestions,
  });
}

class CatalogItem {
  final String modelName;
  final String material;
  final String lensSpec;
  final String priceRef;

  const CatalogItem({
    required this.modelName,
    required this.material,
    required this.lensSpec,
    required this.priceRef,
  });
}

class ClassificationPrediction {
  final String label;
  final double confidence;

  const ClassificationPrediction({
    required this.label,
    required this.confidence,
  });
}

class EyewearClassifierScreen extends StatefulWidget {
  const EyewearClassifierScreen({super.key});

  @override
  State<EyewearClassifierScreen> createState() =>
      _EyewearClassifierScreenState();
}

class _EyewearClassifierScreenState extends State<EyewearClassifierScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<String> _labels = [
    'Gafas redondas',
    'Gafas cuadradas',
    'Gafas aviador',
    'Gafas deportivas',
    'Gafas de sol',
  ];

  bool _isCameraInitialized = false;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  String? _statusMessage;
  String? _capturedImagePath;
  List<ClassificationPrediction> _predictions = [];

  final Map<String, OpticalRecommendation> _opticalDatabase = const {
    'Gafas redondas': OpticalRecommendation(
      categoryTitle: 'Gafas Redondas (Estilo Vintage / Intelectual)',
      summary:
          'Los aros curvos suavizan las facciones angulares y aportan equilibrio visual en la zona de los pómulos y la mandíbula.',
      idealFaceShapes: [
        'Rostro Cuadrado',
        'Rostro Rectangular',
        'Rostro Diamante',
        'Rostro Ovalado'
      ],
      frameStyle:
          'Montura circular de aro fino en titanio o pasta de acetato delgada con puente tipo llave.',
      catalogSuggestions: [
        CatalogItem(
          modelName: 'Havana Round Classic 48',
          material: 'Acetato Mazzucchelli Caret',
          lensSpec: 'Antirreflejo + Filtro Luz Azul',
          priceRef: 'Catálogo Ref. #RD-104',
        ),
        CatalogItem(
          modelName: 'Minimalist Titanium Orb',
          material: 'Titanio ultraligero (11g)',
          lensSpec: 'Policarbonato Asférico 1.67',
          priceRef: 'Catálogo Ref. #RD-209',
        ),
      ],
    ),
    'Gafas cuadradas': OpticalRecommendation(
      categoryTitle: 'Gafas Cuadradas (Estructura y Definición)',
      summary:
          'Las líneas rectas y ángulos marcados agregan estructura geométrica, estilizando rostros de contornos suaves o circulares.',
      idealFaceShapes: [
        'Rostro Redondo',
        'Rostro Ovalado',
        'Rostro Triángulo Invertido'
      ],
      frameStyle:
          'Marco geométrico de frente recto en acetato de alta densidad o combinación metal-acetato (Clubmaster/Wayfarer).',
      catalogSuggestions: [
        CatalogItem(
          modelName: 'Urban Executive Square 54',
          material: 'Acetato Negro Mate con bisagra flex',
          lensSpec: 'Monofocal Digital HD Antirreflejo',
          priceRef: 'Catálogo Ref. #SQ-310',
        ),
        CatalogItem(
          modelName: 'Architect Half-Rim',
          material: 'Acero inoxidable + Terminales TR90',
          lensSpec: 'Fotocromático Transitions Gen 8',
          priceRef: 'Catálogo Ref. #SQ-412',
        ),
      ],
    ),
    'Gafas aviador': OpticalRecommendation(
      categoryTitle: 'Gafas Aviador (Doble Puente / Gota)',
      summary:
          'Su icónica silueta en forma de lágrima y doble puente nasal ensancha visualmente la mitad superior del rostro y estiliza el mentón.',
      idealFaceShapes: [
        'Rostro Corazón',
        'Rostro Ovalado',
        'Rostro Cuadrado'
      ],
      frameStyle:
          'Armazón metálico delgado con doble puente superior y plaquetas de silicona ajustables para ergonomía nasal.',
      catalogSuggestions: [
        CatalogItem(
          modelName: 'AeroPilot Gold Optical',
          material: 'Aleación Monel Dorada / Plata',
          lensSpec: 'Lente Oftálmico Antirreflejo Esmeralda',
          priceRef: 'Catálogo Ref. #AV-501',
        ),
        CatalogItem(
          modelName: 'Navigator Carbon Edition',
          material: 'Fibra de carbono y acero quirúrgico',
          lensSpec: 'Lente Progresivo Digital FreeForm',
          priceRef: 'Catálogo Ref. #AV-588',
        ),
      ],
    ),
    'Gafas deportivas': OpticalRecommendation(
      categoryTitle: 'Gafas Deportivas (Envolventes / Alto Rendimiento)',
      summary:
          'Diseño aerodinámico de curvatura base 8 que ofrece cobertura periférica total, sujeción antideslizante y resistencia a impactos.',
      idealFaceShapes: [
        'Adaptable a todo tipo de rostro',
        'Ajuste ergonómico craneal de 3 puntos'
      ],
      frameStyle:
          'Montura envolvente en polímero con memoria TR90 y terminales engomados hidrofílicos.',
      catalogSuggestions: [
        CatalogItem(
          modelName: 'Veloce Pro Cycling Shield',
          material: 'Grilamid TR90 Ultraflexible',
          lensSpec: 'Policarbonato Fotocromático + Ventilas Antiempañante',
          priceRef: 'Catálogo Ref. #SP-702',
        ),
        CatalogItem(
          modelName: 'TrailRunner Impact RX',
          material: 'Polímero balístico con clip óptico interno',
          lensSpec: 'Espejado Revo UV400 Alto Contraste',
          priceRef: 'Catálogo Ref. #SP-745',
        ),
      ],
    ),
    'Gafas de sol': OpticalRecommendation(
      categoryTitle: 'Gafas de Sol (Protección UV400 y Confort Visual)',
      summary:
          'Equipadas con lentes tintados o polarizados que bloquean el 100% de la radiación UVA/UVB y eliminan el deslumbramiento horizontal.',
      idealFaceShapes: [
        'Rostro Ovalado',
        'Rostro Redondo',
        'Rostro Cuadrado',
        'Rostro Corazón'
      ],
      frameStyle:
          'Monturas de calibre amplio (52mm - 58mm) en acetato pulido o metal con filtros solares categoría 3.',
      catalogSuggestions: [
        CatalogItem(
          modelName: 'Solaris Polarized Classic',
          material: 'Acetato Tortoise con alma metálica',
          lensSpec: 'Polarizado Categoría 3 + Filtro UV400',
          priceRef: 'Catálogo Ref. #SN-901',
        ),
        CatalogItem(
          modelName: 'Riviera Gradient Sun',
          material: 'Bio-Acetato + Herrajes dorados',
          lensSpec: 'Degradado Gris/Ámbar con Antirreflejo Interno',
          priceRef: 'Catálogo Ref. #SN-934',
        ),
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initializeSystem() async {
    await Future.wait([
      _loadModelAndLabels(),
      _initCamera(),
    ]);
  }

  Future<void> _loadModelAndLabels() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/modelo_gafas.tflite',
        options: options,
      );

      final rawLabels = await rootBundle.loadString('assets/labels.txt');
      final parsedLabels = rawLabels
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (parsedLabels.length == 5) {
        _labels = parsedLabels;
      }

      if (mounted) {
        setState(() {
          _isModelLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'Error cargando modelo o etiquetas en assets/: $e';
        });
      }
    }
  }

  Future<void> _initCamera() async {
    if (_cameras.isEmpty) {
      setState(() {
        _statusMessage = 'No se detectó ninguna cámara en el dispositivo.';
      });
      return;
    }

    final CameraDescription selectedCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Permiso de cámara pendiente o error: $e';
        });
      }
    }
  }

  Future<void> _captureAndClassify() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    if (!_isModelLoaded || _interpreter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El modelo TFLite aún no está cargado.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await File(photo.path).readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception('No se pudo decodificar la fotografía.');
      }

      final img.Image orientedImage = img.bakeOrientation(decodedImage);
      final int cropSize = orientedImage.width < orientedImage.height
          ? orientedImage.width
          : orientedImage.height;
      final int offsetX = (orientedImage.width - cropSize) ~/ 2;
      final int offsetY = (orientedImage.height - cropSize) ~/ 2;

      final img.Image croppedImage = img.copyCrop(
        orientedImage,
        x: offsetX,
        y: offsetY,
        width: cropSize,
        height: cropSize,
      );

      final img.Image resizedImage = img.copyResize(
        croppedImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      final inputTensor = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              return <double>[
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final outputTensor = List.generate(1, (_) => List<double>.filled(5, 0.0));

      _interpreter!.run(inputTensor, outputTensor);

      final List<double> probabilities = List<double>.from(outputTensor[0]);
      final List<ClassificationPrediction> results = [];

      for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
        results.add(
          ClassificationPrediction(
            label: _labels[i],
            confidence: probabilities[i],
          ),
        );
      }

      results.sort((a, b) => b.confidence.compareTo(a.confidence));

      if (mounted) {
        setState(() {
          _capturedImagePath = photo.path;
          _predictions = results;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error procesando la imagen: $e';
        });
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _capturedImagePath = null;
      _predictions = [];
      _statusMessage = null;
    });
  }

  OpticalRecommendation _getRecommendationForLabel(String rawLabel) {
    final normalized = rawLabel.trim().toLowerCase();
    for (final entry in _opticalDatabase.entries) {
      if (entry.key.toLowerCase() == normalized) {
        return entry.value;
      }
    }
    if (normalized.contains('redonda')) {
      return _opticalDatabase['Gafas redondas']!;
    } else if (normalized.contains('cuadrada')) {
      return _opticalDatabase['Gafas cuadradas']!;
    } else if (normalized.contains('aviador')) {
      return _opticalDatabase['Gafas aviador']!;
    } else if (normalized.contains('deportiva')) {
      return _opticalDatabase['Gafas deportivas']!;
    }
    return _opticalDatabase['Gafas de sol']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              flex: _predictions.isEmpty ? 7 : 4,
              child: _buildCameraOrPhotoViewport(),
            ),
            Expanded(
              flex: _predictions.isEmpty ? 3 : 6,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121A24),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2D3D), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              color: Color(0xFF00B4D8),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Óptica Vision AI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Clasificador de Monturas & Catálogo Inteligente',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isModelLoaded
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isModelLoaded ? Colors.greenAccent : Colors.orangeAccent,
                width: 1,
              ),
            ),
            child: Text(
              _isModelLoaded ? 'TFLite Offline' : 'Cargando IA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isModelLoaded ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraOrPhotoViewport() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_capturedImagePath != null)
          Image.file(
            File(_capturedImagePath!),
            fit: BoxFit.cover,
          )
        else if (_isCameraInitialized && _cameraController != null)
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00B4D8)),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage ?? 'Inicializando visor de cámara...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        if (_capturedImagePath == null && _isCameraInitialized)
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF00B4D8).withOpacity(0.85),
                  width: 2.2,
                ),
                borderRadius: BorderRadius.circular(18),
                color: Colors.black.withOpacity(0.12),
              ),
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Centra las gafas dentro del recuadro',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_capturedImagePath != null)
          Positioned(
            top: 12,
            right: 12,
            child: ElevatedButton.icon(
              onPressed: _resetScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.cameraswitch_outlined, size: 18),
              label: const Text('Nueva captura'),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    if (_statusMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _statusMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    if (_predictions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: const BoxDecoration(
          color: Color(0xFF121A24),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enfoca la montura con buena iluminación frontal y presiona el botón para analizar su geometría.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _captureAndClassify,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded),
                label: Text(
                  _isProcessing
                      ? 'Procesando Tensor 224x224...'
                      : 'Capturar y Clasificar Montura',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ClassificationPrediction topResult = _predictions.first;
    final OpticalRecommendation recommendation =
        _getRecommendationForLabel(topResult.label);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121A24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MONTURA DETECTADA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        topResult.label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(topResult.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Distribución de Confianza (5 Categorías)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ..._predictions.map((pred) {
            final double pct = (pred.confidence * 100).clamp(0.0, 100.0);
            final bool isTop = pred == topResult;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pred.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                          color: isTop ? const Color(0xFF90E0EF) : Colors.white70,
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                          color: isTop ? const Color(0xFF90E0EF) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pred.confidence.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: const Color(0xFF1E2D3D),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTop ? const Color(0xFF00B4D8) : Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF192432),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF283B52)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF90E0EF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation.categoryTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF90E0EF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recommendation.summary,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tipos de Rostro Recomendados:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: recommendation.idealFaceShapes
                      .map(
                        (shape) => Chip(
                          label: Text(
                            shape,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: const Color(0xFF0D131A),
                          side: const BorderSide(color: Color(0xFF00B4D8)),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Especificación de Montura: ${recommendation.frameStyle}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Sugerencias del Catálogo de Óptica:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ...recommendation.catalogSuggestions.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101720),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.remove_red_eye_outlined,
                          color: Color(0xFF00B4D8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.modelName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${item.material} • ${item.lensSpec}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                item.priceRef,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF90E0EF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}