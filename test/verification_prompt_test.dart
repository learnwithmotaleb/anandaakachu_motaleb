import 'package:flutter_test/flutter_test.dart';
import 'package:we_mama/core/components/app_ui/popup_widgets/verification_status_popup.dart';
import 'package:we_mama/core/services/auth/verification_prompt.dart';
import 'package:we_mama/features/verification/model/verification_model.dart';

void main() {
  group('tier 1 — isIdVerified true', () {
    VerificationPopupCase? p(String? a, String? g) =>
        VerificationPrompt.popupForIdVerified(a, g);

    test('fully verified → nothing', () {
      expect(p('verified', 'verified'), isNull);
    });
    test('age rejected → age popup (wins over gender)', () {
      expect(p('rejected', 'verified'), VerificationPopupCase.ageRejected);
      expect(p('rejected', 'rejected'), VerificationPopupCase.ageRejected);
      expect(p('rejected', 'not_specified'), VerificationPopupCase.ageRejected);
    });
    test('gender rejected, age fine → gender popup', () {
      expect(p('verified', 'rejected'), VerificationPopupCase.genderRejected);
      expect(
        p('not_specified', 'rejected'),
        VerificationPopupCase.genderRejected,
      );
    });
    test('not_specified, nothing rejected → pending review', () {
      expect(p('not_specified', 'verified'), VerificationPopupCase.pendingReview);
      expect(p('verified', 'not_specified'), VerificationPopupCase.pendingReview);
      expect(
        p('not_specified', 'not_specified'),
        VerificationPopupCase.pendingReview,
      );
      expect(p(null, null), VerificationPopupCase.pendingReview);
    });
  });

  group('tier 2 — /verification/status', () {
    VerificationPopupCase? p(String status, [String? a, String? g]) =>
        VerificationPrompt.popupForStatus(
          VerificationStatus.parse(status),
          a ?? 'not_specified',
          g ?? 'not_specified',
        );

    test('each unresolved status maps to its popup', () {
      expect(p('not_started'), VerificationPopupCase.notStarted);
      expect(p('pending'), VerificationPopupCase.pending);
      expect(p('processing'), VerificationPopupCase.processing);
      expect(p('needs_review'), VerificationPopupCase.needsReview);
      expect(p('declined'), VerificationPopupCase.declined);
      expect(p('expired'), VerificationPopupCase.expired);
    });
    test('approved uses age/gender', () {
      expect(p('approved', 'verified', 'verified'), isNull);
      expect(p('approved', 'rejected'), VerificationPopupCase.ageRejected);
      expect(
        p('approved', 'verified', 'rejected'),
        VerificationPopupCase.genderRejected,
      );
      expect(p('approved'), VerificationPopupCase.pendingReview);
    });
  });
}
