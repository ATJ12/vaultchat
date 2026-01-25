import 'api_client.dart';

class RoomApi {
  final _client = ApiClient.instance;

  Future<void> createRoom({
    required String user1Id,
    required String user2Id,
    required String roomCode,
  }) async {
    await _client.post('/rooms/create', data: {
      'user1_id': user1Id,
      'user2_id': user2Id,
      'room_code': roomCode,
    });
  }

  Future<bool> joinRoom({
    required String user1Id,
    required String user2Id,
    required String roomCode,
  }) async {
    try {
      await _client.post('/rooms/join', data: {
        'user1_id': user1Id,
        'user2_id': user2Id,
        'room_code': roomCode,
      });
      return true;
    } catch (e) {
      print('Join room failed: $e');
      return false;
    }
  }
}