import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus {
  unknown,
  noIdentity,
  ready,
}

class AuthState extends StateNotifier<AuthStatus> {
  AuthState() : super(AuthStatus.unknown);

  void noIdentity() => state = AuthStatus.noIdentity;
  void ready() => state = AuthStatus.ready;
}

final authStateProvider =
    StateNotifierProvider<AuthState, AuthStatus>((ref) {
  return AuthState();
});

extension WidgetRefExtension on WidgetRef {
  void listenOnce<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener,
  ) {
    listen(provider, (previous, next) {
      listener(previous, next);
      // Remove the listener after first call
    });
  }
}
