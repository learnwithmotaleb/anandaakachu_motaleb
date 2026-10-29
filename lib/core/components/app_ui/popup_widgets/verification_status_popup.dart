import '../../../../app/helper_widgets_export.dart';
import '../../../themes/color/colors.dart';
import '../../../utils/validator/validators.dart';
import '../../ui/helpers/visibility_suffix.dart';
import '../../ui/inputs/cus_pass_type_text_form_field.dart';

/// Every popup the post-login verification check can show.
enum VerificationPopupCase {
  notStarted,
  pending,
  processing,
  needsReview,
  declined,
  expired,
  ageRejected,
  genderRejected,
  pendingReview,
}

class _PopupCopy {
  final IconData icon;
  final String title;
  final String body;

  /// Label of the action that opens the verification flow.
  /// null → the popup only has an "OK" (dismiss) button.
  final String? actionLabel;

  const _PopupCopy(this.icon, this.title, this.body, [this.actionLabel]);
}

const _copy = <VerificationPopupCase, _PopupCopy>{
  VerificationPopupCase.notStarted: _PopupCopy(
    Icons.verified_user_outlined,
    'Verify your ID',
    "To use all of WeMama, we need to check your ID. It's quick and easy.",
    'Verify Now',
  ),
  VerificationPopupCase.pending: _PopupCopy(
    Icons.verified_user_outlined,
    'Finish your ID check',
    "You started checking your ID but didn't finish. Tap Resume to pick up where you left off.",
    'Resume',
  ),
  VerificationPopupCase.processing: _PopupCopy(
    Icons.hourglass_top,
    "We're checking your ID",
    "Thanks for sending your ID. We're checking it now. This usually takes a minute or two.",
  ),
  VerificationPopupCase.needsReview: _PopupCopy(
    Icons.manage_search,
    'Your ID needs a closer look',
    "We're taking a little more time to check your ID. You don't need to do anything. We'll let you know when it's done.",
  ),
  VerificationPopupCase.declined: _PopupCopy(
    Icons.cancel_outlined,
    "We couldn't check your ID",
    "We couldn't read your ID. Please try again with a clear, well-lit photo of a valid ID.",
    'Try Again',
  ),
  VerificationPopupCase.expired: _PopupCopy(
    Icons.timer_off_outlined,
    'Your ID check timed out',
    "The check stopped because it wasn't finished in time. Please start again.",
    'Try Again',
  ),
  // No retry on the two hard rejections: POST /verification/session
  // returns 409 once isIdVerified is true. Contact Support / Delete Account.
  VerificationPopupCase.ageRejected: _eligibilityCopy,
  VerificationPopupCase.genderRejected: _eligibilityCopy,
  // Waiting on an admin — no retry, retrying would create a new inquiry.
  VerificationPopupCase.pendingReview: _PopupCopy(
    Icons.schedule,
    'Almost done',
    "Your ID has been checked. Our team is confirming a couple of details. You don't need to do anything. We'll let you know when it's done.",
  ),
};

const _eligibilityCopy = _PopupCopy(
  Icons.block,
  "We couldn't verify your eligibility",
  "WeMama is currently available to women aged 18+. Based on the verification result, we're unable to provide access to this account.",
);

/// Popups that keep the user out of the app with nothing to retry: offer
/// Contact Support / Delete Account instead of a bare OK.
const _supportCases = {
  VerificationPopupCase.ageRejected,
  VerificationPopupCase.genderRejected,
  VerificationPopupCase.processing,
  VerificationPopupCase.needsReview,
  VerificationPopupCase.pendingReview,
};

/// Shown before the verification flow starts: what the user will do, and
/// who can use WeMama.
const _infoSteps = [
  'Have a valid government ID ready (passport, driving licence or national ID).',
  'Take a clear photo of your ID.',
  'Take a selfie so we can match it to your ID.',
];
const _infoRules = [
  'You must be 18 or older.',
  'WeMama is for women only.',
  'Your ID must be valid and not expired.',
];

class VerificationStatusPopup extends StatefulWidget {
  final VerificationPopupCase popupCase;

  /// Opens the verification flow (Verify Now / Resume / Try Again).
  final VoidCallback onAction;

