/// Bluetooth access — the implementation is picked at compile time:
///
/// - mobile / desktop  -> `ble_service_mobile.dart` (flutter_blue_plus):
///   a real continuous scan that feeds a live device list.
/// - web               -> `ble_service_web.dart` (flutter_web_bluetooth):
///   the browser's own device-chooser popup.
///
/// Both expose the same `BleService` API, so callers never branch on package.
library;

export 'ble_service_mobile.dart'
    if (dart.library.js_interop) 'ble_service_web.dart';
