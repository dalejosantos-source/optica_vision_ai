import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

List<CameraDescription> _availableCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    _availableCameras = await availableCameras();
  } catch (e) {
    debugPrint('Error detectando cámaras en ALJOLENS: $e');
  }
  runApp(const AljolensApp());
}

class AljolensApp extends StatelessWidget {
  const AljolensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALJOLENS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7EFE2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE86A33),
          primary: const Color(0xFFE86A33),
          secondary: const Color(0xFFF1A661),
          surface: const Color(0xFFFFFDF9),
        ),
      ),
      home: const AljolensStudioScreen(),
    );
  }
}

enum ScanUiState {
  initialScanning,
  rejectedFrame,
  discoverySuccess,
}

class PredictionItem {
  final String label;
  final double confidence;

  const PredictionItem({
    required this.label,
    required this.confidence,
  });
}

class CatalogPiece {
  final String name;
  final String materialAndLens;
  final String code;

  const CatalogPiece({
    required this.name,
    required this.materialAndLens,
    required this.code,
  });
}

class EyewearBentoProfile {
  final String displayTitle;
  final String editorialBadge;
  final String opticalAnalysis;
  final List<String> idealFaceShapes;
  final String structuralSpec;
  final Color cardAccent;
  final List<CatalogPiece> pieces;

  const EyewearBentoProfile({
    required this.displayTitle,
    required this.editorialBadge,
    required this.opticalAnalysis,
    required this.idealFaceShapes,
    required this.structuralSpec,
    required this.cardAccent,
    required this.pieces,
  });
}

class AljolensStudioScreen extends StatefulWidget {
  const AljolensStudioScreen({super.key});

  @override
  State<AljolensStudioScreen> createState() => _AljolensStudioScreenState();
}

