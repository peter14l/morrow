
class RazorpayConfig {
  RazorpayConfig._();

  static String get keyId {
    const fromEnv = String.fromEnvironment('RAZORPAY_KEY_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '';
  }

  static String get monthlyPlanId {
    const fromEnv = String.fromEnvironment('RAZORPAY_MONTHLY_PLAN_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '';
  }

  static String get annualPlanId {
    const fromEnv = String.fromEnvironment('RAZORPAY_ANNUAL_PLAN_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '';
  }
}
