import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService extends ChangeNotifier {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;
  RazorpayService._internal();

  Razorpay? _razorpay;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  PaymentSuccessResponse? _lastSuccessResponse;
  PaymentFailureResponse? _lastFailureResponse;
  ExternalWalletResponse? _lastWalletResponse;

  PaymentSuccessResponse? get lastSuccessResponse => _lastSuccessResponse;
  PaymentFailureResponse? get lastFailureResponse => _lastFailureResponse;
  ExternalWalletResponse? get lastWalletResponse => _lastWalletResponse;

  void init() {
    if (_isInitialized) return;
    try {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      _isInitialized = true;
      debugPrint('RazorpayService initialized');
    } catch (e) {
      debugPrint('RazorpayService initialization failed: $e');
      _isInitialized = false;
    }
  }

  void open(Map<String, dynamic> options) {
    if (!_isInitialized || _razorpay == null) {
      init();
    }

    if (_razorpay != null) {
      _lastSuccessResponse = null;
      _lastFailureResponse = null;
      _lastWalletResponse = null;
      _razorpay!.open(options);
    } else {
      throw Exception('Razorpay SDK not initialized');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _lastSuccessResponse = response;
    notifyListeners();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _lastFailureResponse = response;
    notifyListeners();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _lastWalletResponse = response;
    notifyListeners();
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }
}
