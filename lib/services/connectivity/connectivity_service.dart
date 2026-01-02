import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus {
  online,
  offline,
}

class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _controller =
      StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get connectionStream => _controller.stream;

  // Initialize monitoring
  void initialize() {
    // Check initial status
    _checkStatus();

    // Listen to changes
    _connectivity.onConnectivityChanged.listen((results) {
      _checkStatus(results);
    });
  }

  Future<void> _checkStatus([List<ConnectivityResult>? results]) async {
    bool hasConnection = false;
    
    // If results provided, check if any is NOT none
    var currentResults = results ?? await _connectivity.checkConnectivity();
    
    // Basic check: is WiFi or Mobile connected?
    bool isConnectedToNetwork = currentResults.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet);

    if (isConnectedToNetwork) {
      // Deep check: can we actually reach Google DNS?
      try {
        final result = await InternetAddress.lookup('8.8.8.8');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          hasConnection = true;
        }
      } on SocketException catch (_) {
        hasConnection = false;
      }
    }

    _controller.add(hasConnection ? ConnectionStatus.online : ConnectionStatus.offline);
  }

  void dispose() {
    _controller.close();
  }
}
