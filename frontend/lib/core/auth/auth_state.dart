enum AuthStatus {
  initializing,
  noIdentity,
  ready,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.userId,
    this.errorMessage,
  });

  const AuthState.initializing()
      : status = AuthStatus.initializing,
        userId = null,
        errorMessage = null;

  const AuthState.noIdentity()
      : status = AuthStatus.noIdentity,
        userId = null,
        errorMessage = null;

  const AuthState.ready(this.userId)
      : status = AuthStatus.ready,
        errorMessage = null;

  const AuthState.error(this.errorMessage)
      : status = AuthStatus.error,
        userId = null;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}