// Application information and configuration constants

import 'dart:io';

const String baseUrl = "https://api.wemama.app";
// const String baseUrl = "https://k85v0kkf-8005.inc1.devtunnels.ms";
// const String baseUrl = "https://jpb8m13w-8005.inc1.devtunnels.ms";

const String appName = "We Mama";

const String appVersion = "1.0.0";
const String buildNumber = "1";

const String routeInitial = '/';

const String googleSigninKey =
    "58:4B:FE:3E:4D:C2:84:26:C6:FF:14:4B:70:68:97:C3:BA:2B:7D:24";

final revenueCatPublicKey = Platform.isAndroid
    ? "appl_STntrZPpJhMBcEgBCteOrPfkgoK"
    : "appl_STntrZPpJhMBcEgBCteOrPfkgoK";

// SubscriptionConstants.entitlementId

class SubscriptionConstants {
  static const entitlementId = "premium_monthly";
}
