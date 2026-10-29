import '../../../app/helper_widgets_export.dart';
import '../../../core/services/auth/verification_prompt.dart';

/// Shown instead of the tabs until the user is fully verified.
/// Checking → loader (the verification popup opens on top of it).
/// Check failed → Try Again / Sign Out, never the app content.
class VerificationLockedView extends StatefulWidget {
  const VerificationLockedView({super.key});

  @override
  State<VerificationLockedView> createState() => _VerificationLockedViewState();
}

class _VerificationLockedViewState extends State<VerificationLockedView> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await VerificationPrompt.logout();
    if (mounted) setState(() => _isSigningOut = false);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!VerificationPrompt.checkFailed_.value) {
        return const Center(child: LoadingPrimary(size: 30));
      }

      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, size: 48.r, color: c.primary),
              Gap(itemGap * 3),
              Text(
                "Couldn't check your verification status",
                textAlign: TextAlign.center,
                style: TxtStyle.inter(fs: 15, w: 600),
              ),
              Gap(itemGap),
              Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TxtStyle.inter(fs: 13, w: 400),
              ),
              Gap(itemGap * 4),
              CustomBtnWTxt(
                btnTxt: 'Try Again',
                isLoading: false,
                onTap: VerificationPrompt.retry,
              ),
              Gap(itemGap * 2),
              CustomBtnWTxt(
                btnTxt: 'Sign Out',
                outlined: true,
                isLoading: _isSigningOut,
                onTap: _isSigningOut ? null : _signOut,
              ),
            ],
          ),
        ),
      );
    });
  }
}
