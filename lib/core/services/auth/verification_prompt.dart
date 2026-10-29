import 'dart:async';

import '../../../app/helper_widgets_export.dart';
import '../../../features/main_tabs/home/sub_feature/profile/controller/profile_controller.dart';
import '../../../features/main_tabs/home/sub_feature/profile/model/profile_model.dart';
import '../../../features/verification/model/verification_model.dart';
import '../../../features/verification/service/verification_service.dart';
import '../../components/app_ui/popup_widgets/verification_status_popup.dart';
import '../../components/ui/dialogs/popups.dart';
import '../../local/app_storage.dart';
import '../profile/profile_info_service.dart';
import 'signout_service.dart';
import 'verification_gate.dart';

/// Result of the two-tier verification check.
/// [ok] false → couldn't determine the state (network/server error).
/// [ok] true + [popup] null → fully verified, show nothing.
typedef VerificationCheck = ({bool ok, VerificationPopupCase? popup});

/// Post-login verification popup — at most one popup per app open.
class VerificationPrompt {
  static bool _handledThisSession = false; // in-memory; resets on app restart
  static bool _isShowing = false;
  static bool _isChecking = false;

  /// true → the last check couldn't reach the server. Main nav stays locked
  /// and offers Try Again / Sign Out instead of letting the user in.
  static final checkFailed_ = false.obs;

  /// Lets the check run again (sign-out, or right after verification
  /// gets approved so age/gender results are shown).
  static void reset() {
    _handledThisSession = false;
    checkFailed_.value = false;
  }

