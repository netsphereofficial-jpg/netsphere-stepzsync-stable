import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class NetworkService extends GetxController {
  static NetworkService get instance => Get.find();
  
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  final RxBool _isConnected = true.obs;
  final RxString _connectionType = 'unknown'.obs;
  
  bool get isConnected => _isConnected.value;
  String get connectionType => _connectionType.value;
  
  Stream<bool> get connectionStream => _isConnected.stream;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }

  Future<void> _initConnectivity() async {
    try {
      List<ConnectivityResult> result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      _isConnected.value = false;
      _connectionType.value = 'unknown';
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> connectivityResults) {
    if (connectivityResults.isEmpty || connectivityResults.contains(ConnectivityResult.none)) {
      _isConnected.value = false;
      _connectionType.value = 'none';
    } else {
      _isConnected.value = true;
      
      if (connectivityResults.contains(ConnectivityResult.wifi)) {
        _connectionType.value = 'wifi';
      } else if (connectivityResults.contains(ConnectivityResult.mobile)) {
        _connectionType.value = 'mobile';
      } else if (connectivityResults.contains(ConnectivityResult.ethernet)) {
        _connectionType.value = 'ethernet';
      } else {
        _connectionType.value = 'other';
      }
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      List<ConnectivityResult> result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isConnected.value;
    } catch (e) {
      return false;
    }
  }
}