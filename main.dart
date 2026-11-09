import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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
    debugPrint('Aviso inicializando cámaras en ALJOLENS: $e');
  }
  runApp(const AljolensApp());
}

/// Paleta de colores y estilos globales de ALJOLENS (Diseño de 4 Pantallas)
class AljolensPalette {
  static const Color creamBg = Color(0xFFFDF8F4);
  static const Color creamSecondary = Color(0xFFF5EBE2);
  static const Color inputFill = Color(0xFFEFEAE6);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D1E17);
  static const Color textMuted = Color(0xFF8C7A6B);
  static const Color orangeStart = Color(0xFFFF8C3B);
  static const Color orangeEnd = Color(0xFFF26419);
  static const Color cameraBg = Color(0xFF5A5652);

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [orangeStart, orangeEnd],
  );

  static const LinearGradient orangeVerticalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [orangeStart, orangeEnd],
  );

  static List<BoxShadow> get softCardShadow => const [
        BoxShadow(
          color: Color(0x122D1E17),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get orangeButtonShadow => const [
        BoxShadow(
          color: Color(0x45F26419),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];
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
        scaffoldBackgroundColor: AljolensPalette.creamBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AljolensPalette.orangeEnd,
          primary: AljolensPalette.orangeEnd,
          secondary: AljolensPalette.orangeStart,
          surface: AljolensPalette.cardWhite,
        ),
      ),
      home: const AljolensRootController(),
    );
  }
}

class PredictionItem {
  final String label;
  final double confidence;

  const PredictionItem({
    required this.label,
    required this.confidence,
  });
}

/// Perfil técnico y estético para la Cuadrícula Bento (Pantalla 3) e Historial (Pantalla 4)
class EyewearBentoSpec {
  final String shapeKey;
  final String displayTitle;
  final String posituraCode;
  final String monturaUpper;
  final String specsTop;
  final String curvaturaLabel;
  final String dimMm;
  final String gamaCode;
  final String specsBottom;
  final String bridgeMm;
  final String categoryTier;
  final String catalogSubtitle;
  final String priceEur;
  final List<String> liveFeatureTags;
  final List<String> idealFaceShapes;
  final String opticalRecommendation;

  const EyewearBentoSpec({
    required this.shapeKey,
    required this.displayTitle,
    required this.posituraCode,
    required this.monturaUpper,
    required this.specsTop,
    required this.curvaturaLabel,
    required this.dimMm,
    required this.gamaCode,
    required this.specsBottom,
    required this.bridgeMm,
    required this.categoryTier,
    required this.catalogSubtitle,
    required this.priceEur,
    required this.liveFeatureTags,
    required this.idealFaceShapes,
    required this.opticalRecommendation,
  });
}

const Map<String, EyewearBentoSpec> kSnellenBentoCatalog = {
  'Aviador': EyewearBentoSpec(
    shapeKey: 'Aviador',
    displayTitle: 'Montura Aviador',
    posituraCode: 'AVIN/KxiGxl',
    monturaUpper: 'AVIADOR',
    specsTop: 'Doble Puente',
    curvaturaLabel: 'Comevado · Gota',
    dimMm: '138 mm',
    gamaCode: 'OPF',
    specsBottom: '358 c',
    bridgeMm: '6 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'AeroPilot Metal RX',
    priceEur: '54,00 €',
    liveFeatureTags: [
      'MONTURA AVIADOR',
      'DOBLE PUENTE',
      'HIGH-END',
      'SILUETA LÁGRIMA',
    ],
    idealFaceShapes: ['Rostro Corazón', 'Rostro Cuadrado', 'Rostro Ovalado'],
    opticalRecommendation:
        'Aros con caída en gota suave y puente doble superior que equilibran el tercio medio facial.',
  ),
  'Browline': EyewearBentoSpec(
    shapeKey: 'Browline',
    displayTitle: 'Montura Browline',
    posituraCode: 'BROW/ClbMst',
    monturaUpper: 'BROWLINE',
    specsTop: 'Marco Superior',
    curvaturaLabel: 'Comevado · Club',
    dimMm: '140 mm',
    gamaCode: 'OPF',
    specsBottom: '342 c',
    bridgeMm: '18 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'Clubmaster Heritage',
    priceEur: '58,00 €',
    liveFeatureTags: [
      'MONTURA BROWLINE',
      'CEJA SUPERIOR',
      'CLUBMASTER',
      'HIGH-END',
    ],
    idealFaceShapes: ['Rostro Triángulo', 'Rostro Ovalado', 'Rostro Redondo'],
    opticalRecommendation:
        'Ceja superior en acetato de alto calibre fusionada con aro inferior metálico fino.',
  ),
  'Cat eye': EyewearBentoSpec(
    shapeKey: 'Cat eye',
    displayTitle: 'Montura Cat Eye',
    posituraCode: 'CATE/UpSwpt',
    monturaUpper: 'CAT EYE',
    specsTop: 'Ángulo Lifting',
    curvaturaLabel: 'Comevado · Felino',
    dimMm: '136 mm',
    gamaCode: 'OPF',
    specsBottom: '320 c',
    bridgeMm: '16 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'Monroe Velvet Luxe',
    priceEur: '56,00 €',
    liveFeatureTags: [
      'MONTURA CAT EYE',
      'EFECTO LIFTING',
      'VÉRTICE ALTO',
      'HIGH-END',
    ],
    idealFaceShapes: ['Rostro Redondo', 'Rostro Diamante', 'Rostro Cuadrado'],
    opticalRecommendation:
        'Extremos superiores ascendentes que realzan los pómulos y definen el contorno facial.',
  ),
  'Geométrico': EyewearBentoSpec(
    shapeKey: 'Geométrico',
    displayTitle: 'Montura Geométrica',
    posituraCode: 'GEOM/HexOct',
    monturaUpper: 'GEOMÉTRICO',
    specsTop: 'Poligonal CNC',
    curvaturaLabel: 'Comevado · Hex',
    dimMm: '134 mm',
    gamaCode: 'OPF',
    specsBottom: '310 c',
    bridgeMm: '19 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'HexaGold Titanium',
    priceEur: '62,00 €',
    liveFeatureTags: [
      'MONTURA GEOMÉTRICA',
      'TRAZO HEXAGONAL',
      'CORTE CNC',
      'HIGH-END',
    ],
    idealFaceShapes: ['Rostro Ovalado', 'Rostro Redondo', 'Facciones Suaves'],
    opticalRecommendation:
        'Aros facetados octagonales/hexagonales que rompen la simetría tradicional con firma de autor.',
  ),
  'Ovalado': EyewearBentoSpec(
    shapeKey: 'Ovalado',
    displayTitle: 'Montura Ovalada',
    posituraCode: 'OVAL/ElpMin',
    monturaUpper: 'OVALADO',
    specsTop: 'Elipse Suave',
    curvaturaLabel: 'Comevado · Slim',
    dimMm: '132 mm',
    gamaCode: 'OPF',
    specsBottom: '295 c',
    bridgeMm: '17 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'Ellipse Minimal 9g',
    priceEur: '52,00 €',
    liveFeatureTags: [
      'MONTURA OVALADA',
      'PROPORCIÓN ELÍPTICA',
      'MINIMALISTA',
      'HIGH-END',
    ],
    idealFaceShapes: ['Rostro Cuadrado', 'Rostro Diamante', 'Rostro Alargado'],
    opticalRecommendation:
        'Elipse horizontal discreta de bajo espesor que suaviza mandíbulas y facciones angulares.',
  ),
  'Rectangular': EyewearBentoSpec(
    shapeKey: 'Rectangular',
    displayTitle: 'Montura Rectangular',
    posituraCode: 'RECT/LinEx5',
    monturaUpper: 'RECTANGULAR',
    specsTop: 'Línea Ejecutiva',
    curvaturaLabel: 'Comevado · Plano',
    dimMm: '142 mm',
    gamaCode: 'OPF',
    specsBottom: '365 c',
    bridgeMm: '17 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'Denstar Executive RX',
    priceEur: '54,00 €',
    liveFeatureTags: [
      'MONTURA RECTANGULAR',
      'HORIZONTE ANCHO',
      'EJECUTIVA',
      'HIGH-END',
    ],
    idealFaceShapes: ['Rostro Redondo', 'Rostro Ovalado', 'Rostro Alargado'],
    opticalRecommendation:
        'Proporción horizontal estructurada que acorta visualmente rostros alargados y define mejillas.',
  ),
  'Circular': EyewearBentoSpec(
    shapeKey: 'Circular',
    displayTitle: 'Montura Circular',
    posituraCode: 'CIRC/OrbPnt',
    monturaUpper: 'CIRCULAR',
    specsTop: 'Radio Constante',
    curvaturaLabel: 'Comevado · Panto',
    dimMm: '130 mm',
    gamaCode: 'OPF',
    specsBottom: '305 c',
    bridgeMm: '20 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'Orb-48 Panto Atelier',
    priceEur: '54,00 €',
    liveFeatureTags: [
      'MONTURA CIRCULAR',
      'ARCO SIMÉTRICO',
      'RETRO PANTO',
      'HIGH-END',
    ],
    idealFaceShapes: ['Rostro Cuadrado', 'Rostro Rectangular', 'Rostro Diamante'],
    opticalRecommendation:
        'Círculos simétricos de radio constante con puente en llave que suavizan frentes y mentones.',
  ),
  'Cuadrado': EyewearBentoSpec(
    shapeKey: 'Cuadrado',
    displayTitle: 'Montura Cuadrada',
    posituraCode: 'SQRE/BlkWay',
    monturaUpper: 'CUADRADO',
    specsTop: 'Caja Amplia',
    curvaturaLabel: 'Comevado · Bold',
    dimMm: '144 mm',
    gamaCode: 'OPF',
    specsBottom: '380 c',
    bridgeMm: '18 mm',
    categoryTier: 'High-end',
    catalogSubtitle: 'Block-54 Wayfarer',
    priceEur: '54,00 €',
    liveFeatureTags: [
      'MONTURA CUADRADA',
      'CAJA ARQUITECTÓNICA',
      'WAYFARER',
      'HIGH-END',
    ],
    idealFaceShapes: ['Rostro Redondo', 'Rostro Ovalado', 'Triángulo Invertido'],
    opticalRecommendation:
        'Frente de acetato robusto con ángulos rectos que aporta presencia sólida a rostros curvos.',
  ),
};

