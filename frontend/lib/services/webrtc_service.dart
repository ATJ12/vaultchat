import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';

class WebRTCService {
  final MessageService _messageService;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  WebRTCService(this._messageService);

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  Future<void> initialize(String remoteUserId, bool isOffer) async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      // Send ICE candidate via signaling channel (MessageService)
      _messageService.sendMessage(
        recipientUserId: remoteUserId,
        messageText: "PROTOCOL_WEBRTC_ICE:${candidate.toMap().toString()}",
      );
    };

    if (isOffer) {
      _dataChannel = await _peerConnection!.createDataChannel("fileTransfer", RTCDataChannelInit());
      _setupDataChannel();

      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _messageService.sendMessage(
        recipientUserId: remoteUserId,
        messageText: "PROTOCOL_WEBRTC_OFFER:${offer.sdp}",
      );
    } else {
      _peerConnection!.onDataChannel = (channel) {
        _dataChannel = channel;
        _setupDataChannel();
      };
    }
  }

  void _setupDataChannel() {
    _dataChannel?.onMessage = (data) {
      debugPrint('WebRTC: Received data: ${data.text}');
    };
  }

  Future<void> handleOffer(String remoteUserId, String sdp) async {
    await initialize(remoteUserId, false);
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _messageService.sendMessage(
      recipientUserId: remoteUserId,
      messageText: "PROTOCOL_WEBRTC_ANSWER:${answer.sdp}",
    );
  }

  Future<void> handleAnswer(String sdp) async {
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }
}