  /// Called when the main nav is shown. Runs once per app open.
  static void scheduleLoginCheck() {
    if (_handledThisSession || !VerificationGate.isRequired) return;
    _handledThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runLoginCheck());
  }

  /// Try Again on the locked main nav, or back from the verification screen.
  static void retry() => _runLoginCheck();

  static Future<void> _runLoginCheck() async {
    if (_isChecking || _isShowing) return;
    _isChecking = true;
    checkFailed_.value = false;
    try {
      final check = await resolve();
      if (!check.ok) {
        checkFailed_.value = true; // main nav stays locked
        return;
      }
      if (check.popup == null) {
        VerificationGate.verified = true;
        return;
      }
      // Already inside the verification flow — no need to prompt.
      if (Get.currentRoute == RoutePaths.verification) return;
      await show(check.popup!);
    } catch (e) {
      debugPrint('VerificationPrompt: login check failed: $e');
      checkFailed_.value = true;
    } finally {
      _isChecking = false;
    }
  }

  /// Two-tier check: profile fields first, /verification/status only when
  /// the profile can't tell which unresolved state the user is in.
  static Future<VerificationCheck> resolve() async {
    final profile = await _loadProfile();
    if (profile == null) return (ok: false, popup: null);

    final age = profile.ageVerification;
    final gender = profile.genderStatus;

    // Tier 1 — profile is enough.
    if (profile.isIdVerified == true) {
      return (ok: true, popup: popupForIdVerified(age, gender));
    }

    // Tier 2 — never started / pending / processing / declined / expired /
    // needs_review all look identical on the profile.
    final res = await VerificationService().getStatus();
    if (!res.isSuccess || res.data == null) return (ok: false, popup: null);

    return (ok: true, popup: popupForStatus(res.data!.status, age, gender));
  }

  /// Popup for a /verification/status result (tier 2).
  static VerificationPopupCase? popupForStatus(
    VerificationStatus status,
    String? age,
    String? gender,
  ) {
    return switch (status) {
      VerificationStatus.notStarted => VerificationPopupCase.notStarted,
      VerificationStatus.pending => VerificationPopupCase.pending,
      VerificationStatus.processing => VerificationPopupCase.processing,
      VerificationStatus.needsReview => VerificationPopupCase.needsReview,
      VerificationStatus.declined => VerificationPopupCase.declined,
      VerificationStatus.expired => VerificationPopupCase.expired,
      // Profile not updated yet but the inquiry is approved.
      VerificationStatus.approved => popupForIdVerified(age, gender),
    };
  }

  /// ID is verified — only age/gender decide. Age wins if both are rejected.
  /// null → fully verified, show nothing.
  static VerificationPopupCase? popupForIdVerified(
    String? age,
    String? gender,
  ) {
    if (age == 'rejected') return VerificationPopupCase.ageRejected;
    if (gender == 'rejected') return VerificationPopupCase.genderRejected;
    if (age == 'verified' && gender == 'verified') return null;
    return VerificationPopupCase.pendingReview; // still "not_specified"
  }

  /// Fresh profile. Reuses ProfileController's in-flight request when one
  /// is already running (main nav fetches it on open).
  static Future<ProfileDataModel?> _loadProfile() async {
    if (!Get.isRegistered<ProfileController>()) {
      return ProfileInfoService().fetchProfile();
    }
    final pc = Get.find<ProfileController>();
    await pc.fetchMyProfile(); // returns early if a fetch is in flight
    if (pc.isLoading_.value) {
      final done = Completer<void>();
      final worker = ever<bool>(pc.isLoading_, (loading) {
        if (!loading && !done.isCompleted) done.complete();
      });
      // The fetch may have finished between the check above and subscribing.
      if (!pc.isLoading_.value && !done.isCompleted) done.complete();
      try {
        await done.future.timeout(const Duration(seconds: 30));
      } finally {
        worker.dispose();
      }
    }
    return pc.userProfileData.value;
  }

  /// Can't be dismissed (no barrier tap, no back). OK / Later sign the user
  /// out; the action button opens the verification flow. Age/gender rejected
  /// offers Contact Support / Delete Account instead.
  static Future<void> show(VerificationPopupCase popupCase) async {
    if (_isShowing || Get.context == null) return;
    _isShowing = true;
    await showAnimatedDialog(
      context: Get.context!,
      barrierDismissible: false,
      child: PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 20.h),
          backgroundColor: Colors.transparent,
          clipBehavior: Clip.none,
          child: VerificationStatusPopup(
            popupCase: popupCase,
            requiresPassword: SignoutService.requiresPasswordForDeletion(),
            onAction: _openVerification,
            onLogout: logout,
            onContactSupport: () => _openContactSupport(popupCase),
            onDeleteAccount: _deleteAccount,
            onClosed: () => _isShowing = false,
          ),
        ),
      ),
    );
  }

  /// OK / Later, or Sign Out on the locked main nav. Returns false if
  /// sign-out failed, so the popup stays open.
  static Future<bool> logout() async {
    await SignoutService().signOut();
    if (AppStorage.to.isLoggedIn.value) {
      Snack.showError("Couldn't sign you out. Please try again.");
      return false;
    }
    Get.offAllNamed(RoutePaths.signin);
    return true;
  }

  /// Age/gender rejected. The popup comes back when the user returns, so
  /// they never reach the main app.
  static Future<void> _openContactSupport(VerificationPopupCase c) async {
    await Get.toNamed(RoutePaths.contactSupport);
    if (AppStorage.to.isLoggedIn.value) show(c);
  }

  /// Age/gender rejected. Returns false if the delete failed, so the popup
  /// stays open. The backend logout is skipped: the account is already gone.
  static Future<bool> _deleteAccount(String? password) async {
    final ok = await SignoutService().deleteAccountFromBackend(
      password: password,
    );
    if (!ok) return false;
    SignoutService().clearLocalSession();
    Get.offAllNamed(RoutePaths.signin);
    return true;
  }

  /// Verify Now / Resume / Try Again — the verification screen calls
  /// POST /verification/session and opens Persona right away.
  /// Backing out without finishing brings the popup back, so the locked
  /// main nav is never left without one.
  static Future<void> _openVerification() async {
    if (Get.currentRoute == RoutePaths.verification) return;
    await Get.toNamed(RoutePaths.verification, arguments: {'autoStart': true});
    if (AppStorage.to.isLoggedIn.value && !VerificationGate.verified) retry();
  }
}
