# OwlMate Offline

OwlMate Offline is an iOS app built for the AppBuildersPH Hackathon 2026 Local AI challenge. It is designed around the core idea that meaningful AI computation should happen on the user's device, not entirely in the cloud.

This project is a private, offline study companion that helps students learn, summarize ideas, and ask questions without depending on a continuous internet connection.

## Challenge alignment

This app follows the Local AI theme from the AppBuildersPH Hackathon 2026 participant briefing:

- Real problem: students need a study assistant that works even without internet access.
- Local AI requirement: the app runs an on-device language model and keeps inference local.
- Why it matters: local processing improves privacy, speed, and reliability when cloud services are unavailable.
- Submission focus: the app demonstrates why AI is more useful when it runs locally.

## Project overview

OwlMate Offline is a personal AI study buddy for mobile learning. It lets users:

- start private study chats
- ask questions in natural language
- continue conversations in a saved history
- work with a local model without relying on a cloud API
- review starter prompts for quick learning tasks
- keep study content local to the device

The app is intentionally designed to be useful even when the network is unavailable once the local model has been downloaded and installed.

## Why this qualifies as Local AI

According to the hackathon brief, Local AI means that meaningful AI functionality runs on the user's device rather than depending entirely on cloud inference.

OwlMate Offline follows that principle by:

- downloading a local GGUF model
- running inference on-device through SwiftLlama
- keeping chat and model processing private to the device
- allowing the experience to continue offline after setup

This makes the app distinct from a cloud-only AI assistant that stops working when connectivity is lost.

## Features

- Offline-first chat experience
- On-device AI model download and validation
- Local conversation history
- Prompt-based study starter cards
- Study tool placeholders for summarization and learning workflows
- Privacy-focused design and local-only AI behavior after setup
- Smooth onboarding experience for first-time users

## Tech stack

- Swift / SwiftUI
- Xcode project: OwlMateOffline.xcodeproj
- Swift Package dependency: SwiftLlama
- Local model: Qwen2.5 0.5B Instruct (Q4_K_M)
- iOS target: 17.0+
- App architecture: local inference, on-device model management, SwiftUI UI

## App structure

```text
OwlMate-Offline-main/
├── OwlMateOffline.xcodeproj/
├── OwlMateOffline/
│   ├── AppTheme.swift
│   ├── ChatView.swift
│   ├── ContentView.swift
│   ├── ConversationStore.swift
│   ├── DemoModels.swift
│   ├── HistoryView.swift
│   ├── HomeView.swift
│   ├── LocalAIService.swift
│   ├── ModelManager.swift
│   ├── OwlMateLogo.swift
│   ├── OwlMateOfflineApp.swift
│   ├── SavedMaterialsView.swift
│   ├── SettingsView.swift
│   ├── StudyToolsView.swift
│   └── Assets.xcassets/
├── AppBuildersPH Hackathon 2026 Participant Briefing.pdf
└── README.md
```

## Prerequisites

To run this app in Xcode, you need:

- macOS computer
- Xcode 16.0 or later (the project is configured for Xcode 16 compatibility)
- iOS 17.0+ SDK
- An Apple Developer account if you want to run it on a physical iPhone
- Internet connection for the first-time model download

## How to test the app in Xcode

1. Open the project in Xcode:
   - Open `OwlMateOffline.xcodeproj`

2. Select the app target:
   - Target name: `OwlMateOffline`

3. Choose a device or simulator:
   - Use an iPhone simulator (recommended for quick testing)
   - or a connected physical iPhone

4. Build and run:
   - Click the Run button in Xcode
   - Or press `Cmd + R`

5. First launch experience:
   - The app shows onboarding/tutorial screens
   - Tap through the introduction
   - The app opens the main OwlMate home screen

6. Set up the local AI model:
   - From the app, tap the setup flow for the offline model
   - The app downloads the local GGUF model from the configured source
   - Wait for the model to finish downloading and validating

7. Test offline chat:
   - Start a new chat
   - Use a starter prompt or write your own question
   - Verify that the app can answer using the local model
   - Disconnect internet access after setup if you want to confirm the offline behavior

## Model behavior and setup notes

The app downloads and validates a local model for use on-device. The model manager checks:

- model size
- hash integrity
- successful installation
- local inference readiness

The local model is stored in the app support directory under the model folder used by the app. Once installed, the app is designed to operate without depending entirely on a cloud API.

## Local AI product story

OwlMate Offline is built to answer the hackathon prompt: "Why does this product benefit from running AI locally?"

It benefits from on-device AI because it:

- keeps study conversations private
- works even when internet access is unavailable
- reduces latency for quick tutoring interactions
- avoids complete dependence on cloud services
- creates a more reliable personal learning experience

## Submission guidance

The official AppBuildersPH brief requires teams to disclose:

- model(s) used
- frameworks and technologies
- APIs and cloud services
- any existing code or assets
- the AI development tools used

Every submission should clearly explain why the product benefits from running AI locally.

## Notes for demo and testing

- The app is intended to be tested primarily through Xcode on an iPhone simulator or actual device.
- A first-time internet connection is required to download the local model.
- After setup, the app should continue to work in offline mode for the local inference workflow.
- For the hackathon demo, emphasize the privacy and offline reliability of the experience.

## License

This project was built for the AppBuildersPH Hackathon 2026 and is intended for demonstration and educational use.
