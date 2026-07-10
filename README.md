<div align="center">

# BlueSnap

### Connect with the people around you — no internet, no data, no servers.

BlueSnap is a **Bluetooth‑first social app**. Discover people who are physically
nearby and chat, share photos, voice notes, files and stories, or call them —
all peer‑to‑peer, with **zero internet required**. Your identity, messages and
media live only on your device.

[![Flutter](https://img.shields.io/badge/Flutter-3.16%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-Proprietary-lightgrey)](#license)

</div>

---

## ✨ What it does

BlueSnap takes the parts of Instagram and Snapchat people love — feed, stories,
DMs, snaps, streaks — and makes them work **offline, over the air, between phones
in the same place.**

| | Feature |
|---|---|
| 🛰️ | **Nearby discovery** — find BlueSnap users around you automatically |
| 💬 | **End‑to‑end encrypted chat** — text, voice notes, images and files |
| 🔥 | **Streaks** — Snapchat‑style daily streaks with a nearby friend |
| 📸 | **Stories & posts** — ephemeral stories and a feed that propagates device‑to‑device |
| 📞 | **Calls** — audio & video over WebRTC, signalled peer‑to‑peer |
| 🔒 | **Real security** — PIN/biometric app‑lock, hardware‑backed keys, key verification |
| 📴 | **Store‑and‑forward** — messages queue and deliver when a peer is back in range |
| 🔔 | **Background delivery** — a foreground service keeps you reachable when the app is closed |

---

## 🧠 How it works

The technology is deliberately invisible to users, but under the hood:

- **Transport —** Google **Nearby Connections** (`P2P_CLUSTER`), which handles BLE
  advertising/scanning and transparently upgrades to Wi‑Fi for throughput. One real
  transport; no simulation.
- **Encryption —** each device holds a long‑lived **X25519** identity key. Sessions
  derive a shared key via **ECDH → HKDF‑SHA256**, and messages are sealed with
  **AES‑256‑GCM**. Peer keys are **pinned on first use**; a changed key raises a
  security warning instead of being silently trusted.
- **Trust —** incoming connections require **explicit approval** and show a Nearby
  verification code; each chat exposes a **safety‑code fingerprint** for in‑person
  verification.
- **Key storage —** the private identity seed lives in the **Android Keystore**
  (`flutter_secure_storage`), never in plaintext. `allowBackup` is off.
- **Reliability —** undelivered messages are **queued** and retried idempotently
  when the recipient reconnects.

> **Scope:** v1 targets **Android** — Nearby Connections has no iOS SDK. iOS would
> use MultipeerConnectivity in a future version.

---

## 🏗️ Architecture

```
lib/
├── core/            theme, constants, icon set
├── data/
│   ├── models/      Hive models (User, Message, Conversation, Post, Story…)
│   ├── database/    DatabaseService (Hive) + adapters
│   └── protocol/    binary packet format (BlueSnap protocol)
├── services/        transport, crypto, auth, notifications, streaks, media…
│   ├── nearby_service.dart        Nearby Connections engine
│   ├── bluetooth_service.dart     single transport facade
│   ├── crypto_service.dart        X25519 / AES‑GCM E2E
│   ├── auth_service.dart          PIN + biometric app‑lock
│   ├── foreground_service.dart    background reachability
│   └── …
├── screens/         auth, home, search, chat, call, stories, profile, camera
├── widgets/         shared UI (avatars, pin pad, media, etc.)
└── main.dart        entry, permissions, lock/onboarding routing
```

**Stack:** Flutter · Riverpod (state) · Hive (local DB) · Nearby Connections ·
flutter_webrtc · flutter_secure_storage · local_auth · Iconsax (icons).

---

## 🚀 Getting started

**Prerequisites:** [Flutter](https://docs.flutter.dev/get-started/install) 3.16+
and an **Android device** (Bluetooth + Nearby need real hardware — you need **two**
devices to see discovery).

```bash
# 1. Install dependencies
flutter pub get

# 2. (Re)generate brand icons & splash, if you change the logo
dart run tool/gen_icons.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# 3. Run on a connected Android device
flutter run

# 4. Quality gates
flutter analyze          # static analysis (0 errors expected)
flutter test             # unit tests (crypto, protocol, queue, safety)
flutter build apk        # release-ish build
```

On first launch you'll create a local profile, a profile photo, and an app‑lock PIN.
Grant the Bluetooth, Nearby and Location permissions when prompted so discovery works.

---

## 🔐 Security notes

BlueSnap is built privacy‑first, but it is **not** a formally audited secure
messenger. Known limitations, tracked for future work:

- No forward secrecy yet (single long‑lived session key per peer — Double Ratchet is planned).
- Feed/story payloads propagate in the clear (they're semi‑public by design); 1:1 chat is encrypted.
- Real‑world radio behaviour, battery and cross‑device transfer should be validated on hardware.

Please report security concerns privately rather than in a public issue.

---

## 🗺️ Roadmap

- [ ] Forward secrecy (Double Ratchet)
- [ ] Multi‑hop mesh relay for reach beyond one hop
- [ ] iOS (MultipeerConnectivity)
- [ ] Optional internet sync backbone (hybrid mode)
- [ ] Media in the feed (currently text propagates; media stays local)

---

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feat/my-change`
2. Keep `flutter analyze` clean and `flutter test` green.
3. Match the existing style (see `analysis_options.yaml`).
4. Open a pull request describing the change and how you verified it.

---

## 📄 License

© 2026 BlueSnap. All rights reserved. This is a proprietary project — see the
repository owner before reusing any part of it.

<div align="center">
<sub>Built with Flutter · Connect locally. Zero internet.</sub>
</div>
