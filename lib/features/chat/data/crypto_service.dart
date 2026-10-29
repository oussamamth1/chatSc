import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Encrypts/decrypts chat messages with a shared code the two users agree on
/// out-of-band. The server never sees the code or the plaintext — only the
/// base64 ciphertext this class produces. Works on raw bytes so it covers
/// text, images and voice notes alike.
class CryptoService {
  final _aes = AesGcm.with256bits();

  /// Derives a stable AES-256 key from the shared code. The conversation id
  /// is used as the PBKDF2 salt so both sides derive the identical key
  /// without ever exchanging a salt over the network.
  Future<SecretKey> deriveKey({required String code, required String conversationId}) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(
      password: code,
      nonce: utf8.encode(conversationId),
    );
  }

  /// Returns base64(nonce + ciphertext + mac), safe to send over the wire.
  Future<String> encryptBytes(List<int> bytes, SecretKey key) async {
    final secretBox = await _aes.encrypt(bytes, secretKey: key);
    final packed = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return base64.encode(packed);
  }

  /// Returns null if [payload] can't be decrypted with [key] (wrong shared code).
  Future<Uint8List?> decryptBytes(String payload, SecretKey key) async {
    try {
      final bytes = base64.decode(payload);
      const nonceLength = 12;
      const macLength = 16;
      final nonce = bytes.sublist(0, nonceLength);
      final mac = bytes.sublist(bytes.length - macLength);
      final cipherText = bytes.sublist(nonceLength, bytes.length - macLength);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final clear = await _aes.decrypt(secretBox, secretKey: key);
      return Uint8List.fromList(clear);
    } catch (_) {
      return null;
    }
  }

  Future<String> encrypt(String plaintext, SecretKey key) {
    return encryptBytes(utf8.encode(plaintext), key);
  }

  /// Returns null if [payload] can't be decrypted with [key] (wrong shared code).
  Future<String?> decrypt(String payload, SecretKey key) async {
    final bytes = await decryptBytes(payload, key);
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
