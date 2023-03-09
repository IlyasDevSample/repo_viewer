import 'package:dio/dio.dart';

extension DioErrorTypeX on DioError {
  bool get isConnectionError {
    return type == DioErrorType.connectionError;
  }
}