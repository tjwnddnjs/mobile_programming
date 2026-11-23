# SmartChat AI

SmartChat AI is an Android conversation assistant built with Flutter. It reads conversation screenshots to suggest replies and helps users understand and respond to disagreements through **Moonchul**, its conflict analysis feature.

## What you can do

- **Reply Suggestions.** Select a contact and attach a conversation screenshot. SmartChat AI considers the conversation, your relationship and notes about the contact, and your saved writing preferences. It returns three replies you can tap to copy. Add **Additional instructions** for the current request, for example, “Politely decline and suggest Friday.” A request can override your usual reply style.
- **Moonchul.** Attach up to five screenshots in chronological order, mark which side contains your messages, and optionally describe what happened. Results can include the main issue, supporting statements, an estimate of each person's communication responsibility, steps to resolve the conflict, and suggested replies. Choose **I cannot tell** to get participant analysis without assigning a side to you. Moonchul can defer its assessment when the evidence is insufficient. The estimates are AI interpretations of the visible conversation.
- **AI preferences.** Go to **My Profile → Edit profile → AI preferences** to save a default reply tone, whether to use emojis, and a Moonchul analysis style. **Balanced** weighs facts and impact together, **T (Thinking)** emphasizes facts and practical next steps, and **F (Feeling)** emphasizes emotional impact and repair. All styles use the same standards for evidence and uncertainty. Preferences are stored on the device for the signed-in account.
- **Floating assistant.** Enable it from Home and grant Android permission to display over other apps. From a messenger, use **Reply Suggestions** to capture the current screen or attach up to three images, or open **Moonchul**. Android asks for screen capture permission, and you review the images before sending them for analysis. Replies are copied manually and can be edited before sending in your messenger.

## Run on Android

1. Install Flutter and the Android SDK, then run `flutter doctor`. Connect an Android device with debugging enabled or start an emulator.
2. Configure a Firebase Android app for the package `com.example.smart_chat_ai`. Place its configuration at `android/app/google-services.json`. Enable Email/Password authentication. To use Google sign-in, also enable Google and register the signing certificate for your Android build with Firebase.
3. From this folder, run:

   ```sh
   flutter pub get
   flutter devices
   flutter run --dart-define=OPENROUTER_API_KEY=YOUR_OPENROUTER_API_KEY
   ```

   Replace `YOUR_OPENROUTER_API_KEY` with your development key. The default OpenRouter model is `openrouter/free`. To select a different model, add `--dart-define=OPENROUTER_MODEL=provider/model`. The model must accept images and support the structured responses used by the selected feature.

The key passed through `--dart-define` is embedded in the Android build. Use this setup for development and demos. A public release should use a backend to manage the key.

## How the app works

Flutter renders the screens, and Provider manages authentication and contact state. Firebase Authentication handles email and Google sign-in. SharedPreferences stores profiles, contacts, and preferences on the device. Kotlin code connects Flutter to Android's image picker and screen capture. The app sends the selected images and relevant inputs to OpenRouter and validates the structured response before displaying it.

Reply requests include the selected contact and relevant profile information, preferences, and any additional instructions. Moonchul sends the images, analysis style and context, plus the selected side and contact details when applicable. Review what appears in the screenshots before analyzing them.

## Development checks

```sh
flutter analyze
flutter test
flutter build apk --debug
```

To check the workflow on a device with test credentials, save AI preferences, reopen My Profile, then try both AI features from Home and from the floating assistant. In Reply Suggestions, verify that the keyboard opens in the floating preview and that a new request starts without the previous additional instructions.
