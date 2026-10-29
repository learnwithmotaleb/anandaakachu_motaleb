# Post-Login Verification Popup — Changes

This change implements the "Post-Login Verification Popup — Spec for Mobile".

## Summary

**Before:** the app had a hard gate. After login, a user who was not verified
was sent to a full-screen verification screen with no way back. A user whose
`/verification/status` was `approved` was treated as fully verified, so a user
whose age or gender was rejected got into the app with no message.

**Now:** the user always goes to home after login. A popup shows the user's
verification state, at most once per app open. A fully verified user sees no
popup.

## How it works

```
Login
  ↓
Home (main nav), no block
  ↓
One check per app open
  ↓
Tier 1: read isIdVerified / ageVerification / genderStatus from the profile
  ├─ ID true, age + gender verified   → no popup, no extra API call
  ├─ ID true, age rejected            → "Age requirement not met"
  ├─ ID true, gender rejected         → "This app isn't available for your account"
  └─ ID true, not_specified           → "Verification pending review"
  ↓ (ID false)
Tier 2: GET /verification/status
  ├─ not_started  → "Verify your identity"
  ├─ pending      → "Finish verifying your identity"
  ├─ processing   → "Verification in progress"
  ├─ needs_review → "Your document is under extra review"
  ├─ declined     → "We couldn't verify your document"
  ├─ expired      → "Verification session expired"
  └─ approved     → decided by age/gender, same as tier 1
```

If both age and gender are rejected, the age popup is shown.

### Buttons

| Popup                                                                   | Buttons            |
| ----------------------------------------------------------------------- | ------------------ |
| not_started                                                             | Later · Verify Now |
| pending                                                                 | Later · Resume     |
| declined, expired                                                       | Later · Try Again  |
| processing, needs_review, age rejected, gender rejected, pending review | OK only (no retry) |

- **Verify Now / Resume / Try Again** open the verification screen, which calls
  `POST /verification/session` and starts Persona straight away.
- **Later** closes the popup. It shows again on the next login or app open.
- Moving between screens in the same app open does not show the popup again.

### After verification is approved

The app returns to home and runs the check again with a fresh profile, so an
age or gender result (or "pending review") is shown straight away.

### Feature lock

Deep links (live sessions) and notification taps open only for a fully
verified user:

```
isIdVerified == true && ageVerification == "verified" && genderStatus == "verified"
```

Otherwise the matching popup is shown. A pending live link opens after
verification is approved. The rest of the app can be used before
verification (the user can tap "Later").

## Files changed

| File                                                                            | Change                                                                                                             |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `lib/core/services/auth/verification_prompt.dart` (new)                         | Two-tier decision logic and the once-per-app-open rule                                                             |
| `lib/core/components/app_ui/popup_widgets/verification_status_popup.dart` (new) | Popup UI with the spec's titles, messages and buttons                                                              |
| `lib/core/services/auth/verification_gate.dart`                                 | Removed the hard gate; `ensureVerified()` locks deep links and notifications; fixed `isFromFreePlan` being ignored |
| `lib/features/main_tabs/home/sub_feature/profile/model/profile_model.dart`      | Added `ageVerification` and `genderStatus`                                                                         |
| `lib/features/verification/controller/verification_controller.dart`             | Starts Persona automatically when opened from the popup; re-checks after approval                                  |
| `lib/features/verification/view/verification_screen.dart`                       | User can go back; `processing` has its own view                                                                    |
| `lib/features/main_nav/screen/main_nav_screen.dart`                             | Triggers the popup check                                                                                           |
| `lib/core/services/auth/signout_service.dart`                                   | Resets the check on sign-out                                                                                       |
| `test/verification_prompt_test.dart` (new)                                      | Tests for every case in the spec                                                                                   |

### Fix after review

The profile load had a race: if the profile finished loading between "is it
loading?" and "wait for it to finish", the check waited 30 seconds and then
skipped the popup for that app open. The check now starts listening first,
then checks again.

## Verification

- `flutter test test/verification_prompt_test.dart`: 6 of 6 pass
- `flutter analyze`: 0 errors in the project; no issues in the new files
- **Not yet tested on a device against the real backend.**

## Behaviour that differs slightly from the spec

These were kept on purpose and can be changed if needed:

1. **A second popup can appear in the same app open after verifying.**
   For example, "Verify your identity" first, then "Age requirement not met"
   after approval, so the user sees the result straight away.
2. **Deep links and notification taps show their own popup**, even if the
   login popup was already shown. This is the feature lock, not the login
   popup.
3. **"No extra API call" applies to `/verification/status` only.** The check
   reuses the profile that main nav loads. If that load has already finished,
   the check may fetch the profile once more.

## Open items

1. **Device test.** Check on a phone:
   - A new account sees "Verify your identity".
   - Verify Now opens Persona.
   - After approval, the popup matches the age/gender result.
   - A fully verified account sees no popup.
2. **Gender popup after successful verification.** Reported in testing. The
   app shows "This app isn't available for your account" only when the
   backend sends `genderStatus: "rejected"`. If the test used a male ID, this
   is expected. If it used a female ID, the backend is setting the wrong
   value. To confirm, check the `PROFILE JSON` debug log after login for
   `isIdVerified`, `ageVerification` and `genderStatus`.
3. **Field names.** If the backend uses names other than `ageVerification`
   and `genderStatus`, the app always shows "Verification pending review".
   Confirm the names in the same debug log.
4. **Simpler popup wording (proposed, not applied).** Waiting for approval.
   The spec gives exact wording, so the product/backend team should agree too.

   | Case            | Title                       | Message                                                                                                                                 |
   | --------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
   | not_started     | Verify your ID              | To use all of WeMama, we need to check your ID. It's quick and easy.                                                                    |
   | pending         | Finish your ID check        | You started checking your ID but didn't finish. Tap Resume to pick up where you left off.                                               |
   | processing      | We're checking your ID      | Thanks for sending your ID. We're checking it now. This usually takes a minute or two.                                                  |
   | needs_review    | Your ID needs a closer look | We're taking a little more time to check your ID. You don't need to do anything. We'll let you know when it's done.                     |
   | declined        | We couldn't check your ID   | We couldn't read your ID. Please try again with a clear, well-lit photo of a valid ID.                                                  |
   | expired         | Your ID check timed out     | The check stopped because it wasn't finished in time. Please start again.                                                               |
   | age rejected    | You must be 18 or older     | WeMama is only for people aged 18 and over. Your ID shows you don't meet this age requirement.                                          |
   | gender rejected | WeMama is for women only    | WeMama is only open to women. Based on your ID, we can't give this account access.                                                      |
   | pending review  | Almost done                 | Your ID has been checked. Our team is confirming a couple of details. You don't need to do anything. We'll let you know when it's done. |
