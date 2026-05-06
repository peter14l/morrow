import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

void initSqlite() {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

void initSqliteOverride() {
  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, () {
      try {
        return DynamicLibrary.open('sqlite3.dll');
      } catch (e) {
        debugPrint('Sqlite3 override failed: $e');
        return DynamicLibrary.process();
      }
    });
  }
}
