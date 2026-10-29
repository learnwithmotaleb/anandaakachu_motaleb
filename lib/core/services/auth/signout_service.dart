import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../app/service_export.dart';
import '../../../features/main_tabs/chat/controller/chat_controller.dart';
import '../../../features/main_tabs/chat/controller/chat_inbox_controller.dart';
import '../../../features/main_tabs/community/feed/controller/community_controller.dart';
import '../../../features/main_tabs/experts/controller/experts_controller.dart';
import '../../../features/main_tabs/home/controller/home_controller.dart';
import '../../../features/main_tabs/home/sub_feature/profile/controller/profile_controller.dart';
import '../../../features/main_tabs/match/controller/match_controller.dart';
import '../../../features/more/notification/controller/notification_controller.dart';
import '../../../features/shared/wave_request/controller/wave_request_controller.dart';
import '../../local/app_storage.dart';
import '../socket/socket_service.dart';
import 'verification_gate.dart';
import 'verification_prompt.dart';

class SignoutService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<bool> signoutFromBackend({required String fcmToken}) async {
    apiCall() {
      return ApiClient().post(
        Endpoints.logout.getUrl,
        headers: HeaderHelpers.getAuthHeader(),
        data: {"fcmToken": fcmToken},
      );
    }

    final response = await ApiExecutor().execute(apiCall: apiCall);

    return response.isSuccess;
  }

  Future<String?> getCurrentFcmToken() async {
    try {
      final token = await _fcm.getToken();

      print('🔑 [SignoutService] current FCM token: $token');

      return token;
    } catch (e, st) {
      print('❌ [SignoutService] failed to get FCM token: $e');
      print('$st');

      return null;
    }
  }

  Future<void> signOut() async {
    final fcmToken = await getCurrentFcmToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      print(
        '⚠️ [SignoutService] FCM token unavailable. '
        'Logout cancelled to avoid logging out without removing the device token.',
      );
      return;
    }

    final res = await signoutFromBackend(fcmToken: fcmToken);

    if (!res) {
      print('❌ [SignoutService] backend logout failed');
      return;
    }

    print('✅ [SignoutService] backend logout successful for current device');

    clearLocalSession();
  }

  /// Clears everything the signed-in user left on this device. Doesn't call
  /// the backend, so it also works after the account is deleted.
  void clearLocalSession() {
    // Disconnect socket FIRST
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().disconnectSocket();
    }

    if (Get.isRegistered<ChatController>()) {
      Get.find<ChatController>().clearData();
      Get.delete<ChatController>(force: true);
    }

    if (Get.isRegistered<NotificationController>()) {
      Get.find<NotificationController>().notifications.clear();
    }

    if (Get.isRegistered<WaveRequestController>()) {
      Get.find<WaveRequestController>().newWaveList.clear();
    }

    // Delete user-scoped controllers
    Get.delete<ChatInboxController>(force: true);
    Get.delete<NotificationController>(force: true);
    Get.delete<ProfileController>(force: true);
    Get.delete<MatchController>(force: true);
    Get.delete<WaveRequestController>(force: true);
    Get.delete<HomeController>(force: true);
    Get.delete<ExpertsController>(force: true);
    Get.delete<CommunityController>(force: true);

    //
    VerificationGate.verified = false;
    VerificationPrompt.reset();

    // Clear storage
    AppStorage.to.logout();
  }

  /// Backend's `requiresPasswordForDeletion` when the profile has it,
  /// otherwise how the user signed in (Google/Apple accounts have no password).
  static bool requiresPasswordForDeletion() {
    final fromProfile = Get.isRegistered<ProfileController>()
        ? ProfileController
              .to
              .userProfileData
              .value
              ?.requiresPasswordForDeletion
        : null;
    return fromProfile ?? AppStorage.to.getLoginProvider.isEmpty;
  }

  /// [password] null → social account, sent without a password.
  Future<bool> deleteAccountFromBackend({String? password}) async {
    apiCall() {
      return ApiClient().delete(
        Endpoints.deleteAccount.getUrl,
        headers: HeaderHelpers.getAuthHeader(),
        data: password == null ? null : {"password": password},
      );
    }

    final response = await ApiExecutor().execute(apiCall: apiCall);

    return response.isSuccess;
  }
}
