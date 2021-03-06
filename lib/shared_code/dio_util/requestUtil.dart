import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:layout/base/base_resp.dart';
import 'package:layout/base/common/define_service_api.dart';
import 'package:layout/shared_code/materials/constant.dart';
import 'package:layout/shared_code/method/constants.dart';
import 'package:layout/shared_preferences/shared_preferences.dart';
import 'dart:developer';

class RequestUtil {
  static final RequestUtil _instance = RequestUtil._internal();
  static const String TAG = 'DIO';

  // ignore: sort_constructors_first
  factory RequestUtil() => _instance;

  static bool _isDebug = false;

  static void openDebug() {
    _isDebug = true;
  }

  Dio dio;

  // ignore: sort_constructors_first
  RequestUtil._internal() {
    final options = BaseOptions(
      baseUrl: ovEnfieldServiceUrl,
      connectTimeout: 15000,
      receiveTimeout: 10000,
      headers: {},
      contentType: 'application/json',
      responseType: ResponseType.json,
    );

    dio = Dio(options);

    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options) {
      if (_isDebug) {
        log(
            'DIO REQUEST[${options?.method}] => URL: ${ovEnfieldServiceUrl + options?.path}');
      }
      return options;
    }, onResponse: (response) {
      if (_isDebug) {
        log(
            'DIO RESPONSE[${response?.statusCode}] => PATH: ${response?.request?.path}');
      }
      return response;
    }, onError: (e) {
      if (_isDebug) {
        log(
            'DIO ERROR[${e?.response?.statusCode}] => PATH: ${e?.request?.path}');
      }
      return createErrorEntity(e);
    }));
  }

  // Get Token
  Future getAuthorizationHeader() async {
    return await SPref.instance.get(SPrefCache.KEY_ACCESS_TOKEN);
  }

  Future addOptions(Options options) async{
    final requestOptions = options ?? Options();
    final token = await SPref.instance.get(SPrefCache.KEY_ACCESS_TOKEN);
    if (token != null) {
      requestOptions.headers['content-type'] = 'application/json';
      requestOptions.headers['Authorization'] = 'Bearer $token';
    }

    return requestOptions;
  }

  // Get
  Future get<T>(
      String path, {
        params,
        Options options,
      }) async {
    try {
      final response =
      await dio.get(path, queryParameters: params, options: await addOptions(options));
      _printHttpLog(response);
      return handleResponse<T>(response);
    } on DioError catch (e) {
      log('$TAG ${e.toString()}');
      return BaseResponse(false, createErrorEntity(e).code, createErrorEntity(e).message, null);
    }
  }

  // Post
  Future post<T>(String path, {params, Options options}) async {
    log('$TAG params $params');
    try {
      final response =
      await dio.post(path, data: params, options: await addOptions(options));
      _printHttpLog(response);
      return handleResponse<T>(response);
    } on DioError catch (e) {
      log('$TAG ${e.toString()}');
      return BaseResponse(false, createErrorEntity(e).code, createErrorEntity(e).message, null);
    }
  }

  // Put
  Future put<T>(String path, {params, Options options}) async {
    try {
      final response = await dio.put(path, data: params, options: await addOptions(options));
      _printHttpLog(response);
      return handleResponse<T>(response);
    } on DioError catch (e) {
      log('$TAG ${e.toString()}');
      return BaseResponse(false, createErrorEntity(e).code, createErrorEntity(e).message, null);
    }
  }

  BaseResponse<T> handleResponse<T>(Response response) {
    const _statusKey = 'Status';
    const _codeKey = 'Code';
    const _dataKey = 'Data';

    bool _status;
    int _code;
    T _data;

    if (response.statusCode == HttpStatus.ok ||
        response.statusCode == HttpStatus.created) {
      try {
        if (response.data is Map) {
          _status = response.data[_statusKey];
          _code = (response.data[_codeKey] is String)
              ? int.tryParse(response.data[_codeKey])
              : response.data[_codeKey];
          _data = _status ? response.data[_dataKey] : null;
        } else {
          final _dataMap = _decodeData(response);
          _status = response.data[_statusKey];
          _code = (_dataMap[_codeKey] is String)
              ? int.tryParse(_dataMap[_codeKey])
              : _dataMap[_codeKey];
          _data = _status ? _dataMap[_dataKey] : null;
        }
        return BaseResponse(_status, _code, Constant.SUCCESS, _data);
      } catch (e) {
        log('$TAG ${e.toString()}');
        return null;
      }
    }
  }

  Map<String, dynamic> _decodeData(Response response) {
    if (response == null ||
        response.data == null ||
        response.data.toString().isEmpty) {
      return {};
    }
    return json.decode(response.data.toString());
  }

  void _printHttpLog(Response response) {
    if (!_isDebug) {
      return;
    }
    try {
      log(
          '----------------$TAG RESPONSE---------------- +\n[data] => ${response.toString()} \n[statusCode] => ${response.statusCode.toString()} \n[requestData] => ${response.request.data.toString()}');
      log('${response.request.data.toString()}');
    } catch (ex) {
      log('$TAG Log' ' error......');
    }
  }

  Future<bool> _checkConnectionAddress() async {
    try {
      final address = '${operatorServiceUrl}swagger/';
      final uri = Uri.parse(address);

      final client = HttpClient();
      final request = await client.getUrl(uri);
      // ignore: unused_local_variable
      final response = await request.close();
      return true;
    } on SocketException catch (_) {
      return false;
    }
  }
}

