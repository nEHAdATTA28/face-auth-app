import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/prediction_service.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  late AnimationController _scanController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initCamera();
  }

  // 📸 Initialize Camera
  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller?.initialize();
    if (mounted) setState(() => _isCameraReady = true);
  }

  // 🔄 SWITCH CAMERA (Front/Back) - This is the magic function!
  Future<void> _switchCamera() async {
    if (_controller == null) return;
    final cameras = await availableCameras();
    if (cameras.length < 2) {
      // If only one camera, just show a quick feedback (optional)
      return;
    }
    final currentLens = _controller!.description.lensDirection;
    final newLens = currentLens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final newCamera = cameras.firstWhere(
      (c) => c.lensDirection == newLens,
      orElse: () => cameras.first,
    );
    await _controller?.dispose();
    _controller = CameraController(newCamera, ResolutionPreset.high);
    await _controller?.initialize();
    if (mounted) setState(() {});
  }

  // 📸 Capture and Predict
  Future<void> _captureAndPredict() async {
    if (_controller == null || !_isCameraReady || _isProcessing) return;
    try {
      final XFile image = await _controller!.takePicture();
      await _processImage(image);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture the image. Please try again.')),
        );
      }
    }
  }

  Future<void> _pickAndPredict() async {
    if (_isProcessing) return;
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) await _processImage(image);
  }

  Future<void> _processImage(XFile image) async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await image.readAsBytes();
      final result = await PredictionService.predict(bytes);
      if (!mounted) return;
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ResultScreen(
            imageBytes: bytes,
            predictedClass: result.appClass,
            confidence: result.confidence,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image classification failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E1A), Color(0xFF1A1A3A), Color(0xFF2D1045)],
          ),
        ),
        child: Stack(
          children: [
            // Camera preview
            if (_isCameraReady && _controller != null)
              CameraPreview(_controller!)
            else
              const Center(child: CircularProgressIndicator()),
            
            // Glass overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // 🟢 Top Bar: LIVE indicator + FLIP button + Security
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E5FF),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Color(0xFF00E5FF), blurRadius: 10),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'LIVE SCAN',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // 🔄 FLIP CAMERA BUTTON (Glowing Neon)
                            GestureDetector(
                              onTap: _switchCamera,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00E5FF).withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.flip_camera_ios,
                                  color: Color(0xFF00E5FF),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.security, color: Color(0xFF00E5FF), size: 24),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    
                    // 🎯 Neon Face Frame (With animated scan line)
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: CustomPaint(
                              painter: NeonFramePainter(animation: _scanController),
                            ),
                          ),
                          // Subtle scan line moving down
                          Positioned(
                            top: 40 + (200 * _scanController.value),
                            child: Container(
                              width: 200,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.transparent, Color(0xFF00E5FF), Colors.transparent],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    
                    // 🔘 Capture Button with Pulsing Glow
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF).withOpacity(0.8),
                                        blurRadius: 30 * (1 + _scanController.value * 0.5),
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                                FloatingActionButton(
                                  heroTag: 'capture',
                                  onPressed: _isProcessing ? null : _captureAndPredict,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child: _isProcessing
                                      ? const SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt, color: Colors.white, size: 35),
                                ),
                              ],
                            ),
                            const SizedBox(width: 32),
                            FloatingActionButton(
                              heroTag: 'upload',
                              onPressed: _isProcessing ? null : _pickAndPredict,
                              backgroundColor: const Color(0xFF202A4A),
                              child: const Icon(Icons.upload_file, color: Color(0xFF00E5FF)),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isProcessing ? 'PROCESSING...' : 'CAPTURE OR UPLOAD IMAGE',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanController.dispose();
    super.dispose();
  }
}

// 🎨 Custom Painter for the Neon Frame
class NeonFramePainter extends CustomPainter {
  final Animation<double> animation;
  NeonFramePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.7 + 0.3 * animation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);

    final rect = Rect.fromLTWH(20, 20, size.width - 40, size.height - 40);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(rrect, paint);

    // Corner neon brackets
    final cornerPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const c = 20.0;
    // Top left
    canvas.drawPath(Path()..moveTo(20, 20 + c)..lineTo(20, 20)..lineTo(20 + c, 20), cornerPaint);
    // Top right
    canvas.drawPath(Path()..moveTo(size.width - 20 - c, 20)..lineTo(size.width - 20, 20)..lineTo(size.width - 20, 20 + c), cornerPaint);
    // Bottom left
    canvas.drawPath(Path()..moveTo(20, size.height - 20 - c)..lineTo(20, size.height - 20)..lineTo(20 + c, size.height - 20), cornerPaint);
    // Bottom right
    canvas.drawPath(Path()..moveTo(size.width - 20 - c, size.height - 20)..lineTo(size.width - 20, size.height - 20)..lineTo(size.width - 20, size.height - 20 - c), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
