import 'package:flutter/services.dart';
import 'package:oauth2/oauth2.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;

  GithubAuthenticator(this._credentialsStorage);

  Future<Credentials?> getSignedInCredentials() async {
    try {
      final credentials = await _credentialsStorage.read();
      if (credentials != null) {
        if (credentials.canRefresh && credentials.isExpired) {
          //TODO: Refresh the token
        }
      }
      return credentials;
    } on PlatformException catch (e) {
      print(e);
      return null;
    }
  }

  Future<bool> isSignedIn() async {
    final credentials = await getSignedInCredentials();
    return credentials != null;
  }
}
