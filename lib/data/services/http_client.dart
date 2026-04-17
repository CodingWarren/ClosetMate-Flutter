import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 创建一个在 Debug 模式下跳过 SSL 证书验证的 HTTP 客户端。
///
/// 仅用于开发调试，Release 版本使用标准客户端。
http.Client createHttpClient() {
  // ignore: do_not_use_environment
  const isDebug = bool.fromEnvironment('dart.vm.product') == false;

  if (isDebug) {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  return http.Client();
}
