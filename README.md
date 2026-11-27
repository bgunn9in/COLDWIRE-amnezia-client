# COLDWIRE Amnezia VPN

[Русский](README_RU.md)

COLDWIRE Amnezia VPN is an AmneziaVPN fork that opens a COLDWIRE relay with SPA before connecting over AmneziaWG 3.1. Use a `.vpn` profile issued or converted by the relay administrator.

- [Download for Mac with Apple Silicon](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/latest/download/COLDWIRE-macOS.pkg).
- [Download for Windows x64 or Android ARM64](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/latest). Pick the APK for Android 9/10 or Android 11 and later.
- [Install the app and connect](docs/spa.md).
- [Set up a relay or manage devices](https://github.com/bgunn9in/coldwire).

The diagnostics preview adds a connection report and renews SPA through the VPN service on Windows and macOS. The release notes list the remaining Android 9 and macOS sleep checks. [Download the preview](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/tag/coldwire-preview-b1377ae987b6)

GitHub Actions builds the stable installers from `feature/spa-admission`. Releases include SHA-256 checksums and a link to the build. The client carries the upstream [license](LICENSE). [AmneziaVPN upstream](https://github.com/amnezia-vpn/amnezia-client)