EyewearBentoSpec resolveBentoSpec(String rawLabel) {
  final clean = rawLabel.toLowerCase();
  if (clean.contains('aviador')) return kSnellenBentoCatalog['Aviador']!;
  if (clean.contains('browline')) return kSnellenBentoCatalog['Browline']!;
  if (clean.contains('cat')) return kSnellenBentoCatalog['Cat eye']!;
  if (clean.contains('geom')) return kSnellenBentoCatalog['Geométrico']!;
  if (clean.contains('oval')) return kSnellenBentoCatalog['Ovalado']!;
  if (clean.contains('rectang')) return kSnellenBentoCatalog['Rectangular']!;
  if (clean.contains('circul') || clean.contains('redond')) {
    return kSnellenBentoCatalog['Circular']!;
  }
  return kSnellenBentoCatalog['Cuadrado']!;
}

/// Modelo persistente para cada elemento en el Historial de Scans (Pantalla 4)
class ScanHistoryRecord {
  final String id;
  final String shapeKey;
  final double confidence;
  final double shannonEntropy;
  final String? imagePath;
  final String timestampIso;
  final bool isFavorite;
  final String? secondaryShape;

  const ScanHistoryRecord({
    required this.id,
    required this.shapeKey,
    required this.confidence,
    required this.shannonEntropy,
    this.imagePath,
    required this.timestampIso,
    this.isFavorite = false,
    this.secondaryShape,
  });

  ScanHistoryRecord copyWith({bool? isFavorite}) {
    return ScanHistoryRecord(
      id: id,
      shapeKey: shapeKey,
      confidence: confidence,
      shannonEntropy: shannonEntropy,
      imagePath: imagePath,
      timestampIso: timestampIso,
      isFavorite: isFavorite ?? this.isFavorite,
      secondaryShape: secondaryShape,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shapeKey': shapeKey,
        'confidence': confidence,
        'shannonEntropy': shannonEntropy,
        'imagePath': imagePath,
        'timestampIso': timestampIso,
        'isFavorite': isFavorite,
        'secondaryShape': secondaryShape,
      };

  factory ScanHistoryRecord.fromJson(Map<String, dynamic> map) {
    return ScanHistoryRecord(
      id: (map['id'] ?? '').toString(),
      shapeKey: (map['shapeKey'] ?? 'Aviador').toString(),
      confidence: (map['confidence'] is num)
          ? (map['confidence'] as num).toDouble()
          : 0.866,
      shannonEntropy: (map['shannonEntropy'] is num)
          ? (map['shannonEntropy'] as num).toDouble()
          : 0.24,
      imagePath: map['imagePath'] as String?,
      timestampIso: (map['timestampIso'] ?? '').toString(),
      isFavorite: map['isFavorite'] == true,
      secondaryShape: map['secondaryShape'] as String?,
    );
  }
}

/// Controlador raíz que coordina las 4 Pantallas, la sesión local y el motor TFLite
class AljolensRootController extends StatefulWidget {
  const AljolensRootController({super.key});

