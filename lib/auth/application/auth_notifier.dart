import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../domain/auth_failure.dart';
import '../infrastructure/github_authenticator.dart';

part 'auth_notifier.freezed.dart';

@freezed
class AuthState  with _$AuthState {
  const AuthState._();
  const factory AuthState.initial() = _Initial;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.authenticated() = _Authenticated;
  const factory AuthState.failure(AuthFailure failure) = _Failure;
}

typedef AuthUriCallbackFn = Future<Uri> Function(Uri authorizationUrl);

class AuthNotifier extends StateNotifier<AuthState> {
  GithubAuthenticator _authenticator;
  AuthNotifier(this._authenticator) : super(const AuthState.initial());

  Future<void> checkAndUpdateAuthState() async {
    final isSignedIn = await _authenticator.isSignedIn();
    if (isSignedIn) {
      state = const AuthState.authenticated();
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> signIn(AuthUriCallbackFn authorizationCallBack) async {
    final grant = _authenticator.createGrant();
    final authorizationUrl = _authenticator.getAuthorizationUrl(grant);
    final redirectUrl = await authorizationCallBack(authorizationUrl);
    final leftOrRight = await _authenticator.handleAuthorizationResponse(redirectUrl.queryParameters, grant);
    leftOrRight.fold(
      (l) => state = AuthState.failure(l),
      (r) => state = const AuthState.authenticated(),
    );
    grant.close();
  }

  Future<void> signOut() async {
    final leftOrRight = await _authenticator.signOut();
    leftOrRight.fold(
      (l) => state = AuthState.failure(l),
      (r) => state = const AuthState.unauthenticated(),
    );
  }
}
