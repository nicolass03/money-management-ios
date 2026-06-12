# money-management-ios

Native iOS client for **spendfly** — terminal-styled personal finance tracker. Companion to the [money-management](https://github.com/nicolass03/money-management) web app.

**Current scope:** login screen + session shell. Data screens and Rust API integration come later.

## Requirements

- macOS with **Xcode 15+** (iOS 17 SDK)
- Apple ID (free tier is fine for Simulator)
- Supabase project (same as the web app)

## First-time setup

### 1. Install Xcode (one-time)

1. Open the **Mac App Store** → search **Xcode** → Install (~12–15 GB).
2. Launch **Xcode** once → accept the license → wait for additional components.
3. Point the active developer directory at Xcode (if `xcodebuild` fails):
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

### 2. Open the project

```bash
cd money-management-ios
open MoneyManagement.xcodeproj
```

Wait for Xcode to resolve Swift packages (**File → Packages → Resolve Package Versions**). First fetch of `supabase-swift` can take 1–3 minutes.

### 3. Configure Supabase secrets

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Edit `Config/Secrets.xcconfig` with the **same values** as the web app `.env`:

```
SUPABASE_URL = https:/$()/YOUR_PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
```

**Note:** In `.xcconfig` files, `//` starts a comment — never write `https://` literally or the host is stripped. Use `https:/$()/` instead.

`Secrets.xcconfig` is gitignored — never commit it.

### 4. Code signing

1. Select the **MoneyManagement** project → target **MoneyManagement** → **Signing & Capabilities**.
2. Enable **Automatically manage signing**.
3. Choose your **Team** (Xcode → Settings → Accounts to add an Apple ID).
4. If the bundle ID conflicts, change **Bundle Identifier** to something unique.

### 5. Run on Simulator

1. In the Xcode toolbar, click the **destination** menu next to the Play (▶) button.
   - If it says **Any iOS Device** or **My Mac**, that is why Run fails — no simulator is selected.
2. Under **iOS Simulators**, pick a device (e.g. **iPhone 17**).
   - **Product → Destination → iOS Simulators** works too if the menu is hidden.
3. Press **⌘R** (Product → Run).
3. Sign in with your Supabase user (same credentials as the web app).

### 6. Run on a physical iPhone (optional)

1. Connect via USB and trust the computer.
2. Select your device in the toolbar → **⌘R**.
3. On the device: **Settings → General → VPN & Device Management** → trust the developer certificate.

## Debugging

| Action | Shortcut / location |
|--------|---------------------|
| Console logs | Debug area **⌘⇧Y** |
| Breakpoints | Gutter click in `LoginViewModel.swift` |
| Clean build | **⌘⇧K** (Product → Clean Build Folder) |
| Reset packages | File → Packages → Reset Package Caches |

## Project structure

```
MoneyManagement/
├── App/              # @main entry, session routing
├── Features/         # Login, placeholder home
├── Core/             # Auth, config, storage
├── DesignSystem/     # Terminal UI tokens & components
└── Resources/        # Fonts, Assets, Info.plist
Config/               # xcconfig (secrets injected into Info.plist)
```

## Regenerating the Xcode project

The committed `.xcodeproj` is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen   # one-time
xcodegen generate
```

Run this after editing `project.yml` (new files are picked up automatically from the `MoneyManagement/` folder).

## Common issues

| Symptom | Fix |
|---------|-----|
| **No supported iOS devices are available** | Select an **iOS Simulator** (e.g. iPhone 17) in the toolbar destination menu — not "Any iOS Device" |
| `SUPABASE_URL is missing` at launch | Create `Config/Secrets.xcconfig` from the example |
| `xcodebuild` requires Xcode | Install Xcode; run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Package resolve failed | File → Packages → Reset Package Caches |
| Signing error | Set Team + unique bundle ID |
| `supabaseURL must have a valid host` | Use `https:/$()/project.supabase.co` in `Secrets.xcconfig`, not `https://` |
| Invalid credentials (web works) | Same Supabase URL/key; no trailing spaces in xcconfig |
| Font not monospace | Confirm JetBrains Mono `.ttf` files are in the target **Copy Bundle Resources** build phase |

## Related repos

- Web UI: [money-management](https://github.com/nicolass03/money-management)
- API: [money-management-api](https://github.com/nicolass03/money-management-api)