  /// OK / Later. Returns false if sign-out failed.
  final Future<bool> Function() onLogout;

  /// [_supportCases] only.
  final VoidCallback onContactSupport;

  /// [_supportCases] only. Returns false if the delete failed.
  /// [password] is null when [requiresPassword] is false.
  final Future<bool> Function(String? password) onDeleteAccount;

  /// false → Google/Apple account: delete without asking for a password.
  final bool requiresPassword;

  /// Called when the popup leaves the screen for any reason
  /// (button or route removed by navigation).
  final VoidCallback onClosed;

  const VerificationStatusPopup({
    super.key,
    required this.popupCase,
    required this.onAction,
    required this.onLogout,
    required this.onContactSupport,
    required this.onDeleteAccount,
    required this.onClosed,
    this.requiresPassword = true,
  });

  @override
  State<VerificationStatusPopup> createState() =>
      _VerificationStatusPopupState();
}

class _VerificationStatusPopupState extends State<VerificationStatusPopup> {
  bool _isLoggingOut = false;
  bool _showInfo = false; // "Before you start" step
  bool _showDeleteConfirm = false; // "Delete your account?" step
  bool _isDeleting = false;
  final _deleteFormKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _isPasswordHidden = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    widget.onClosed();
    super.dispose();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    final ok = await widget.onLogout();
    if (!ok && mounted) setState(() => _isLoggingOut = false);
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    if (widget.requiresPassword && !_deleteFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _isDeleting = true);
    final ok = await widget.onDeleteAccount(
      widget.requiresPassword ? _passwordCtrl.text : null,
    );
    if (!ok && mounted) setState(() => _isDeleting = false);
  }

  @override
  Widget build(BuildContext context) {
    // Close (top-right) signs the user out. Only on the status step —
    // the info and delete steps have their own Back / Cancel.
    final showClose = !_showDeleteConfirm && !_showInfo;

    return Container(
      padding: 20.pa,
      decoration: BoxDeco.decRadiusAll(20, clr: bgClr),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _showDeleteConfirm
              ? _buildDeleteConfirm()
              : _showInfo
              ? _buildInfo(context)
              : _buildStatus(context),
          if (showClose)
            Positioned(
              top: -8,
              right: -8,
              child: _isLoggingOut
                  ? Padding(padding: 12.pa, child: LoadingPrimary(size: 18))
                  : IconButton(
                      onPressed: _logout,
                      icon: Icon(Icons.close, color: c.textPrimary),
                      tooltip: 'Close',
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final copy = _copy[widget.popupCase]!;
    final actionLabel = copy.actionLabel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(copy.icon, color: c.primary, size: 48),
        12.toHeight,

        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: TxtStyle.inter(fs: 18, w: 600, color: c.primary),
        ),
        6.toHeight,

        Text(copy.body, textAlign: TextAlign.center, style: TxtStyle.inter()),
        24.toHeight,

        if (_supportCases.contains(widget.popupCase))
          Row(
            children: [
              Expanded(
                child: CustomBtnWTxt(
                  outlined: true,
                  txtClr: c.textPrimary,
                  btnTxt: 'Contact Support',
                  isLoading: false,
                  rad: 30,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onContactSupport();
                  },
                ),
              ),
              Gap(8),
              Expanded(
                child: CustomBtnWTxt(
                  btnColor: AppPalette.snackError,
                  borderClr: AppPalette.snackError,
                  isSmall: true,
                  txtClr: white,
                  btnTxt: 'Delete Account',
                  isLoading: false,
                  rad: 30,
                  onTap: () => setState(() => _showDeleteConfirm = true),
                ),
              ),
            ],
          )
        else if (actionLabel == null)
          CustomBtnWTxt(
            btnColor: c.primary,
            borderClr: c.primary,
            isSmall: true,
            txtClr: white,
            btnTxt: 'OK',
            isLoading: _isLoggingOut,
            rad: 30,
            onTap: _logout,
          )
        else
          Row(
            children: [
              Expanded(
                child: CustomBtnWTxt(
                  outlined: true,
                  txtClr: c.textPrimary,
                  btnTxt: 'Later',
                  isLoading: _isLoggingOut,
                  rad: 30,
                  onTap: _logout,
                ),
              ),
              Gap(8),
              Expanded(
                child: CustomBtnWTxt(
                  btnColor: c.primary,
                  borderClr: c.primary,
                  isSmall: true,
                  txtClr: white,
                  btnTxt: actionLabel,
                  isLoading: false,
                  rad: 30,
                  onTap: _isLoggingOut
                      ? null
                      : () => setState(() => _showInfo = true),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDeleteConfirm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.delete_forever_rounded,
          color: AppPalette.snackError,
          size: 48,
        ),
        12.toHeight,

        Text(
          'Delete your account?',
          textAlign: TextAlign.center,
          style: TxtStyle.inter(fs: 18, w: 600, color: AppPalette.snackError),
        ),
        6.toHeight,

        Text(
          'This will permanently delete your WeMama account and associated account information. This action cannot be undone.',
          textAlign: TextAlign.center,
          style: TxtStyle.inter(),
        ),

        if (widget.requiresPassword) ...[
          16.toHeight,
          Form(
            key: _deleteFormKey,
            child: CusPassTypeTextFormField(
              controller: _passwordCtrl,
              obscureText: _isPasswordHidden,
              hintText: 'Enter your password',
              validator: validatePassword,
              prefix: SvgIcon(
                iconPath: IconsPath.lock,
                height: 22,
              ).mOnly(left: 15, right: 6),
              prefixSize: 34,
              suffix: VisibilitySuffix(
                onTap: () =>
                    setState(() => _isPasswordHidden = !_isPasswordHidden),
                icon: _isPasswordHidden
                    ? IconsPath.visibilityOff
                    : IconsPath.visibilityOn,
              ),
              hintW: 500,
            ),
          ),
        ],
        24.toHeight,

        Row(
          children: [
            Expanded(
              child: CustomBtnWTxt(
                outlined: true,
                txtClr: c.textPrimary,
                btnTxt: 'Cancel',
                isLoading: false,
                rad: 30,
                onTap: _isDeleting
                    ? null
                    : () => setState(() => _showDeleteConfirm = false),
              ),
            ),
            Gap(8),
            Expanded(
              child: CustomBtnWTxt(
                btnColor: AppPalette.snackError,
                borderClr: AppPalette.snackError,
                isSmall: true,
                txtClr: white,
                btnTxt: 'Delete Account',
                isLoading: _isDeleting,
                rad: 30,
                onTap: _delete,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context) {
    Widget item(IconData icon, String text) => Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.primary, size: 20),
          Gap(8),
          Expanded(child: Text(text, style: TxtStyle.inter())),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Icon(Icons.badge_outlined, color: c.primary, size: 48)),
        12.toHeight,

        Center(
          child: Text(
            'Before you start',
            textAlign: TextAlign.center,
            style: TxtStyle.inter(fs: 18, w: 600, color: c.primary),
          ),
        ),
        16.toHeight,

        Text('How it works', style: TxtStyle.inter(w: 600)),
        8.toHeight,
        for (final (i, step) in _infoSteps.indexed)
          item(Icons.arrow_right, '${i + 1}. $step'),
        8.toHeight,

        Text('Who can use WeMama', style: TxtStyle.inter(w: 600)),
        8.toHeight,
        for (final rule in _infoRules) item(Icons.check_circle_outline, rule),
        8.toHeight,

        Text(
          "If your ID doesn't meet these rules, you won't be able to use WeMama.",
          style: TxtStyle.inter(),
        ),
        24.toHeight,

        Row(
          children: [
            Expanded(
              child: CustomBtnWTxt(
                outlined: true,
                txtClr: c.textPrimary,
                btnTxt: 'Back',
                isLoading: false,
                rad: 30,
                onTap: () => setState(() => _showInfo = false),
              ),
            ),
            Gap(8),
            Expanded(
              child: CustomBtnWTxt(
                btnColor: c.primary,
                borderClr: c.primary,
                isSmall: true,
                txtClr: white,
                btnTxt: 'Continue',
                isLoading: false,
                rad: 30,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onAction();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
