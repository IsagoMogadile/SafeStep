import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide reactive online/offline signal, matching [ThemeController]'s
/// `ValueNotifier` singleton pattern. [ConnectivityService.hasConnection]
/// (a one-shot check) is still used for one-off decisions like "is SOS
/// online right now"; this is for anything that needs to *react* the
/// moment a connection comes back — greying out online-only tiles and
/// kicking off [SyncManager].
class ConnectivityController extends ValueNotifier<bool> {
  ConnectivityController._() : super(true);

  static final instance = ConnectivityController._();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Safe to call more than once (e.g. app start and again after a
  /// student logs in) — later calls are a no-op if already listening.
  Future<void> init() async {
    if (_subscription != null) return;
    final initial = await Connectivity().checkConnectivity();
    value = initial.any((r) => r != ConnectivityResult.none);
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      value = results.any((r) => r != ConnectivityResult.none);
    });
  }

  bool get isOnline => value;
}
