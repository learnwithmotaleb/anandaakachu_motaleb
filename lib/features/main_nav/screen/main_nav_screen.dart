import '../../../app/helper_widgets_export.dart';
import '../../../core/services/auth/verification_gate.dart';
import '../../../core/services/auth/verification_prompt.dart';
import '../controller/main_nav_controller.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/verification_locked_view.dart';

class MainNavScreen extends StatelessWidget {
  const MainNavScreen({super.key});

  @override
  Widget build(BuildContext context) {
    MainNavController mnc = Get.find<MainNavController>();

    print("🏗️ MainNavigationPage build called");

    // Post-login verification popup — runs once per app open.
    VerificationPrompt.scheduleLoginCheck();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) =>
          didPop ? null : mnc.handleWillPop(),
      child: SafeArea(
        top: false,

        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: bgClr,
          // Nothing in the app is reachable until the user is fully verified.
          body: Obx(() {
            if (_isLocked) return const VerificationLockedView();
            final currentIndex = mnc.currentIndex.value;
            print("📄 Displaying page at index: $currentIndex");
            return mnc.pages[currentIndex];
          }),
          bottomNavigationBar: Obx(
            () => _isLocked
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: c.inputBackground,
                          boxShadow: boxShadowTopOnly,
                          // borderRadius: BorderRadius.only(
                          //   topLeft: Radius.circular(35.r),
                          //   topRight: Radius.circular(35.r),
                          // ),
                        ),
                        padding: EdgeInsets.only(
                          left: 15.w,
                          right: 15.w,
                          top: 15.h,
                          bottom: S.bottomInset + 12.h,
                        ),
                        child: CustomBottomNavBar(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  static bool get _isLocked =>
      VerificationGate.isRequired && !VerificationGate.verified;
}
