# Connect with the COLDWIRE client

[Русский](spa.ru.md)

## Install the app

Download the installer and `SHA256SUMS.txt` from the same release. Compare the SHA-256 hash before opening the installer. [Latest release](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/latest)

| Device | Installer |
| --- | --- |
| Windows x64 | `COLDWIRE-Windows-x64.msi` |
| Mac with Apple Silicon | `COLDWIRE-macOS.pkg` |
| Android 10, ARM64 | `COLDWIRE-Android-10-arm64-v8a.apk` |
| Android 11 or later, ARM64 | `COLDWIRE-Android-11-plus-arm64-v8a.apk` |

Run the MSI on Windows or open the PKG on macOS. Both installers are unsigned. COLDWIRE signs the app inside the PKG ad hoc. If macOS blocks the PKG, verify the downloaded file before following Apple’s instructions. [Apple’s Gatekeeper guide](https://support.apple.com/en-us/102445)

On Android, open the APK for your Android version. If prompted, allow your file manager or browser to install it. Both APKs use the COLDWIRE signing key and the package name `org.amnezia.vpn.coldwire`. If Android rejects an update from an early test APK because of a signature mismatch, save the profile before uninstalling that test build.

## Import your profile

1. Get a `.vpn` file from your COLDWIRE administrator. It contains the device's VPN and SPA keys, so keep it private.
2. Open the app. Select **+**, then **File with connection settings**. Choose the `.vpn` file and confirm the import.
3. Select the imported profile and connect. Check your public IPv4 on a site routed through the VPN. It should match the exit node B. A site that you explicitly route outside the VPN sees your ISP's address.

If your administrator gave you a converted administrator profile, the server shown in its card may be B. The VPN endpoint in the profile still goes to A. Manage SSH and device access in the [COLDWIRE panel](https://github.com/bgunn9in/coldwire).

## Route Russian sites through your ISP

The list menu is shared by Windows, Apple Silicon macOS, and both Android ARM64 builds. Disconnect the VPN and open **Connection → Site-based split tunneling** in Settings. In the three-dot menu, choose **Russian services** for the shorter list or **Russian IPv4 ranges** for broader coverage. The wider list also sends some foreign IPv4 addresses through your ISP. Use the same menu whenever you want to refresh the list.

Choose **Russian services and dedicated CDNs** to include verified, dedicated foreign CDN addresses for selected services. This option needs a current download. If the CDN list is unavailable, COLDWIRE keeps your current rules. [List sources and formats](https://github.com/bgunn9in/coldwire/blob/main/docs/lists.md)

COLDWIRE asks before replacing your **Directly** rules. **Russian services** and **Russian IPv4 ranges** have bundled copies for offline use. To back up your current rules, choose **Save site list**. To load your own JSON, choose **Replace site list**.

Reconnect and check a listed site and a control site routed through B. When repeating the split-tunneling test on Android 10, turn off **App-based split tunneling**. [Huawei test results](huawei-android10.md)

## What happens when you connect

The app sends an authenticated SPA request to A. A verifies that the client holds the device key and can receive a reply at its address, then admits that IPv4 for 120 seconds. The app starts AmneziaWG over the admitted route and normally refreshes the lease every 40 seconds. When your public IPv4 changes, the new address needs a fresh grant.

The VPN service renews access on Windows, macOS and Android while the app window is closed. SPA control packets reach A outside the VPN tunnel.

## If the connection fails

- Check that the selected profile came from COLDWIRE and that the app is the COLDWIRE build. Ask the administrator to check whether the device key is still active.
- If the app stays on **Connecting**, check reachability of A's SPA and AmneziaWG UDP ports. Tell the administrator when the attempt occurred and whether you had just switched networks.
- Under **Logging**, choose **Save connection report**. The JSON file contains the last connection stage, its timing and the error code. It omits addresses, device names and keys. While the VPN is connected, the app also checks DNS and HTTPS access to GitHub.
- To export diagnostics, open the app's logging settings and choose **Save all logs**. Share logs with the administrator. Keep `.vpn` files and keys out of public reports.

[Server setup and routing diagram](https://github.com/bgunn9in/coldwire)
