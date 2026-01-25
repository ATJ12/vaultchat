import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';

class UserApi {
  final _client = ApiClient.instance;

  Future<void> registerUser(String userId, String publicKeyPem) async {
    // The backend expects the raw PEM string encoded as base64
    final publicKeyBase64 = base64Encode(utf8.encode(publicKeyPem));
    
    await _client.post('/users/register', data: {
      'user_id': userId,
      'public_key': publicKeyBase64,
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