  @override
  State<AljolensRootController> createState() => _AljolensRootControllerState();
}

class _AljolensRootControllerState extends State<AljolensRootController>
    with WidgetsBindingObserver {
  // Umbrales Open-Set calibrados (Probabilidad de gafa + Softmax + Entropía de Shannon)
  static const double _minGlassesProbability = 0.80;
  static const double _minShapeConfidence = 0.45;
  static const double _minDeltaMargin = 0.10;
  static const double _maxNormalizedEntropy = 0.72;
  static const double _dualMinCombined = 0.80;
  static const double _cropFactor = 0.72;

  static const String _prefsUsersKey = 'aljolens_users_v5';
  static const String _prefsActiveUserKey = 'aljolens_active_user_v5';
  static const String _prefsHistoryKey = 'aljolens_scan_history_v5';

  CameraController? _cameraController;
  Interpreter? _interpreter;

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
  bool _isFlashOn = false;

  // Sesión local (Pantalla 1)
  String? _loggedUserEmail;
  Map<String, String> _registeredUsers = {};

  // Navegación entre las 4 pantallas:
  // Si _loggedUserEmail == null -> muestra Pantalla 1 (Welcome to ALJOLENS)
  // Si está autenticado:
  //   _activeTab: 0 = Inicio, 1 = Escáner IA (Pantalla 2), 2 = Historial (Pantalla 4), 3 = Perfil
  //   _activeResultRecord != null -> muestra Pantalla 3 (Resultados Bento)
  int _activeTab = 1;
  ScanHistoryRecord? _activeResultRecord;

  // Estado en tiempo real del Escáner IA (Pantalla 2)
  String _liveBannerText = 'MONTURA AVIADOR';
  bool _isLiveRejected = false;
  String _rejectionDetail = '';
  List<String> _liveFeatureTags = const [
    'MONTURA AVIADOR',
    'MONTURA LOOD',
    'HIGH-END',
  ];
  List<PredictionItem> _lastPredictions = [];

  // Historial de Scans (Pantalla 4)
  List<ScanHistoryRecord> _scanHistory = [];

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
      _loadLocalPersistence(),
      _loadTfliteAssets(),
      _setupCamera(),
    ]);
  }

  Future<void> _loadLocalPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Usuarios registrados localmente
      final rawUsers = prefs.getString(_prefsUsersKey);
      if (rawUsers != null && rawUsers.isNotEmpty) {
        final decoded = jsonDecode(rawUsers) as Map<String, dynamic>;
        _registeredUsers = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
      if (_registeredUsers.isEmpty) {
        _registeredUsers = {
          'optica@aljolens.com': '123456',
          'admin': '123456',
        };
        await prefs.setString(_prefsUsersKey, jsonEncode(_registeredUsers));
      }

      _loggedUserEmail = prefs.getString(_prefsActiveUserKey);

      // 2. Historial de Scans guardado localmente
      final rawHistory = prefs.getString(_prefsHistoryKey);
      if (rawHistory != null && rawHistory.isNotEmpty) {
        final list = jsonDecode(rawHistory) as List<dynamic>;
        _scanHistory = list
            .map((e) => ScanHistoryRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (_scanHistory.isEmpty) {
        _scanHistory = _buildDefaultSeedHistory();
        await _saveHistoryToPrefs();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Aviso cargando persistencia local: $e');
    }
  }

  List<ScanHistoryRecord> _buildDefaultSeedHistory() {
    final now = DateTime.now().toIso8601String();
    return [
      ScanHistoryRecord(
        id: 'seed_rect_1',
        shapeKey: 'Rectangular',
        confidence: 0.912,
        shannonEntropy: 0.19,
        timestampIso: now,
        isFavorite: true,
      ),
      ScanHistoryRecord(
        id: 'seed_sq_2',
        shapeKey: 'Cuadrado',
        confidence: 0.884,
        shannonEntropy: 0.22,
        timestampIso: now,
        isFavorite: true,
      ),
      ScanHistoryRecord(
        id: 'seed_brow_3',
        shapeKey: 'Browline',
        confidence: 0.895,
        shannonEntropy: 0.21,
        timestampIso: now,
        isFavorite: true,
      ),
      ScanHistoryRecord(
        id: 'seed_avi_4',
        shapeKey: 'Aviador',
        confidence: 0.866,
        shannonEntropy: 0.24,
        timestampIso: now,
        isFavorite: true,
      ),
      ScanHistoryRecord(
        id: 'seed_cat_5',
        shapeKey: 'Cat eye',
        confidence: 0.904,
        shannonEntropy: 0.20,
        timestampIso: now,
        isFavorite: false,
      ),
      ScanHistoryRecord(
        id: 'seed_geom_6',
        shapeKey: 'Geométrico',
        confidence: 0.878,
        shannonEntropy: 0.25,
        timestampIso: now,
        isFavorite: false,
      ),
      ScanHistoryRecord(
        id: 'seed_circ_7',
        shapeKey: 'Circular',
        confidence: 0.921,
        shannonEntropy: 0.18,
        timestampIso: now,
        isFavorite: false,
      ),
      ScanHistoryRecord(
        id: 'seed_oval_8',
        shapeKey: 'Ovalado',
        confidence: 0.859,
        shannonEntropy: 0.26,
        timestampIso: now,
        isFavorite: false,
      ),
    ];
  }

  Future<void> _saveHistoryToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_scanHistory.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsHistoryKey, encoded);
    } catch (e) {
      debugPrint('Error guardando historial: $e');
    }
  }

  Future<String?> _handleLogin(String userOrEmail, String password) async {
    final key = userOrEmail.trim().toLowerCase();
    final pass = password.trim();
    if (key.isEmpty || pass.isEmpty) {
      return 'Ingresa tu usuario/correo y contraseña.';
    }
    final storedPass = _registeredUsers[key];
    if (storedPass == null) {
      return 'La cuenta no existe. Créala en la pestaña "Crear Cuenta".';
    }
    if (storedPass != pass) {
      return 'Contraseña incorrecta.';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActiveUserKey, key);
    if (mounted) {
      setState(() {
        _loggedUserEmail = key;
        _activeTab = 1; // Abre directamente el Escáner IA o la navegación principal
      });
    }
    return null;
  }

  Future<String?> _handleRegister(String userOrEmail, String password) async {
    final key = userOrEmail.trim().toLowerCase();
    final pass = password.trim();
    if (key.isEmpty || pass.length < 4) {
      return 'Ingresa un usuario válido y una contraseña de al menos 4 caracteres.';
    }
    _registeredUsers[key] = pass;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUsersKey, jsonEncode(_registeredUsers));
    await prefs.setString(_prefsActiveUserKey, key);
    if (mounted) {
      setState(() {
        _loggedUserEmail = key;
        _activeTab = 1;
      });
    }
    return null;
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsActiveUserKey);
    if (mounted) {
      setState(() {
        _loggedUserEmail = null;
        _activeResultRecord = null;
      });
    }
  }

  Future<void> _toggleFavorite(String id) async {
    final idx = _scanHistory.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    setState(() {
      _scanHistory[idx] = _scanHistory[idx].copyWith(
        isFavorite: !_scanHistory[idx].isFavorite,
      );
      if (_activeResultRecord?.id == id) {
        _activeResultRecord = _scanHistory[idx];
      }
    });
    await _saveHistoryToPrefs();
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
      debugPrint('Error cargando modelo_gafas.tflite en ALJOLENS: $e');
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
        setState(() {
          _isCameraReady = true;
          _isFlashOn = false;
        });
      }
    } catch (e) {
      debugPrint('Error configurando cámara: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final nextMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(nextMode);
      if (mounted) {
        setState(() => _isFlashOn = !_isFlashOn);
      }
    } catch (e) {
      debugPrint('No se pudo cambiar el flash: $e');
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

  bool _isNegativeLabel(String label) {
    final clean = label.toLowerCase();
    return clean.contains('sin_gafas') ||
        clean.contains('sin gafas') ||
        clean.contains('no_es_montura') ||
        clean.contains('fondo');
  }

  /// Calcula la Entropía de Shannon normalizada en [0, 1] sobre las probabilidades de forma:
  /// H(p) = - sum(p_i * ln(p_i)) / ln(K)
  double _computeNormalizedShannonEntropy(List<double> shapeProbs) {
    if (shapeProbs.length <= 1) return 0.0;
    double sumH = 0.0;
    for (final p in shapeProbs) {
      final double clipped = p.clamp(1e-7, 1.0);
      sumH -= clipped * math.log(clipped);
    }
    final double maxH = math.log(shapeProbs.length.toDouble());
    return (sumH / maxH).clamp(0.0, 1.0);
  }

  List<double> _runInference(img.Image resized224) {
    final inputTensor = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = resized224.getPixel(x, y);
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
    return List<double>.from(outputTensor[0]);
  }

  Future<void> _captureAndClassifyFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing ||
        !_isModelReady ||
        _interpreter == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _rejectionDetail = '';
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      final Uint8List bytes = await File(picture.path).readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('No fue posible decodificar la captura de cámara.');
      }

      final img.Image oriented = img.bakeOrientation(decoded);
      final int minDim = oriented.width < oriented.height
          ? oriented.width
          : oriented.height;
      final int side = (minDim * _cropFactor).round();
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

      // Inferencia con Test-Time Augmentation (Original + Espejo Horizontal)
      final List<double> probsOriginal = _runInference(resized);
      final List<double> probsMirror =
          _runInference(img.flipHorizontal(img.Image.from(resized)));
      final List<double> probs = List<double>.generate(
        probsOriginal.length,
        (i) => (probsOriginal[i] + probsMirror[i]) / 2.0,
      );

      int negativeIndex = -1;
      for (int i = 0; i < probs.length && i < _labels.length; i++) {
        if (_isNegativeLabel(_labels[i])) {
          negativeIndex = i;
          break;
        }
      }
      final double pNoGlasses = negativeIndex >= 0 ? probs[negativeIndex] : 0.0;
      final double pGlasses = (1.0 - pNoGlasses).clamp(0.0, 1.0);

      final List<PredictionItem> shapeResults = [];
      final List<double> rawShapeProbs = [];
      for (int i = 0; i < probs.length; i++) {
        if (i == negativeIndex) continue;
        final String labelName =
            i < _labels.length ? _labels[i] : 'Estilo #$i';
        final double shapeConfidence =
            pGlasses > 1e-6 ? (probs[i] / pGlasses).clamp(0.0, 1.0) : 0.0;
        rawShapeProbs.add(shapeConfidence);
        shapeResults.add(
          PredictionItem(label: labelName, confidence: shapeConfidence),
        );
      }

      final double shannonEntropy =
          _computeNormalizedShannonEntropy(rawShapeProbs);

      shapeResults.sort((a, b) => b.confidence.compareTo(a.confidence));

      final PredictionItem top1 = shapeResults.isNotEmpty
          ? shapeResults.first
          : const PredictionItem(label: 'Aviador', confidence: 0.0);
      final PredictionItem top2 = shapeResults.length > 1
          ? shapeResults[1]
          : const PredictionItem(label: '', confidence: 0.0);
      final double delta = top1.confidence - top2.confidence;

      bool rejectedOpenSet = false;
      String rejectMsg = '';
      String? secondaryLabel;

      if (pGlasses < _minGlassesProbability) {
        rejectedOpenSet = true;
        rejectMsg =
            'Rechazo Open-Set: Probabilidad de montura baja (${(pGlasses * 100).toStringAsFixed(1)}%). Apunta a unas gafas reales.';
      } else if (isHandOrBlank && pGlasses < 0.95) {
        rejectedOpenSet = true;
        rejectMsg =
            'Superficie uniforme o mano detectada en el encuadre. Centra únicamente la montura.';
      } else if (shannonEntropy > _maxNormalizedEntropy) {
        rejectedOpenSet = true;
        rejectMsg =
            'Rechazo Open-Set por alta incertidumbre morfológica (Entropía Shannon ${(shannonEntropy * 100).toStringAsFixed(0)}%).';
      } else if (top1.confidence < _minShapeConfidence) {
        rejectedOpenSet = true;
        rejectMsg =
            'Confianza Softmax insuficiente (${(top1.confidence * 100).toStringAsFixed(1)}%). Acerca la montura de frente.';
      } else if (delta < _minDeltaMargin) {
        if ((top1.confidence + top2.confidence) >= _dualMinCombined &&
            top2.label.isNotEmpty) {
          secondaryLabel = top2.label;
        } else {
          rejectedOpenSet = true;
          rejectMsg =
              'Ambigüedad entre ${top1.label} y ${top2.label}. Alinea las gafas de frente.';
        }
      }

      if (!mounted) return;

      if (rejectedOpenSet) {
        setState(() {
          _isProcessing = false;
          _isLiveRejected = true;
          _liveBannerText = 'NO ES UNA GAFA';
          _rejectionDetail = rejectMsg;
          _liveFeatureTags = const [
            'NO ES UNA GAFA',
            'RECHAZO OPEN-SET',
            'REINTENTAR ENFOQUE',
          ];
          _lastPredictions = shapeResults;
        });
        return;
      }

      final spec = resolveBentoSpec(top1.label);
      final newRecord = ScanHistoryRecord(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        shapeKey: spec.shapeKey,
        confidence: top1.confidence,
        shannonEntropy: shannonEntropy,
        imagePath: picture.path,
        timestampIso: DateTime.now().toIso8601String(),
        isFavorite: false,
        secondaryShape: secondaryLabel,
      );

      setState(() {
        _isProcessing = false;
        _isLiveRejected = false;
        _rejectionDetail = '';
        _liveBannerText = 'MONTURA ${spec.monturaUpper}';
        _liveFeatureTags = spec.liveFeatureTags;
        _lastPredictions = shapeResults;
        _scanHistory.insert(0, newRecord);
        _activeResultRecord = newRecord;
      });
      await _saveHistoryToPrefs();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isLiveRejected = true;
          _liveBannerText = 'NO ES UNA GAFA';
          _rejectionDetail = 'Error procesando captura: $e';
        });
      }
    }
  }

  void _showOpenSetSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AljolensPalette.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Motor TFLite & Calibración Open-Set',
                    style: TextStyle(
                      color: AljolensPalette.textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: AljolensPalette.orangeGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isModelReady ? 'OFFLINE ACTIVO' : 'CARGANDO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildThresholdRow(
                'Umbral Presencia P(gafas)',
                '${(_minGlassesProbability * 100).toStringAsFixed(0)}%',
              ),
              _buildThresholdRow(
                'Confianza Mínima Softmax (8 formas)',
                '${(_minShapeConfidence * 100).toStringAsFixed(0)}%',
              ),
              _buildThresholdRow(
                'Entropía Máxima de Shannon H(p)',
                _maxNormalizedEntropy.toStringAsFixed(2),
              ),
              _buildThresholdRow(
                'Recorte Central Visor 1:1',
                '${(_cropFactor * 100).toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 12),
              const Text(
                'Combina probabilidad máxima Softmax + Entropía de Shannon para rechazar objetos que no son gafas (• NO ES UNA GAFA).',
                style: TextStyle(
                  color: AljolensPalette.textMuted,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThresholdRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AljolensPalette.textDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AljolensPalette.orangeEnd,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla 1: Si no hay sesión iniciada, mostrar Bienvenida, Login y Registro Local
    if (_loggedUserEmail == null) {
      return WelcomeAuthScreen(
        onLogin: _handleLogin,
        onRegister: _handleRegister,
      );
    }

    // Pantalla 3: Si hay un resultado seleccionado, mostrar Diseño Bento de Clasificación
    if (_activeResultRecord != null) {
      return BentoResultScreen(
        record: _activeResultRecord!,
        allPredictions: _lastPredictions,
        onBack: () => setState(() => _activeResultRecord = null),
        onScanAnother: () => setState(() {
          _activeResultRecord = null;
          _activeTab = 1;
        }),
        onOpenHistory: () => setState(() {
          _activeResultRecord = null;
          _activeTab = 2;
        }),
      );
    }

    // Pantalla 2: Escáner IA en Vivo a pantalla completa
    if (_activeTab == 1) {
      return LiveScannerScreen(
        cameraController: _cameraController,
        isCameraReady: _isCameraReady,
        isModelReady: _isModelReady,
        isProcessing: _isProcessing,
        isFlashOn: _isFlashOn,
        liveBannerText: _liveBannerText,
        isLiveRejected: _isLiveRejected,
        rejectionDetail: _rejectionDetail,
        liveFeatureTags: _liveFeatureTags,
        onCloseToHistory: () => setState(() => _activeTab = 2),
        onToggleFlash: _toggleFlash,
        onOpenSettings: _showOpenSetSettingsSheet,
        onCapture: _captureAndClassifyFrame,
        onSelectQuickDemoShape: (String shapeKey) {
          final spec = resolveBentoSpec(shapeKey);
          setState(() {
            _isLiveRejected = false;
            _rejectionDetail = '';
            _liveBannerText = 'MONTURA ${spec.monturaUpper}';
            _liveFeatureTags = spec.liveFeatureTags;
          });
        },
      );
    }

    // Contenedor con Barra de Navegación Inferior de 4 Pestañas (Inicio, Escáner, Historial, Perfil)
    return Scaffold(
      backgroundColor: AljolensPalette.creamBg,
      body: SafeArea(
        child: _buildCurrentTabBody(),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_activeTab) {
      case 0:
        return _buildHomeDashboardTab();
      case 2:
        return ScanHistoryScreen(
          records: _scanHistory,
          onToggleFavorite: _toggleFavorite,
          onOpenDetails: (record) {
            setState(() => _activeResultRecord = record);
          },
          onBackToScanner: () => setState(() => _activeTab = 1),
        );
      case 3:
        return _buildAccountProfileTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHomeDashboardTab() {
    final int favCount = _scanHistory.where((e) => e.isFavorite).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to',
                  style: TextStyle(
                    color: AljolensPalette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'ALJOLENS STUDIO',
                  style: TextStyle(
                    color: AljolensPalette.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => setState(() => _activeTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: AljolensPalette.orangeGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AljolensPalette.orangeButtonShadow,
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.center_focus_strong_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Escáner IA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AljolensPalette.orangeGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AljolensPalette.orangeButtonShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CLASIFICADOR ÓPTICO OFFLINE v5',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Reconoce 8 siluetas Snellen con rechazo Open-Set inteligente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatPill('${_scanHistory.length} Scans'),
                  const SizedBox(width: 8),
                  _buildStatPill('$favCount Favoritas ♥'),
                  const SizedBox(width: 8),
                  _buildStatPill(_isModelReady ? 'TFLite Listo' : 'Cargando'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Escaneos Recientes',
              style: TextStyle(
                color: AljolensPalette.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _activeTab = 2),
              child: const Text(
                'Ver todos',
                style: TextStyle(
                  color: AljolensPalette.orangeEnd,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._scanHistory.take(4).map((record) {
          final spec = resolveBentoSpec(record.shapeKey);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AljolensPalette.cardWhite,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AljolensPalette.softCardShadow,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  height: 44,
                  child: CustomPaint(
                    painter: EyewearSilhouettePainter(shapeKey: spec.shapeKey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.displayTitle,
                        style: const TextStyle(
                          color: AljolensPalette.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${(record.confidence * 100).toStringAsFixed(1)}% MATCH · ${spec.posituraCode}',
                        style: const TextStyle(
                          color: AljolensPalette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _activeResultRecord = record),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AljolensPalette.orangeGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Detalles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildAccountProfileTab() {
    final int favs = _scanHistory.where((e) => e.isFavorite).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: [
        const Text(
          'Perfil de Cuenta',
          style: TextStyle(
            color: AljolensPalette.textDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AljolensPalette.cardWhite,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AljolensPalette.softCardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  gradient: AljolensPalette.orangeGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _loggedUserEmail ?? 'usuario@aljolens.com',
                style: const TextStyle(
                  color: AljolensPalette.textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Especialista Óptico · Cuenta Local Offline',
                style: TextStyle(
                  color: AljolensPalette.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileMetric('${_scanHistory.length}', 'Escaneos'),
                  _buildProfileMetric('$favs', 'Favoritos'),
                  _buildProfileMetric('8', 'Siluetas IA'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AljolensPalette.cardWhite,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AljolensPalette.softCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parámetros del Clasificador TFLite',
                style: TextStyle(
                  color: AljolensPalette.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _buildThresholdRow('Modelo activo', 'assets/modelo_gafas.tflite'),
              _buildThresholdRow('Rechazo Open-Set', 'Softmax + Shannon H(p)'),
              _buildThresholdRow('Persistencia', 'SharedPreferences Local'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: _handleLogout,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AljolensPalette.orangeGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: AljolensPalette.orangeButtonShadow,
            ),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AljolensPalette.orangeEnd,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AljolensPalette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: AljolensPalette.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x142D1E17),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(index: 0, icon: Icons.home_filled, tooltip: 'Inicio'),
          _buildNavItem(
            index: 1,
            icon: Icons.search_rounded,
            tooltip: 'Búsqueda / Escáner',
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.calendar_today_outlined,
            tooltip: 'Historial de Scans',
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.person_outline_rounded,
            tooltip: 'Perfil de Cuenta',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String tooltip,
  }) {
    final bool isSelected = _activeTab == index;
    return IconButton(
      onPressed: () => setState(() => _activeTab = index),
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: 25,
        color: isSelected
            ? AljolensPalette.orangeEnd
            : AljolensPalette.textMuted,
      ),
    );
  }
}

// ============================================================================
// PANTALLA 1: BIENVENIDA, LOGIN Y REGISTRO LOCAL (Welcome to ALJOLENS)
// ============================================================================
class WelcomeAuthScreen extends StatefulWidget {
  final Future<String?> Function(String user, String password) onLogin;
  final Future<String?> Function(String user, String password) onRegister;

  const WelcomeAuthScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  State<WelcomeAuthScreen> createState() => _WelcomeAuthScreenState();
}

class _WelcomeAuthScreenState extends State<WelcomeAuthScreen> {
  bool _isLoginTab = true;
  bool _obscurePassword = true;
  String? _feedbackMessage;

  final TextEditingController _userController = TextEditingController(
    text: 'optica@aljolens.com',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '123456',
  );

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    setState(() => _feedbackMessage = null);
    final user = _userController.text;
    final pass = _passwordController.text;

    final String? err = _isLoginTab
        ? await widget.onLogin(user, pass)
        : await widget.onRegister(user, pass);

    if (err != null && mounted) {
      setState(() => _feedbackMessage = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AljolensPalette.creamBg,
      body: Stack(
        children: [
          // Cabecera con ondas fluidas en degradado naranja (#FF8C3B a #F26419)
          Positioned.fill(
            child: CustomPaint(
              painter: OrangeWavesHeaderPainter(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 18),
                    const Text(
                      'Welcome to',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ALJOLENS',
                      style: TextStyle(
                        color: AljolensPalette.textDark,
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Tarjeta central con pestañas Iniciar Sesión / Crear Cuenta
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.94),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AljolensPalette.softCardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Pestañas superiores
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isLoginTab = true;
                                    _feedbackMessage = null;
                                  }),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Iniciar Sesión',
                                        style: TextStyle(
                                          color: _isLoginTab
                                              ? AljolensPalette.textDark
                                              : AljolensPalette.textMuted,
                                          fontSize: 13.5,
                                          fontWeight: _isLoginTab
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          color: _isLoginTab
                                              ? AljolensPalette.orangeEnd
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isLoginTab = false;
                                    _feedbackMessage = null;
                                  }),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Crear Cuenta',
                                        style: TextStyle(
                                          color: !_isLoginTab
                                              ? AljolensPalette.textDark
                                              : AljolensPalette.textMuted,
                                          fontSize: 13.5,
                                          fontWeight: !_isLoginTab
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          color: !_isLoginTab
                                              ? AljolensPalette.orangeEnd
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFEAE2DC),
                          ),
                          const SizedBox(height: 22),

                          // Campo de usuario / correo
                          Container(
                            decoration: BoxDecoration(
                              color: AljolensPalette.inputFill,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: TextField(
                              controller: _userController,
                              style: const TextStyle(
                                color: AljolensPalette.textDark,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Nombre o usuario / correo',
                                hintStyle: TextStyle(
                                  color: AljolensPalette.textMuted,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Campo de contraseña con botón de mostrar/ocultar
                          Container(
                            decoration: BoxDecoration(
                              color: AljolensPalette.inputFill,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: AljolensPalette.textDark,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Contraseña',
                                hintStyle: const TextStyle(
                                  color: AljolensPalette.textMuted,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 19,
                                    color: AljolensPalette.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _userController.text = 'optica@aljolens.com';
                                  _passwordController.text = '123456';
                                  _feedbackMessage =
                                      'Credenciales locales restauradas (optica@aljolens.com / 123456).';
                                });
                              },
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: AljolensPalette.orangeEnd,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          if (_feedbackMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _feedbackMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AljolensPalette.orangeEnd,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Botón principal en degradado naranja (#FF8C3B a #F26419)
                          GestureDetector(
                            onTap: _submitForm,
                            child: Container(
                              height: 50,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: AljolensPalette.orangeGradient,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: AljolensPalette.orangeButtonShadow,
                              ),
                              child: Text(
                                _isLoginTab ? 'Iniciar sesión' : 'Crear cuenta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pie inferior "Already come to ALJOLENS?"
                    GestureDetector(
                      onTap: () => setState(() => _isLoginTab = !_isLoginTab),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: AljolensPalette.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(text: 'Already come to '),
                            TextSpan(
                              text: 'ALJOLENS?',
                              style: TextStyle(
                                color: AljolensPalette.orangeEnd,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintor de las ondas fluidas en degradado naranja de la Pantalla 1
class OrangeWavesHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect topRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.68);

    // Fondo base suave cálido superior
    final Paint softBgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFB074),
          Color(0xFFFF8C3B),
          Color(0xFFF26419),
        ],
      ).createShader(topRect);

    final Path mainWave = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.56)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.64,
        size.width * 0.42,
        size.height * 0.50,
      )
      ..quadraticBezierTo(
        size.width * 0.14,
        size.height * 0.38,
        0,
        size.height * 0.44,
      )
      ..close();
    canvas.drawPath(mainWave, softBgPaint);

    // Segunda onda superpuesta más intensa (#FF8C3B -> #F26419)
    final Paint deepWavePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFF984F),
          Color(0xFFF26419),
        ],
      ).createShader(topRect);

    final Path secondWave = Path()
      ..moveTo(size.width * 0.34, 0)
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.18,
        size.width,
        size.height * 0.25,
      )
      ..lineTo(size.width, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.48,
        size.width * 0.22,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.05,
        size.height * 0.28,
        0,
        size.height * 0.29,
      )
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(secondWave, deepWavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// PANTALLA 2: ESCÁNER IA EN VIVO (Visor esquinas naranjas + Live feature tags)
// ============================================================================
class LiveScannerScreen extends StatelessWidget {
  final CameraController? cameraController;
  final bool isCameraReady;
  final bool isModelReady;
  final bool isProcessing;
  final bool isFlashOn;
  final String liveBannerText;
  final bool isLiveRejected;
  final String rejectionDetail;
  final List<String> liveFeatureTags;
  final VoidCallback onCloseToHistory;
  final VoidCallback onToggleFlash;
  final VoidCallback onOpenSettings;
  final VoidCallback onCapture;
  final ValueChanged<String> onSelectQuickDemoShape;

  const LiveScannerScreen({
    super.key,
    required this.cameraController,
    required this.isCameraReady,
    required this.isModelReady,
    required this.isProcessing,
    required this.isFlashOn,
    required this.liveBannerText,
    required this.isLiveRejected,
    required this.rejectionDetail,
    required this.liveFeatureTags,
    required this.onCloseToHistory,
    required this.onToggleFlash,
    required this.onOpenSettings,
    required this.onCapture,
    required this.onSelectQuickDemoShape,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AljolensPalette.cameraBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vista de cámara a pantalla completa (o visor interactivo si no hay cámara física)
          if (isCameraReady &&
              cameraController != null &&
              cameraController!.value.isInitialized)
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cameraController!.value.previewSize!.height,
                    height: cameraController!.value.previewSize!.width,
                    child: CameraPreview(cameraController!),
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF66625E),
                    Color(0xFF524E4A),
                    Color(0xFF45423E),
                  ],
                ),
              ),
            ),

          // Capa oscura sutil alrededor para resaltar el recuadro central
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Barra superior (Cerrar, Flash, Ajustes)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: onCloseToHistory,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        tooltip: 'Cerrar escáner',
                      ),
                      IconButton(
                        onPressed: onToggleFlash,
                        icon: Icon(
                          isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: isFlashOn
                              ? AljolensPalette.orangeStart
                              : Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Alternar flash',
                      ),
                      IconButton(
                        onPressed: onOpenSettings,
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Ajustes Open-Set',
                      ),
                    ],
                  ),
                ),

                // Recuadro central de enfoque con esquinas naranjas brillantes,
                // cuadrícula de tercios y etiqueta flotante en tiempo real
                Center(
                  child: SizedBox(
                    width: 286,
                    height: 286,
                    child: Stack(
                      children: [
                        // Fondo translúcido claro dentro del recuadro + cuadrícula de tercios y esquinas naranjas
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ScannerReticlePainter(
                              isRejected: isLiveRejected,
                            ),
                          ),
                        ),

                        // Si la cámara no está activa (ej. emulador sin webcam), muestra silueta guía
                        if (!isCameraReady)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: SizedBox(
                                width: 220,
                                height: 100,
                                child: CustomPaint(
                                  painter: EyewearSilhouettePainter(
                                    shapeKey: liveBannerText
                                            .toLowerCase()
                                            .contains('browline')
                                        ? 'Browline'
                                        : liveBannerText
                                                .toLowerCase()
                                                .contains('cat')
                                            ? 'Cat eye'
                                            : 'Aviador',
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Etiqueta flotante en tiempo real (• MONTURA AVIADOR o • NO ES UNA GAFA)
                        Positioned(
                          top: 26,
                          left: 22,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isLiveRejected
                                  ? const Color(0xD93B1D16)
                                  : const Color(0xCC3C3936),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isLiveRejected
                                        ? const Color(0xFFFF4D4D)
                                        : AljolensPalette.orangeStart,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  liveBannerText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (rejectionDetail.isNotEmpty)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xD92D1E17),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                rejectionDetail,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Sección inferior: "Live feature tags", chips horizontales y botón de captura doble anillo
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Live feature tags',
                        style: TextStyle(
                          color: Color(0xFFE5DFDA),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          scrollDirection: Axis.horizontal,
                          itemCount: liveFeatureTags.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            final tag = liveFeatureTags[i];
                            return GestureDetector(
                              onTap: () => onSelectQuickDemoShape(tag),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color.fromRGBO(
                                      255,
                                      255,
                                      255,
                                      0.45,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Fila inferior con acceso al historial y botón circular naranja con doble anillo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 42),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: onCloseToHistory,
                              icon: const Icon(
                                Icons.grid_view_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              tooltip: 'Historial de Scans',
                            ),
                            GestureDetector(
                              onTap: isProcessing ? null : onCapture,
                              child: Container(
                                width: 74,
                                height: 74,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AljolensPalette.orangeStart,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66FF8C3B),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient:
                                        AljolensPalette.orangeVerticalGradient,
                                  ),
                                  child: isProcessing
                                      ? const Padding(
                                          padding: EdgeInsets.all(18),
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 42),
                          ],
                        ),
                      ),
                    ],
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

/// Pintor del recuadro central con esquinas naranjas brillantes y cuadrícula de tercios
class ScannerReticlePainter extends CustomPainter {
  final bool isRejected;

  const ScannerReticlePainter({this.isRejected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final RRect frameRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );

    // Fondo claro translúcido del visor central
    final Paint innerFill = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.24);
    canvas.drawRRect(frameRRect, innerFill);

    // Cuadrícula de tercios (2 verticales + 2 horizontales)
    final Paint gridPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.38)
      ..strokeWidth = 1.0;

    final double thirdW = size.width / 3.0;
    final double thirdH = size.height / 3.0;

    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(thirdW * i, 0),
        Offset(thirdW * i, size.height),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, thirdH * i),
        Offset(size.width, thirdH * i),
        gridPaint,
      );
    }

    // Esquinas naranjas brillantes con resplandor (glow)
    final Color cornerColor =
        isRejected ? const Color(0xFFFF4D4D) : AljolensPalette.orangeStart;

    final Paint glowPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final Paint solidPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;

    const double r = 28.0;
    const double arm = 54.0;
    final Path cornersPath = Path()
      // Arriba-izquierda
      ..moveTo(0, arm)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(arm, 0)
      // Arriba-derecha
      ..moveTo(size.width - arm, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, arm)
      // Abajo-izquierda
      ..moveTo(0, size.height - arm)
      ..lineTo(0, size.height - r)
      ..quadraticBezierTo(0, size.height, r, size.height)
      ..lineTo(arm, size.height)
      // Abajo-derecha
      ..moveTo(size.width - arm, size.height)
      ..lineTo(size.width - r, size.height)
      ..quadraticBezierTo(
          size.width, size.height, size.width, size.height - r)
      ..lineTo(size.width, size.height - arm);

    canvas.drawPath(cornersPath, glowPaint);
    canvas.drawPath(cornersPath, solidPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerReticlePainter oldDelegate) =>
      oldDelegate.isRejected != isRejected;
}

// ============================================================================
// PANTALLA 3: RESULTADOS DE CLASIFICACIÓN (Diseño Bento + 86.6% MATCH)
// ============================================================================
class BentoResultScreen extends StatelessWidget {
  final ScanHistoryRecord record;
  final List<PredictionItem> allPredictions;
  final VoidCallback onBack;
  final VoidCallback onScanAnother;
  final VoidCallback onOpenHistory;

  const BentoResultScreen({
    super.key,
    required this.record,
    required this.allPredictions,
    required this.onBack,
    required this.onScanAnother,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    final EyewearBentoSpec spec = resolveBentoSpec(record.shapeKey);
    final String matchPct =
        '${(record.confidence * 100).clamp(0.0, 99.9).toStringAsFixed(1)}%';

    return Scaffold(
      backgroundColor: AljolensPalette.creamBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior con flecha atrás y título "Resulta"
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AljolensPalette.textDark,
                      size: 24,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Resulta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AljolensPalette.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onScanAnother,
                    tooltip: 'Nuevo escaneo',
                    icon: const Icon(
                      Icons.center_focus_strong_rounded,
                      color: AljolensPalette.orangeEnd,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Encabezado con porcentaje destacado en grande (ej. 86.6% MATCH)
              Center(
                child: Column(
                  children: [
                    Text(
                      matchPct,
                      style: const TextStyle(
                        color: AljolensPalette.textDark,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'MATCH',
                      style: TextStyle(
                        color: AljolensPalette.orangeStart,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Contenido Bento desplazable
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Fila 1 de la Cuadrícula Bento de 2 columnas
                    Row(
                      children: [
                        Expanded(
                          child: _buildBentoPairCard(
                            topLabel: 'Positura',
                            topValue: spec.posituraCode,
                            bottomLabel: 'Montura',
                            bottomValue: spec.monturaUpper,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildBentoPairCard(
                            topLabel: 'Specs',
                            topValue: spec.specsTop,
                            bottomLabel: spec.curvaturaLabel,
                            bottomValue: record.secondaryShape != null
                                ? 'Afinidad ${record.secondaryShape}'
                                : 'Simetría 1:1',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Fila 2 de la Cuadrícula Bento de 2 columnas
                    Row(
                      children: [
                        Expanded(
                          child: _buildBentoPairCard(
                            topLabel: 'Dino',
                            topValue: spec.dimMm,
                            bottomLabel: 'Gamia',
                            bottomValue: spec.gamaCode,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildBentoPairCard(
                            topLabel: 'Specs',
                            topValue: spec.specsBottom,
                            bottomLabel: 'Comaviate',
                            bottomValue: spec.bridgeMm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tarjeta inferior ancha de categoría / recomendación óptica (High-end)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      decoration: BoxDecoration(
                        color: AljolensPalette.cardWhite,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AljolensPalette.softCardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tipographia',
                            style: TextStyle(
                              color: AljolensPalette.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                spec.categoryTier,
                                style: const TextStyle(
                                  color: AljolensPalette.textDark,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AljolensPalette.creamSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'H=${record.shannonEntropy.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AljolensPalette.orangeEnd,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            spec.opticalRecommendation,
                            style: const TextStyle(
                              color: AljolensPalette.textMuted,
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: spec.idealFaceShapes
                                .map(
                                  (face) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AljolensPalette.creamBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      face,
                                      style: const TextStyle(
                                        color: AljolensPalette.textDark,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Botón inferior en degradado naranja (#FF8C3B a #F26419)
              GestureDetector(
                onTap: onOpenHistory,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AljolensPalette.orangeGradient,
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: AljolensPalette.orangeButtonShadow,
                  ),
                  child: const Text(
                    'Iniciar escaneo / Ver Historial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoPairCard({
    required String topLabel,
    required String topValue,
    required String bottomLabel,
    required String bottomValue,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AljolensPalette.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AljolensPalette.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topLabel,
            style: const TextStyle(
              color: AljolensPalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            topValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AljolensPalette.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            bottomLabel,
            style: const TextStyle(
              color: AljolensPalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bottomValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AljolensPalette.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PANTALLA 4: HISTORIAL DE SCANS Y NAVEGACIÓN (Grid 2 columnas + Buscador)
// ============================================================================
class ScanHistoryScreen extends StatefulWidget {
  final List<ScanHistoryRecord> records;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<ScanHistoryRecord> onOpenDetails;
  final VoidCallback onBackToScanner;

  const ScanHistoryScreen({
    super.key,
    required this.records,
    required this.onToggleFavorite,
    required this.onOpenDetails,
    required this.onBackToScanner,
  });

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _onlyFavorites = false;
  String? _selectedShapeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AljolensPalette.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtrar Historial de Scans',
                        style: TextStyle(
                          color: AljolensPalette.textDark,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _onlyFavorites = false;
                            _selectedShapeFilter = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(
                            color: AljolensPalette.orangeEnd,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AljolensPalette.orangeEnd,
                    title: const Text(
                      'Solo Favoritos ♥',
                      style: TextStyle(
                        color: AljolensPalette.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: _onlyFavorites,
                    onChanged: (val) {
                      setSheetState(() => _onlyFavorites = val);
                      setState(() => _onlyFavorites = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kSnellenBentoCatalog.keys.map((shape) {
                      final bool active = _selectedShapeFilter == shape;
                      return ChoiceChip(
                        label: Text(shape),
                        selected: active,
                        selectedColor: AljolensPalette.orangeStart,
                        labelStyle: TextStyle(
                          color: active
                              ? Colors.white
                              : AljolensPalette.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (sel) {
                          setSheetState(
                            () => _selectedShapeFilter = sel ? shape : null,
                          );
                          setState(
                            () => _selectedShapeFilter = sel ? shape : null,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ScanHistoryRecord> filtered = widget.records.where((r) {
      if (_onlyFavorites && !r.isFavorite) return false;
      if (_selectedShapeFilter != null && r.shapeKey != _selectedShapeFilter) {
        return false;
      }
      if (_query.isNotEmpty) {
        final spec = resolveBentoSpec(r.shapeKey);
        final q = _query.toLowerCase();
        return spec.displayTitle.toLowerCase().contains(q) ||
            spec.catalogSubtitle.toLowerCase().contains(q) ||
            spec.posituraCode.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          // Cabecera "Historial de Scans"
          Row(
            children: [
              IconButton(
                onPressed: widget.onBackToScanner,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AljolensPalette.textDark,
                  size: 24,
                ),
              ),
              const Expanded(
                child: Text(
                  'Historial de Scans',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AljolensPalette.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),

          // Buscador superior ("Buscar") con botón de filtro circular naranja
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AljolensPalette.inputFill,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(
                      color: AljolensPalette.textDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Buscar',
                      hintStyle: TextStyle(
                        color: AljolensPalette.textMuted,
                        fontSize: 13.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AljolensPalette.textMuted,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _openFilterModal,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AljolensPalette.orangeGradient,
                    shape: BoxShape.circle,
                    boxShadow: AljolensPalette.orangeButtonShadow,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid de 2 columnas con tarjetas blancas redondeadas (borderRadius: 22)
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, index) {
                final item = filtered[index];
                final spec = resolveBentoSpec(item.shapeKey);
                final bool hasPhoto = item.imagePath != null &&
                    item.imagePath!.isNotEmpty &&
                    File(item.imagePath!).existsSync();

                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: AljolensPalette.cardWhite,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AljolensPalette.softCardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícono de favorito en corazón naranja arriba a la derecha
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => widget.onToggleFavorite(item.id),
                          child: Icon(
                            item.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: AljolensPalette.orangeEnd,
                            size: 20,
                          ),
                        ),
                      ),

                      // Imagen de la montura (captura local o silueta óptica vectorial)
                      Expanded(
                        child: Center(
                          child: hasPhoto
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(item.imagePath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: CustomPaint(
                                    size: const Size(130, 56),
                                    painter: EyewearSilhouettePainter(
                                      shapeKey: spec.shapeKey,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Marca, nombre de la montura, confianza y precio
                      const Text(
                        'ALJOLENS',
                        style: TextStyle(
                          color: AljolensPalette.textDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${spec.shapeKey} · ${(item.confidence * 100).toStringAsFixed(1)}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AljolensPalette.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spec.priceEur,
                        style: const TextStyle(
                          color: AljolensPalette.textDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Botón naranja "Detalles"
                      GestureDetector(
                        onTap: () => widget.onOpenDetails(item),
                        child: Container(
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AljolensPalette.orangeGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Detalles',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustrador vectorial de las 8 siluetas de gafas para tarjetas sin foto de cámara
class EyewearSilhouettePainter extends CustomPainter {
  final String shapeKey;

  const EyewearSilhouettePainter({required this.shapeKey});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cy = h * 0.52;
    final double lensW = w * 0.36;
    final double lensH = h * 0.62;
    final double leftCx = w * 0.27;
    final double rightCx = w * 0.73;

    final Paint rimPaint = Paint()
      ..color = const Color(0xFF3E2A1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final Paint lensTint = Paint()
      ..color = const Color.fromRGBO(186, 142, 108, 0.22)
      ..style = PaintingStyle.fill;

    final String key = shapeKey.toLowerCase();

    void drawLensPair(RRect leftLens, RRect rightLens) {
      canvas.drawRRect(leftLens, lensTint);
      canvas.drawRRect(rightLens, lensTint);
      canvas.drawRRect(leftLens, rimPaint);
      canvas.drawRRect(rightLens, rimPaint);
    }

    if (key.contains('circular')) {
      final double r = math.min(lensW, lensH) * 0.48;
      canvas.drawCircle(Offset(leftCx, cy), r, lensTint);
      canvas.drawCircle(Offset(rightCx, cy), r, lensTint);
      canvas.drawCircle(Offset(leftCx, cy), r, rimPaint);
      canvas.drawCircle(Offset(rightCx, cy), r, rimPaint);
    } else if (key.contains('oval')) {
      final Rect lRect =
          Rect.fromCenter(center: Offset(leftCx, cy), width: lensW, height: lensH * 0.72);
      final Rect rRect =
          Rect.fromCenter(center: Offset(rightCx, cy), width: lensW, height: lensH * 0.72);
      canvas.drawOval(lRect, lensTint);
      canvas.drawOval(rRect, lensTint);
      canvas.drawOval(lRect, rimPaint);
      canvas.drawOval(rRect, rimPaint);
    } else if (key.contains('rectang')) {
      drawLensPair(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(leftCx, cy),
            width: lensW,
            height: lensH * 0.68,
          ),
          const Radius.circular(6),
        ),
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(rightCx, cy),
            width: lensW,
            height: lensH * 0.68,
          ),
          const Radius.circular(6),
        ),
      );
    } else if (key.contains('browline')) {
      drawLensPair(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(leftCx, cy), width: lensW, height: lensH),
          const Radius.circular(11),
        ),
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(rightCx, cy), width: lensW, height: lensH),
          const Radius.circular(11),
        ),
      );
      final Paint browPaint = Paint()
        ..color = const Color(0xFF231710)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(leftCx - lensW * 0.52, cy - lensH * 0.48),
        Offset(leftCx + lensW * 0.48, cy - lensH * 0.44),
        browPaint,
      );
      canvas.drawLine(
        Offset(rightCx - lensW * 0.48, cy - lensH * 0.44),
        Offset(rightCx + lensW * 0.52, cy - lensH * 0.48),
        browPaint,
      );
    } else {
      // Aviador / Cat eye / Cuadrado / Geométrico
      final Radius rad = key.contains('aviador')
          ? const Radius.circular(16)
          : const Radius.circular(9);
      drawLensPair(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(leftCx, cy), width: lensW, height: lensH),
          rad,
        ),
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(rightCx, cy), width: lensW, height: lensH),
          rad,
        ),
      );
      if (key.contains('aviador')) {
        // Doble puente superior característico de Aviador
        canvas.drawLine(
          Offset(leftCx + lensW * 0.45, cy - lensH * 0.36),
          Offset(rightCx - lensW * 0.45, cy - lensH * 0.36),
          rimPaint,
        );
      }
    }

    // Puente nasal central y varillas laterales
    canvas.drawLine(
      Offset(leftCx + lensW * 0.48, cy - lensH * 0.12),
      Offset(rightCx - lensW * 0.48, cy - lensH * 0.12),
      rimPaint,
    );
    canvas.drawLine(
      Offset(leftCx - lensW * 0.50, cy - lensH * 0.22),
      Offset(w * 0.02, cy - lensH * 0.30),
      rimPaint,
    );
    canvas.drawLine(
      Offset(rightCx + lensW * 0.50, cy - lensH * 0.22),
      Offset(w * 0.98, cy - lensH * 0.30),
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant EyewearSilhouettePainter oldDelegate) =>
      oldDelegate.shapeKey != shapeKey;
}
