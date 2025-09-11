// api_client.dart
export 'api_client_stub.dart'
    if (dart.library.io) 'api_client_mobile.dart'
    if (dart.library.html) 'api_client_web.dart';