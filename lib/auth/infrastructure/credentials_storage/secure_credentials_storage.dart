
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oauth2/src/credentials.dart';
import 'credentials_storage.dart';

class SecureCredentialsStorage implements CredentialsStorage {
  static const _key = "oauth2_credentials";
  Credentials? _credentials;
  final FlutterSecureStorage _storage;

  SecureCredentialsStorage(this._storage);

  @override
  Future<Credentials?> read() async {
    if (_credentials != null) {
      return _credentials;
    }
    final json = await _storage.read(key: _key);
    if (json == null) {
      return null;
    }
    try {
      return _credentials = Credentials.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> save(Credentials credentials) async {
    _credentials = credentials;
    await _storage.write(key: _key, value: credentials.toJson());
  }
  @override
  Future<void> clear() async {
    _credentials = null;
    await _storage.delete(key: _key);
  }


}