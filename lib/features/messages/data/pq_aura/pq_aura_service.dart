// Platform-conditional export for PQ-Aura encryption service.
//
// Platform        | Library condition         | File
// --------------- | ------------------------- | ---------------------------
// Web (browser)   | dart.library.js_interop   | pq_aura_service_web.dart
// Native (FFI)    | dart.library.io           | pq_aura_service_io.dart
// Unknown/stub    | (default)                 | pq_aura_service_stub.dart
export 'pq_aura_service_stub.dart'
    if (dart.library.js_interop) 'pq_aura_service_web.dart'
    if (dart.library.io) 'pq_aura_service_io.dart';
