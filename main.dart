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
  static const double _minConfidenceThreshold = 0.52;
  static const double _minDeltaMargin = 0.12;

  CameraController? _cameraController;
  Interpreter? _interpreter;

  // Las 8 categorías de SnellenVision + 1 clase de rechazo
  List<String> _labels = [
    'Aviador',
    'Browline',
    'Cat eye',
    'Geométrico',
    'Ovalado',
    'Rectangular',
    'Circular',
    'Cuadrado',
    'Sin gafas / Fondo',
  ];

  bool _isCameraReady = false;
  bool _isModelReady = false;
  bool _isProcessing = false;
  String? _capturedImagePath;
  String _rejectionReason = '';
  ScanUiState _uiState = ScanUiState.initialScanning;
  List<PredictionItem> _predictions = [];

  final Map<String, EyewearBentoProfile> _snellenCatalog = const {
    'Aviador': EyewearBentoProfile(
      displayTitle: 'Montura Aviador',
      editorialBadge: 'SILUETA LÁGRIMA & PUENTE CLÁSICO',
      opticalAnalysis:
          'Aros con caída en gota suave que equilibran el tercio medio facial y estilizan pómulos y mentón.',
      idealFaceShapes: ['Rostro Corazón', 'Rostro Cuadrado', 'Rostro Ovalado'],
      structuralSpec:
          'Frente estilizado con puente superior definido y apoyo nasal ergonómico.',
      cardAccent: Color(0xFF2A9D8F),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS AeroPilot 56',
          materialAndLens: 'Aleación Monel Ligera • Antirreflejo Esmeralda',
          code: 'SNELLEN #AV-01',
        ),
        CatalogPiece(
          name: 'Navigator Studio RX',
          materialAndLens: 'Titanio Cepillado • Lente Digital FreeForm',
          code: 'SNELLEN #AV-02',
        ),
      ],
    ),
    'Browline': EyewearBentoProfile(
      displayTitle: 'Montura Browline',
      editorialBadge: 'MARCO SUPERIOR CLUBMASTER',
      opticalAnalysis:
          'Su ceja superior acentuada enmarca la mirada y atrae la atención hacia la línea frontal superior del rostro.',
      idealFaceShapes: ['Rostro Triángulo', 'Rostro Ovalado', 'Rostro Redondo'],
      structuralSpec:
          'Cejas en acetato de alto calibre fusionadas con aro inferior metálico fino.',
      cardAccent: Color(0xFF3D5A80),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Clubmaster Heritage',
          materialAndLens: 'Acetato Caret + Acero Dorado • Filtro Luz Azul',
          code: 'SNELLEN #BR-11',
        ),
        CatalogPiece(
          name: 'Intellectual Brow 52',
          materialAndLens: 'Negro Mate + Titanio • Asférico 1.67 HD',
          code: 'SNELLEN #BR-12',
        ),
      ],
    ),
    'Cat eye': EyewearBentoProfile(
      displayTitle: 'Montura Cat Eye',
      editorialBadge: 'EFECTO LIFTING & ÁNGULO ASCENDENTE',
      opticalAnalysis:
          'Los extremos superiores elevados proyectan un efecto lifting visual que realza los pómulos y define el contorno facial.',
      idealFaceShapes: ['Rostro Redondo', 'Rostro Diamante', 'Rostro Cuadrado'],
      structuralSpec:
          'Frente en acetato esculpido con vértices laterales ascendentes y bisagra flex.',
      cardAccent: Color(0xFFD9534F),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Monroe Velvet',
          materialAndLens: 'Bio-Acetato Burdeos • Antirreflejo Multicapa',
          code: 'SNELLEN #CE-21',
        ),
        CatalogPiece(
          name: 'Feline Luxe 53',
          materialAndLens: 'Acetato Havana • Fotocromático Transitions',
          code: 'SNELLEN #CE-22',
        ),
      ],
    ),
    'Geométrico': EyewearBentoProfile(
      displayTitle: 'Montura Geométrica',
      editorialBadge: 'DISEÑO VANGUARDISTA & ANGULAR',
      opticalAnalysis:
          'Trazos poligonales y siluetas de autor que rompen la simetría tradicional y aportan una firma visual única.',
      idealFaceShapes: ['Rostro Ovalado', 'Rostro Redondo', 'Facciones Suaves'],
      structuralSpec:
          'Aros facetados en metal fresado o acetato geométrico de corte CNC.',
      cardAccent: Color(0xFFE86A33),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS HexaGold 50',
          materialAndLens: 'Acero Quirúrgico Dorado • Policarbonato BlueCut',
          code: 'SNELLEN #GM-31',
        ),
        CatalogPiece(
          name: 'Avant-Garde Heart/Poly',
          materialAndLens: 'Acetato Translúcido • Lente Ultraligero 1.60',
          code: 'SNELLEN #GM-32',
        ),
      ],
    ),
    'Ovalado': EyewearBentoProfile(
      displayTitle: 'Montura Ovalada',
      editorialBadge: 'PROPORCIÓN SUAVE & MINIMALISMO',
      opticalAnalysis:
          'Su elipse horizontal discreta acompaña las líneas naturales del rostro sin sobrecargar las facciones.',
      idealFaceShapes: ['Rostro Cuadrado', 'Rostro Diamante', 'Rostro Alargado'],
      structuralSpec:
          'Perfil elíptico de bajo espesor con terminales anatómicos ajustables.',
      cardAccent: Color(0xFF6D597A),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Ellipse Minimal',
          materialAndLens: 'Titanio Ultraligero 9g • Antirreflejo Zafiro',
          code: 'SNELLEN #OV-41',
        ),
        CatalogPiece(
          name: 'Soft Oval Classic 49',
          materialAndLens: 'Acetato Miel Translúcido • Monofocal Digital',
          code: 'SNELLEN #OV-42',
        ),
      ],
    ),
    'Rectangular': EyewearBentoProfile(
      displayTitle: 'Montura Rectangular',
      editorialBadge: 'LÍNEA HORIZONTAL & EJECUTIVA',
      opticalAnalysis:
          'Su proporción más ancha que alta acorta visualmente los rostros alargados y brinda estructura a mejillas redondeadas.',
      idealFaceShapes: ['Rostro Redondo', 'Rostro Ovalado', 'Rostro Alargado'],
      structuralSpec:
          'Armazón horizontal con varillas de ajuste firme y talón metálico.',
      cardAccent: Color(0xFF457B9D),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Executive 55',
          materialAndLens: 'Acetato Gris Grafito • Filtro Luz Azul + UV400',
          code: 'SNELLEN #RC-51',
        ),
        CatalogPiece(
          name: 'Linear Tech Frame',
          materialAndLens: 'Fibra de Carbono + TR90 • Progresivo Digital',
          code: 'SNELLEN #RC-52',
        ),
      ],
    ),
    'Circular': EyewearBentoProfile(
      displayTitle: 'Montura Circular',
      editorialBadge: 'GEOMETRÍA ORBITAL & RETRO',
      opticalAnalysis:
          'Círculos simétricos que suavizan mandíbulas pronunciadas, frentes anchas y mentones angulares.',
      idealFaceShapes: ['Rostro Cuadrado', 'Rostro Rectangular', 'Rostro Diamante'],
      structuralSpec:
          'Aro redondo de radio constante con puente en arco de alta comodidad.',
      cardAccent: Color(0xFFE76F51),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Orb-48 Panto',
          materialAndLens: 'Titanio Japonés • Lente Asférico Antirreflejo',
          code: 'SNELLEN #CR-61',
        ),
        CatalogPiece(
          name: 'Atelier Round Tortoise',
          materialAndLens: 'Acetato Mazzucchelli • BlueProtect HD',
          code: 'SNELLEN #CR-62',
        ),
      ],
    ),
    'Cuadrado': EyewearBentoProfile(
      displayTitle: 'Montura Cuadrada',
      editorialBadge: 'PRESENCIA ARQUITECTÓNICA & WAYFARER',
      opticalAnalysis:
          'Su caja ocular amplia de ángulos rectos proporciona contraste sólido a rostros curvos o de facciones suaves.',
      idealFaceShapes: ['Rostro Redondo', 'Rostro Ovalado', 'Triángulo Invertido'],
      structuralSpec:
          'Frente de acetato robusto con puente recto y bisagra reforzada de 5 puntos.',
      cardAccent: Color(0xFFF1A661),
      pieces: [
        CatalogPiece(
          name: 'ALJOLENS Block-54 Bold',
          materialAndLens: 'Acetato Negro Intenso • Monofocal HD Antirreflejo',
          code: 'SNELLEN #SQ-71',
        ),
        CatalogPiece(
          name: 'Studio Square Matte',
          materialAndLens: 'TR90 Alta Densidad • Fotocromático Gen 8',
          code: 'SNELLEN #SQ-72',
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
            i < _labels.length ? _labels[i] : 'Estilo #$i';
        parsedResults.add(
          PredictionItem(label: labelName, confidence: probs[i]),
        );
      }

      parsedResults.sort((a, b) => b.confidence.compareTo(a.confidence));

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
      } else if (isHandOrBlank && top1.confidence < 0.80) {
        nextState = ScanUiState.rejectedFrame;
        reason =
            'Se detectó una mano o superficie uniforme obstruyendo el encuadre. Apoya las gafas sobre una mesa despejada.';
      } else if (top1.confidence < _minConfidenceThreshold) {
        nextState = ScanUiState.rejectedFrame;
        reason =
            'Nivel de confianza insuficiente (${(top1.confidence * 100).toStringAsFixed(1)}%). Acerca la montura de frente sobre un fondo claro.';
      } else if (delta < _minDeltaMargin) {
        nextState = ScanUiState.rejectedFrame;
        reason =
            'Similitud ajustada entre ${top1.label} y ${top2.label}. Toma la fotografía completamente de frente sin inclinar el marco.';
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
    if (clean.contains('aviador')) return _snellenCatalog['Aviador']!;
    if (clean.contains('browline')) return _snellenCatalog['Browline']!;
    if (clean.contains('cat')) return _snellenCatalog['Cat eye']!;
    if (clean.contains('geom')) return _snellenCatalog['Geométrico']!;
    if (clean.contains('oval')) return _snellenCatalog['Ovalado']!;
    if (clean.contains('rectang')) return _snellenCatalog['Rectangular']!;
    if (clean.contains('circul') || clean.contains('redond')) {
      return _snellenCatalog['Circular']!;
    }
    return _snellenCatalog['Cuadrado']!;
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
                _isModelReady ? '8 ESTILOS SNELLEN • AI' : 'CARGANDO AI...',
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
                          'VISOR MORFOLÓGICO SNELLEN',
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
                        'Centra el frente de la montura',
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
                'DETECTOR DE 8 SILUETAS ÓPTICAS',
                style: TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Identifica Aviador, Browline, Cat eye, Geométrico, Ovalado, Rectangular, Circular y Cuadrado.',
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
                          'Analizando Silueta...',
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
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFF264653),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.back_hand_outlined,
              color: Color(0xFFF1A661),
              size: 30,
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
                  'ENCUADRE NO VÁLIDO',
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
                'No se detectó una montura clara',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF264653),
                  fontSize: 19,
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
                'Intentar de Nuevo',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateDiscoveryAtelier() {
    final PredictionItem winner = _predictions.first;
    final EyewearBentoProfile profile = _resolveProfile(winner.label);

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
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
                  Flexible(
                    child: Container(
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
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFFDF9),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      '${(winner.confidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFFF1A661),
                        fontSize: 12,
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
                  fontSize: 24,
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
                          'ARQUITECTURA',
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
                'SUGERENCIAS DEL CATÁLOGO ALJOLENS',
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
                'PROBABILIDADES EN LAS 8 SILUETAS SNELLEN',
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