class _AljolensStudioScreenState extends State<AljolensStudioScreen>
    with WidgetsBindingObserver {
  static const double _minConfidenceThreshold = 0.60;
  static const double _minDeltaMargin = 0.15;

  CameraController? _cameraController;
  Interpreter? _interpreter;

  List<String> _labels = [
    'Gafas redondas',
    'Gafas cuadradas',
    'Gafas aviador',
    'Gafas deportivas',
    'Gafas de sol',
    'Sin gafas / Fondo',
  ];

  bool _isCameraReady = false;
  bool _isModelReady = false;
  bool _isProcessing = false;
  String? _capturedImagePath;
  String _rejectionReason = '';
  ScanUiState _uiState = ScanUiState.initialScanning;
  List<PredictionItem> _predictions = [];

  final Map<String, EyewearBentoProfile> _atelierProfiles = const {
    'Gafas redondas': EyewearBentoProfile(
      displayTitle: 'Gafas Redondas',
      editorialBadge: 'COLECCIÓN INTELECTUAL & VINTAGE',
      opticalAnalysis:
          'Los aros orbitales curvos suavizan facciones angulares marcadas, equilibrando pómulos prominentes y líneas mandibulares rectas.',
      idealFaceShapes: [
        'Rostro Cuadrado',
        'Rostro Rectangular',
        'Rostro Diamante',
        'Rostro Ovalado',
      ],
      structuralSpec:
          'Aro circular continuo en titanio japonés ligero o pasta de acetato con puente tipo llave.',
      cardAccent: Color(0xFFE86A33),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Orb-48 Titanium',
          materialAndLens: 'Titanio Beta 10g • Antirreflejo + Filtro Azul',
          code: 'ATELIER #RD-104',
        ),
        CatalogPiece(
          name: 'Havana Panto Classic',
          materialAndLens: 'Acetato Mazzucchelli Caret • Lente Asférico 1.67',
          code: 'ATELIER #RD-209',
        ),
      ],
    ),
    'Gafas cuadradas': EyewearBentoProfile(
      displayTitle: 'Gafas Cuadradas',
      editorialBadge: 'ARQUITECTURA & DEFINICIÓN LINEAL',
      opticalAnalysis:
          'Sus ángulos definidos aportan estructura geométrica y carácter, estilizando contornos faciales suaves o circulares.',
      idealFaceShapes: [
        'Rostro Redondo',
        'Rostro Ovalado',
        'Triángulo Invertido',
      ],
      structuralSpec:
          'Marco de frente recto en acetato de alta densidad con bisagra flexible de 5 barriles.',
      cardAccent: Color(0xFFF1A661),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Block-54 Matte',
          materialAndLens: 'Acetato Negro Mate • Monofocal Digital HD',
          code: 'ATELIER #SQ-310',
        ),
        CatalogPiece(
          name: 'Architect Half-Rim',
          materialAndLens: 'Acero Quirúrgico + TR90 • Fotocromático Gen 8',
          code: 'ATELIER #SQ-412',
        ),
      ],
    ),
    'Gafas aviador': EyewearBentoProfile(
      displayTitle: 'Gafas Aviador',
      editorialBadge: 'ICÓNICO DOBLE PUENTE & GOTA',
      opticalAnalysis:
          'La silueta en forma de lágrima con doble barra nasal ensancha visualmente el tercio superior del rostro y equilibra el mentón.',
      idealFaceShapes: [
        'Rostro Corazón',
        'Rostro Cuadrado',
        'Rostro Ovalado',
      ],
      structuralSpec:
          'Armazón metálico delgado anticorrosivo con plaquetas nasales ergonómicas de silicona.',
      cardAccent: Color(0xFF2A9D8F),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS AeroPilot Gold',
          materialAndLens: 'Aleación Monel Dorada • Antirreflejo Esmeralda',
          code: 'ATELIER #AV-501',
        ),
        CatalogPiece(
          name: 'Navigator Carbon Edition',
          materialAndLens: 'Fibra de Carbono • Progresivo FreeForm HD',
          code: 'ATELIER #AV-588',
        ),
      ],
    ),
    'Gafas deportivas': EyewearBentoProfile(
      displayTitle: 'Gafas Deportivas',
      editorialBadge: 'AERODINÁMICA & ALTO RENDIMIENTO',
      opticalAnalysis:
          'Diseño envolvente de curvatura base 8 que ofrece cobertura periférica total, agarre antideslizante y protección contra impactos.',
      idealFaceShapes: [
        'Ajuste Craneal Universal',
        'Rostro Ovalado',
        'Rostro Atlético',
      ],
      structuralSpec:
          'Polímero con memoria Grilamid TR90 y terminales hidrofílicos de sujeción en 3 puntos.',
      cardAccent: Color(0xFF3D5A80),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Veloce Shield Pro',
          materialAndLens: 'TR90 Ultraflex • Policarbonato Ventilado UV400',
          code: 'ATELIER #SP-702',
        ),
        CatalogPiece(
          name: 'TrailRunner Impact RX',
          materialAndLens: 'Polímero Balístico + Clip Óptico • Espejado Revo',
          code: 'ATELIER #SP-745',
        ),
      ],
    ),
    'Gafas de sol': EyewearBentoProfile(
      displayTitle: 'Gafas de Sol',
      editorialBadge: 'PROTECCIÓN SOLAR UV400 & POLARIZADO',
      opticalAnalysis:
          'Lentes con filtro solar categoría 3 que bloquean el 100% de la radiación UVA/UVB y eliminan el deslumbramiento horizontal.',
      idealFaceShapes: [
        'Rostro Ovalado',
        'Rostro Cuadrado',
        'Rostro Redondo',
        'Rostro Corazón',
      ],
      structuralSpec:
          'Montura de calibre amplio (54-58mm) en bio-acetato pulido con alma metálica reforzada.',
      cardAccent: Color(0xFFD9534F),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Riviera Polarized',
          materialAndLens: 'Acetato Tortoise • Polarizado Categoría 3 UV400',
          code: 'ATELIER #SN-901',
        ),
        CatalogPiece(
          name: 'Solaris Amber Gradient',
          materialAndLens: 'Bio-Acetato + Herraje Dorado • Degradado Ámbar',
          code: 'ATELIER #SN-934',
        ),
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
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
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _initializeAll() async {
    await Future.wait([
      _loadTfliteAssets(),
      _setupCamera(),
    ]);
  }

  Future<void> _loadTfliteAssets() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/modelo_gafas.tflite',
        options: options,
      );

      final rawLabels = await rootBundle.loadString('assets/labels.txt');
      final cleanLabels = rawLabels
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (cleanLabels.isNotEmpty) {
        _labels = cleanLabels;
      }

      if (mounted) {
        setState(() => _isModelReady = true);
      }
    } catch (e) {
      debugPrint('Error cargando TFLite en ALJOLENS: $e');
    }
  }

  Future<void> _setupCamera() async {
    try {
      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
      }
      if (_availableCameras.isEmpty) return;

      final selected = _availableCameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Error cámara: $e');
    }
  }

  /// Detector auxiliar de textura uniforme o piel en primer plano (manos/fondos lisos)
  bool _isLikelyHandOrBlankSurface(img.Image resized224) {
    int skinTonePixels = 0;
    int lowContrastPixels = 0;
    const int totalPixels = 224 * 224;

    double sumLuminance = 0.0;
    final List<double> luminances = [];

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final p = resized224.getPixel(x, y);
        final int r = p.r.toInt();
        final int g = p.g.toInt();
        final int b = p.b.toInt();

        // Regla cromática RGB para detección de epidermis en primer plano
        final bool isSkin = r > 95 &&
            g > 40 &&
            b > 20 &&
            (r - g).abs() > 12 &&
            r > g &&
            r > b;
        if (isSkin) skinTonePixels++;

        final double lum = 0.299 * r + 0.587 * g + 0.114 * b;
        sumLuminance += lum;
        luminances.add(lum);
      }
    }

    final double meanLum = sumLuminance / totalPixels;
    for (final l in luminances) {
      if ((l - meanLum).abs() < 18.0) {
        lowContrastPixels++;
      }
    }

    final double skinRatio = skinTonePixels / totalPixels;
    final double flatRatio = lowContrastPixels / totalPixels;

    // Si más del 62% del recuadro es piel continua (una mano) o >85% es pared lisa sin bordes
    return skinRatio > 0.62 || flatRatio > 0.85;
  }

  Future<void> _scanAndEvaluateFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing ||
        !_isModelReady ||
        _interpreter == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile picture = await _cameraController!.takePicture();
      final Uint8List bytes = await File(picture.path).readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('No fue posible decodificar la imagen capturada.');
      }

      final img.Image oriented = img.bakeOrientation(decoded);
      final int side = oriented.width < oriented.height
          ? oriented.width
          : oriented.height;
      final int offsetX = (oriented.width - side) ~/ 2;
      final int offsetY = (oriented.height - side) ~/ 2;

      final img.Image squareCrop = img.copyCrop(
        oriented,
        x: offsetX,
        y: offsetY,
        width: side,
        height: side,
      );

      final img.Image resized = img.copyResize(
        squareCrop,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      final bool isHandOrBlank = _isLikelyHandOrBlankSurface(resized);

      // Tensor de entrada [1, 224, 224, 3] normalizado en [0.0, 1.0]
      final inputTensor = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              return <double>[
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Determinar dinámicamente cuántas clases tiene el modelo TFLite cargado (5 o 6)
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final int numModelClasses = outputShape.last;
      final outputTensor = List.generate(
        1,
        (_) => List<double>.filled(numModelClasses, 0.0),
      );

      _interpreter!.run(inputTensor, outputTensor);

      final List<double> probs = List<double>.from(outputTensor[0]);
      final List<PredictionItem> parsedResults = [];

      for (int i = 0; i < probs.length; i++) {
        final String labelName =
            i < _labels.length ? _labels[i] : 'Clase #$i';
        parsedResults.add(
          PredictionItem(label: labelName, confidence: probs[i]),
        );
      }

      parsedResults.sort((a, b) => b.confidence.compareTo(a.confidence));

      // Evaluación del Filtro Dual de Rechazo (Open-Set Guard)
      final PredictionItem top1 = parsedResults.first;
      final PredictionItem top2 = parsedResults.length > 1
          ? parsedResults[1]
          : const PredictionItem(label: '', confidence: 0.0);

      final double delta = top1.confidence - top2.confidence;
      final bool isNegativeClass =
          top1.label.toLowerCase().contains('sin_gafas') ||
              top1.label.toLowerCase().contains('sin gafas') ||
              top1.label.toLowerCase().contains('fondo');

      ScanUiState nextState = ScanUiState.discoverySuccess;
      String reason = '';

      if (isNegativeClass) {
        nextState = ScanUiState.rejectedFrame;
        reason =
            'El sensor detectó un fondo, mano u objeto distinto a una montura óptica.';
      } else if (isHandOrBlank && top1.confidence < 0.82) {
        nextState = ScanUiState.rejectedFrame;
        reason =
            'Se detectó una mano o superficie uniforme obstruyendo el encuadre. Apoya las gafas sobre una mesa despejada.';
      } else if (top1.confidence < _minConfidenceThreshold) {
        nextState = ScanUiState.rejectedFrame;
        reason =
            'Nivel de confianza insuficiente (${(top1.confidence * 100).toStringAsFixed(1)}% < 60%). Acerca la montura de frente y evita cubrir el puente con los dedos.';
      } else if (delta < _minDeltaMargin) {
        nextState = ScanUiState.rejectedFrame;
        reason =
            'Ambigüedad morfológica entre ${top1.label} y ${top2.label} (margen Δ de ${(delta * 100).toStringAsFixed(1)}% < 15%). Mejora la iluminación frontal.';
      }

      if (mounted) {
        setState(() {
          _capturedImagePath = picture.path;
          _predictions = parsedResults
              .where((p) =>
                  !p.label.toLowerCase().contains('sin_gafas') &&
                  !p.label.toLowerCase().contains('sin gafas'))
              .toList();
          _rejectionReason = reason;
          _uiState = nextState;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _uiState = ScanUiState.rejectedFrame;
          _rejectionReason = 'No se pudo procesar la captura: $e';
        });
      }
    }
  }

  void _resetToCamera() {
    setState(() {
      _capturedImagePath = null;
      _predictions = [];
      _rejectionReason = '';
      _uiState = ScanUiState.initialScanning;
    });
  }

  EyewearBentoProfile _resolveProfile(String label) {
    final clean = label.toLowerCase();
    if (clean.contains('redonda')) {
      return _atelierProfiles['Gafas redondas']!;
    } else if (clean.contains('cuadrada')) {
      return _atelierProfiles['Gafas cuadradas']!;
    } else if (clean.contains('aviador')) {
      return _atelierProfiles['Gafas aviador']!;
    } else if (clean.contains('deportiva')) {
      return _atelierProfiles['Gafas deportivas']!;
    }
    return _atelierProfiles['Gafas de sol']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEditorialTopBar(),
              const SizedBox(height: 14),
              Expanded(
                flex: _uiState == ScanUiState.initialScanning ? 6 : 4,
                child: _buildBentoCameraViewport(),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: _uiState == ScanUiState.initialScanning ? 3 : 6,
                child: _buildDynamicStatePanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ENCABEZADO WARM EDITORIAL "ALJOLENS"
  // ===========================================================================
  Widget _buildEditorialTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF264653),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFF1A661),
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ALJOLENS.',
                    style: TextStyle(
                      color: Color(0xFFF7EFE2),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEED7C5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _isModelReady ? 'AI STUDIO • OFFLINE' : 'CARGANDO MOTOR...',
                style: const TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        if (_uiState != ScanUiState.initialScanning)
          IconButton.filledTonal(
            onPressed: _resetToCamera,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFEED7C5),
              foregroundColor: const Color(0xFF264653),
            ),
            icon: const Icon(Icons.replay_rounded, size: 20),
            tooltip: 'Nuevo escaneo',
          ),
      ],
    );
  }

  // ===========================================================================
  // VISOR DE CÁMARA CON BORDES SUAVES (BORDER RADIUS 32) Y GUÍA ÓPTICA
  // ===========================================================================
  Widget _buildBentoCameraViewport() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF264653),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE6D5C3), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F264653),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_capturedImagePath != null)
            Image.file(
              File(_capturedImagePath!),
              fit: BoxFit.cover,
            )
          else if (_isCameraReady && _cameraController != null)
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
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFF1A661)),
            ),

          // Retículo guía de encuadre durante el modo escaneo
          if (_capturedImagePath == null && _isCameraReady)
            Center(
              child: Container(
                width: 240,
                height: 135,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFF7EFE2).withOpacity(0.9),
                    width: 2.2,
                  ),
                  color: Colors.black.withOpacity(0.10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF264653).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ENCUADRE ÓPTICO 224×224',
                          style: TextStyle(
                            color: Color(0xFFF1A661),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      color: Color(0x99FFFFFF),
                      size: 28,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Sin dedos sobre el puente nasal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Botón flotante para volver a capturar cuando hay foto fija
          if (_capturedImagePath != null)
            Positioned(
              bottom: 12,
              right: 12,
              child: FilledButton.tonalIcon(
                onPressed: _resetToCamera,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF264653).withOpacity(0.9),
                  foregroundColor: const Color(0xFFF7EFE2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text(
                  'Capturar otra',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SELECTOR DE LOS 3 ESTADOS DE INTERFAZ
  // ===========================================================================
  Widget _buildDynamicStatePanel() {
    switch (_uiState) {
      case ScanUiState.initialScanning:
        return _buildStateInitialScanning();
      case ScanUiState.rejectedFrame:
        return _buildStateRejectedFrame();
      case ScanUiState.discoverySuccess:
        return _buildStateDiscoveryAtelier();
    }
  }

  // ESTADO A: ESCANEO INICIAL
  Widget _buildStateInitialScanning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFEED7C5), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14E86A33),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const Text(
                'DESCUBRIMIENTO DE MONTURA',
                style: TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Coloca las gafas de frente sobre una superficie clara. Nuestro filtro descartará manos o tomas con menos del 60% de certeza.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF264653).withOpacity(0.75),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _scanAndEvaluateFrame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE86A33),
                foregroundColor: const Color(0xFFFFFDF9),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Analizando Geometría...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.center_focus_strong_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Escanear en ALJOLENS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ESTADO B: DESCARTE / RECHAZO ILUSTRADO (MANOS, FONDOS O BAJA CERTEZA)
  Widget _buildStateRejectedFrame() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE6D4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1A661), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: Color(0xFF264653),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.back_hand_outlined,
              color: Color(0xFFF1A661),
              size: 32,
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE86A33),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'FILTRO OPEN-SET ACTIVADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No se detectaron gafas válidas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _rejectionReason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFE86A33),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip ALJOLENS: Apoya las gafas sobre una mesa lisa y toma la foto desde arriba sin tapar el marco con la mano.',
                    style: TextStyle(
                      color: Color(0xFF264653),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _resetToCamera,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF264653),
                foregroundColor: const Color(0xFFF7EFE2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Reintentar Captura',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ESTADO C: DESCUBRIMIENTO "ALJOLENS ATELIER" (CUADRÍCULA BENTO)
  Widget _buildStateDiscoveryAtelier() {
    final PredictionItem winner = _predictions.first;
    final EyewearBentoProfile profile = _resolveProfile(winner.label);

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // TARJETA HERO BENTO DE RESULTADO
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: profile.cardAccent,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: profile.cardAccent.withOpacity(0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF264653).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      profile.editorialBadge,
                      style: const TextStyle(
                        color: Color(0xFFFFFDF9),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF264653),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(winner.confidence * 100).toStringAsFixed(1)}% CERTEZA',
                      style: const TextStyle(
                        color: Color(0xFFF1A661),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                profile.displayTitle.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFFFDF9),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile.opticalAnalysis,
                style: const TextStyle(
                  color: Color(0xFFFFFDF9),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // FILA BENTO DOBLE: ROSTROS IDEALES Y ESTRUCTURA DE MARCO
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF9),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFEED7C5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 18,
                          color: Color(0xFFE86A33),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'ROSTROS AFINES',
                          style: TextStyle(
                            color: Color(0xFF264653),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: profile.idealFaceShapes
                          .map(
                            (shape) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7EFE2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                shape,
                                style: const TextStyle(
                                  color: Color(0xFF264653),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF264653),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.architecture_rounded,
                          size: 18,
                          color: Color(0xFFF1A661),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'INGENIERÍA',
                          style: TextStyle(
                            color: Color(0xFFF1A661),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.structuralSpec,
                      style: const TextStyle(
                        color: Color(0xFFF7EFE2),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // TARJETA BENTO: CATÁLOGO DE AUTOR ALJOLENS ATELIER
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEED7C5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SUGERENCIAS DEL CATÁLOGO ALJOLENS ATELIER',
                style: TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              ...profile.pieces.map(
                (piece) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EFE2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: profile.cardAccent.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.visibility_rounded,
                          color: profile.cardAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              piece.name,
                              style: const TextStyle(
                                color: Color(0xFF264653),
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              piece.materialAndLens,
                              style: TextStyle(
                                color:
                                    const Color(0xFF264653).withOpacity(0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF264653),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          piece.code,
                          style: const TextStyle(
                            color: Color(0xFFF1A661),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // DISTRIBUCIÓN DE CONFIANZA DE LAS CATEGORÍAS ÓPTICAS
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEED7C5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DISTRIBUCIÓN TENSORIAL DE PROBABILIDADES',
                style: TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              ..._predictions.map((item) {
                final bool isWinner = item == winner;
                final double pct = (item.confidence * 100).clamp(0.0, 100.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: const Color(0xFF264653),
                              fontSize: 12,
                              fontWeight:
                                  isWinner ? FontWeight.w900 : FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: isWinner
                                  ? const Color(0xFFE86A33)
                                  : const Color(0xFF264653),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: item.confidence.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF7EFE2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isWinner
                                ? const Color(0xFFE86A33)
                                : const Color(0xFFF1A661),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
