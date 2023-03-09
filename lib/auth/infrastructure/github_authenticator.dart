import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:oauth2/oauth2.dart';
import 'package:repo_viewer/auth/domain/auth_failure.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credentials_storage.dart';
import 'package:repo_viewer/core/infrastructure/dio_extensions.dart';
import '../../core/shared/encoders.dart';
import 'package:http/http.dart' as http;


// this class is used to override the default http client on the oauth2 package to add the "Accept" header
// because the default http client doesn't add this header
class GithubOauthHttpClient extends http.BaseClient {
  final httpClient = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept'] = "application/json";
    return httpClient.send(request);
  }
}

class GithubAuthenticator {
  final CredentialsStorage _credentialsStorage;
  final Dio _dio;

  static const clientId = "d561edcb89b66fb32368";
  static const clientSecret = "5251591c45f19e6fba411cba97b713fec3f2bb0b";
  static const scopes = ["repo", "user"];

  // we are not using const keyword here because Uri.parse is not a const constructor
  static final authorizationEndpoint =
  Uri.parse("https://github.com/login/oauth/authorize");
  static final tokenEndpoint =
  Uri.parse("https://github.com/login/oauth/access_token");
  static final revocationEndpoint = Uri.parse(
      "https://api.github.com/applications/$clientId/token");

  // for the web version, this should be the same as the one in the github app
  static final redirectUrl = Uri.parse("http://localhost:3000/callback");

  GithubAuthenticator(this._credentialsStorage, this._dio);

  Future<Credentials?> getSignedInCredentials() async {
    try {
      final credentials = await _credentialsStorage.read();
      if (credentials != null) {
        if (credentials.canRefresh && credentials.isExpired) {
          //Refresh the token
          final leftOrRight = await refresh(credentials);
          return leftOrRight.fold(
                (l) => null,
                (r) => r,
          );
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

  AuthorizationCodeGrant createGrant() {
    return AuthorizationCodeGrant(
      clientId,
      authorizationEndpoint,
      tokenEndpoint,
      secret: clientSecret,
      httpClient: GithubOauthHttpClient(),
    );
  }

  Uri getAuthorizationUrl(AuthorizationCodeGrant grant) {
    return grant.getAuthorizationUrl(redirectUrl, scopes: scopes);
  }

  // "Unit" is a type that represents a value that is not used, it's like using "void" in dart
  // it just because we are using 'Either' type from dartz package
  Future<Either<AuthFailure, Unit>> handleAuthorizationResponse(
      Map<String, String> queryParameters,
      AuthorizationCodeGrant grant,) async {
    try {
      // this method "handleAuthorizationResponse" is called when the user
      // is redirected back to the app after signing in
      // we need to get the code from the query parameters with the key "code"
      // and then use this method to get the access token from the code "queryParameters['code']"
      final httpClient = await grant.handleAuthorizationResponse(queryParameters);
      // we need to save the credentials in the storage
      final credentials = httpClient.credentials;

      await _credentialsStorage.save(credentials);
      return right(unit);
    } on FormatException {
      return left(const AuthFailure.server());
    } on AuthorizationException catch (e) {
      return left(AuthFailure.server('${e.error}: ${e.description}'));
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }

  Future<Either<AuthFailure, Unit>> signOut() async {
    try {
      try {
        _dio.deleteUri(
          revocationEndpoint,
          data: {
            "access_token": (await getSignedInCredentials())!.accessToken,
          },
          options: Options(
            headers: {
              "Authorization": "Basic ${stringToBase64.encode(
                  "$clientId:$clientSecret")}",
            },
          ),
        );
      }on DioError catch (e){
        if(e.isConnectionError){
        // TODO: Handle this case. when the user is offline
        }else{
          rethrow;
        }
      }
      await _credentialsStorage.clear();
      return right(unit);
    } on PlatformException {
      return left(const AuthFailure.storage());
    }
  }


  Future<Either<AuthFailure, Credentials>> refresh(Credentials credentials) async{
    try{
      final refreshedCredentials = await credentials.refresh(
        httpClient: GithubOauthHttpClient(),
        identifier: clientId,
        secret: clientSecret,
      );
      await _credentialsStorage.save(refreshedCredentials);
      return right(refreshedCredentials);
    }on PlatformException {
      return left(const AuthFailure.storage());
    }on FormatException {
      return left(const AuthFailure.server());
    }on AuthorizationException catch (e) {
      return left(AuthFailure.server('${e.error}: ${e.description}'));
    }


  }


}





