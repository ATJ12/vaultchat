import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';

class UserApi {
  final _client = ApiClient.instance;

  Future<void> registerUser({
    required String userId,
    required String publicKeyPem,
    required String signature,
    required String timestamp,
  }) async {
    await _client.post('/users/register', data: {
      'user_id': userId,
      'public_key': publicKeyPem,
      'signature': signature,
      'timestamp': timestamp,
    });
  }

  Future<String> getUserPublicKey(String userId) async {
    final response = await _client.get('/users/$userId/public-key');
    
    final publicKeyBase64 = response.data['public_key'] as String;
    final publicKeyPem = utf8.decode(base64Decode(publicKeyBase64));
    
    return publicKeyPem;
  }

  Future<bool> checkUserExists(String userId) async {
    try {
      await getUserPublicKey(userId);
      return true;
    } catch (e) {
      return false;
    }
  }
}