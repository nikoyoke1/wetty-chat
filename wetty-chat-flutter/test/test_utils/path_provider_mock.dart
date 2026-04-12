import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Future<void> setUpPathProviderMock() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final root = await Directory.systemTemp.createTemp('wetty-cache-test');
  final temporary = Directory('${root.path}/tmp')..createSync(recursive: true);
  final support = Directory('${root.path}/support')
    ..createSync(recursive: true);
  final documents = Directory('${root.path}/documents')
    ..createSync(recursive: true);
  final cache = Directory('${root.path}/cache')..createSync(recursive: true);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        return switch (call.method) {
          'getTemporaryDirectory' => temporary.path,
          'getApplicationSupportDirectory' => support.path,
          'getApplicationDocumentsDirectory' => documents.path,
          'getApplicationCacheDirectory' => cache.path,
          _ => temporary.path,
        };
      });
}

Future<void> tearDownPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, null);
  return Future<void>.value();
}
