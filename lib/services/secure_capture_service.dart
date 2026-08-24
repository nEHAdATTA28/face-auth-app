import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Encrypts only a picture captured by this app, in private app storage.
class SecureCaptureService {
  static const _storage = FlutterSecureStorage();
  static final _algorithm = AesGcm.with256bits();
  static final _random = Random.secure();

  static Future<String> encryptCapturedImage(File source) async {
    final plaintext = await source.readAsBytes();
    final key = await _algorithm.newSecretKey();
    final nonce = List<int>.generate(12, (_) => _random.nextInt(256));
    final box = await _algorithm.encrypt(plaintext, secretKey: key, nonce: nonce);
    final directory = await getApplicationDocumentsDirectory();
    final outputDirectory = Directory('${directory.path}/encrypted_captures');
    await outputDirectory.create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final encryptedFile = File('${outputDirectory.path}/capture_$id.jpg.aesgcm');
    await encryptedFile.writeAsBytes(<int>[...box.nonce, ...box.cipherText, ...box.mac.bytes]);
    await _storage.write(key: 'capture_key_$id', value: _toHex(await key.extractBytes()));
    await source.delete();
    return encryptedFile.path;
  }

  /// Encrypts only the app-created demo file, never a user-selected device file.
  static Future<String> encryptAppDemoPimpFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final demoDirectory = Directory('${directory.path}/class_b_demo');
    await demoDirectory.create(recursive: true);

    final plainFile = File('${demoDirectory.path}/pimp.txt');
    final encryptedFile = File('${plainFile.path}.aesgcm');

    if (await encryptedFile.exists()) return encryptedFile.path;

    if (!await plainFile.exists()) {
      await plainFile.writeAsString(
        'This is an app-owned encryption demonstration file.\n'
        'Created after a class_B classification.\n',
      );
    }

    final key = await _algorithm.newSecretKey();
    final nonce = List<int>.generate(12, (_) => _random.nextInt(256));
    final box = await _algorithm.encrypt(
      await plainFile.readAsBytes(),
      secretKey: key,
      nonce: nonce,
    );

    await encryptedFile.writeAsBytes(<int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    await _storage.write(
      key: 'class_b_demo_pimp_key',
      value: _toHex(await key.extractBytes()),
    );
    await plainFile.delete();
    return encryptedFile.path;
  }

  static String _toHex(List<int> bytes) => bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
