import 'package:get/get.dart';

import '../../../routes/route_paths.dart';
import '../../utils/extension/context_extension.dart';
import '../deep_link/app_link_service.dart';
import 'verification_prompt.dart';

class PostAuthNavigator {
  static Future<void> goHome() async {
    final deepLinkService = Get.find<DeepLinkService>();
    // A pending live link only opens for a fully verified user; otherwise it
    // stays pending (opened after approval via goHome()) and main nav shows
    // the verification popup.
    if (deepLinkService.pendingLiveId != null &&
        await VerificationGate.ensureVerified(showPopup: false)) {
      await deepLinkService.handlePostLoginRedirect();
    } else {
      Get.offAllNamed(RoutePaths.mainNav);
    }
  }

  static void goWelcomeFundingMum() {
    Get.offAllNamed(RoutePaths.welcomeFundingMum);
  }
}

class VerificationGate {
  /// true once the user is confirmed fully verified
  /// (isIdVerified && ageVerification == verified && genderStatus == verified).
  /// Reactive so main nav can lock/unlock its content.
  static final verified_ =
      false.obs; // in-memory; resets on app restart / sign-out
  static bool get verified => verified_.value;
  static set verified(bool v) => verified_.value = v;

  static bool get isRequired => true; // TODO: user vs expert

  /// For flows that end in the app (login, splash, subscription, finish-profile).
  /// Never blocks — the verification popup is shown once main nav opens.
  static Future<void> routeAfterAuth({bool isFromFreePlan = false}) async {
    return isFromFreePlan
        ? PostAuthNavigator.goWelcomeFundingMum()
        : PostAuthNavigator.goHome();
  }

  /// Feature lock for flows that open a specific screen (deep link,
  /// notification tap). Returns false and shows the matching popup when the
  /// user isn't fully verified.
  static Future<bool> ensureVerified({bool showPopup = true}) async {
    if (!isRequired || verified) return true;

    VerificationCheck check;
    try {
      check = await VerificationPrompt.resolve();
    } catch (_) {
      check = (ok: false, popup: null);
    }

    if (check.ok && check.popup == null) {
      verified = true;
      return true;
    }

    if (showPopup) {
      if (check.ok) {
        VerificationPrompt.show(check.popup!);
      } else {
        Snack.showError(
          "Couldn't check your verification status. Please try again.",
        );
      }
    }
    return false;
  }
}
