# Switchie

A fast, keyboard-driven macOS application and window switcher.

- **Tap** a global hotkey to toggle between apps (cycle through all, or just bounce to the previous one — your choice).
- **Hold** the same hotkey to bring up an overlay panel with searchable, numbered app icons.
- **Cycle windows** within the frontmost application using a separate hotkey.
- **Mark** favorite apps to restrict toggling to just those.
- Lives in the menu bar; the Dock icon is optional.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later (free from the Mac App Store)
- An Apple ID — **no paid Apple Developer Program membership required**

## Building and running locally (no paid developer account)

Xcode lets you sign and run apps on your own Mac for free using just an Apple ID. There's no $99/year fee for personal use; the only restriction is that locally-signed builds can't be distributed.

### 1. Clone the repository

```sh
git clone https://github.com/jfrankl/switchie.git
cd switchie
```

### 2. Open the project in Xcode

```sh
open Switchie.xcodeproj
```

### 3. Add your Apple ID to Xcode (one-time setup)

If you've never signed an app on this Mac before:

1. In Xcode, open **Settings** (`⌘,`).
2. Go to the **Accounts** tab.
3. Click **+** and choose **Apple ID**, then sign in with your regular Apple ID.

This gives you a free "Personal Team" you can use to sign builds.

### 4. Configure signing

1. In the Xcode project navigator, click the blue **Switchie** project at the top.
2. Select the **Switchie** target.
3. Open the **Signing & Capabilities** tab.
4. Under **Team**, choose your Personal Team (it'll appear as your name with `(Personal Team)`).
5. Leave **Automatically manage signing** checked. Xcode will set the bundle identifier and provisioning automatically.

> If you see a bundle ID conflict, change `Bundle Identifier` to something unique to you, e.g. `com.yourname.switchie`.

### 5. Build and run

- Press `⌘R` (or **Product → Run**).
- The first build may take a minute. The app will launch as **Switchie** in the menu bar.

### 6. Grant Accessibility permission

Switchie uses macOS Accessibility APIs to enumerate windows and bring them to the front. The first time you press the window-cycling hotkey, macOS will prompt you to grant permission.

To grant it manually:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Click **+** and add the running `Switchie.app` (or drag it from Xcode's build products).
3. Toggle it on.

You'll need to quit and relaunch Switchie after granting permission.

## Configuring shortcuts

Open Switchie's preferences (it appears on first launch, or via the menu bar icon). Click any shortcut field and press the key combination you want.

Default shortcuts are unset — pick whatever feels natural. Common choices:

| Action | Suggested shortcut |
|--------|-------------------|
| Toggle app (tap = cycle, hold = open panel) | `F12` |
| Toggle window | `F11` |
| Select highlighted app (in panel) | `Return` |
| Quit selected app (in panel) | `⌘Q` |
| Mark / unmark app (in panel) | `M` |

## Notes on signing limitations

When you sign with a free Personal Team:

- The signed build is valid only on Macs where you're signed in with that Apple ID.
- Re-signing every 7 days is technically required by Xcode for sideloaded iOS apps, but **macOS apps signed locally don't expire** — you can keep running the build indefinitely.
- You cannot notarize or distribute the build to other users.

If you want to share the app, you'll need to enroll in the Apple Developer Program ($99/year) and sign with a Developer ID certificate.

## License

See [LICENSE](LICENSE).