ErrorEntity createErrorEntity(DioError error) {
  switch (error.type) {
    case DioErrorType.CANCEL:
      {
        return ErrorEntity(code: -1, message: 'Y??u c???u h???y b???');
      }
      break;
    case DioErrorType.CONNECT_TIMEOUT:
      {
        return ErrorEntity(code: -1, message: 'K???t n???i qu?? h???n');
      }
      break;
    case DioErrorType.SEND_TIMEOUT:
      {
        return ErrorEntity(code: -1, message: 'Y??u c???u ???? h???t th???i gian ch???');
      }
      break;
    case DioErrorType.RECEIVE_TIMEOUT:
      {
        return ErrorEntity(code: -1, message: '???? h???t th???i gian nh???n ph???n h???i');
      }
      break;
    case DioErrorType.RESPONSE:
      {
        try {
          final errCode = error.response.statusCode;
          switch (errCode) {
            case 400:
              {
                return ErrorEntity(
                    code: errCode, message: 'Y??u c???u l???i c?? ph??p');
              }
              break;
            case 401:
              {
                return ErrorEntity(code: errCode, message: 'Quy???n b??? t??? ch???i');
              }
              break;
            case 403:
              {
                return ErrorEntity(
                    code: errCode, message: 'M??y ch??? t??? ch???i th???c thi');
              }
              break;
            case 404:
              {
                return ErrorEntity(
                    code: errCode, message: 'Kh??ng th??? k???t n???i ?????n m??y ch???');
              }
              break;
            case 405:
              {
                return ErrorEntity(
                    code: errCode, message: 'Ph????ng th???c y??u c???u b??? c???m');
              }
              break;
            case 500:
              {
                return ErrorEntity(
                    code: errCode, message: 'M??y ch??? l???i n???i b???');
              }
              break;
            case 502:
              {
                return ErrorEntity(
                    code: errCode, message: 'Y??u c???u kh??ng h???p l???');
              }
              break;
            case 503:
              {
                return ErrorEntity(code: errCode, message: 'M??y ch??? ???? s???p');
              }
              break;
            case 505:
              {
                return ErrorEntity(
                    code: errCode,
                    message: 'Kh??ng h??? tr??? y??u c???u giao th???c HTTP');
              }
              break;
            default:
              {
                return ErrorEntity(
                    code: errCode, message: error.response.statusMessage);
              }
          }
        } on Exception catch (_) {
          return ErrorEntity(code: -1, message: 'L???i kh??ng x??c ?????nh');
        }
      }
      break;
    default:
      {
        return ErrorEntity(code: -1, message: error.message);
      }
  }
}

class ErrorEntity implements Exception {
  int code;
  String message;

  // ignore: sort_constructors_first
  ErrorEntity({this.code, this.message});

  @override
  String toString() {
    return (message == null) ? 'L???i kh??ng x??c ?????nh' : message;
  }
}
