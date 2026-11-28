# COLDWIRE on a Huawei phone with Android 10

[Русский](huawei-android10.ru.md)

We installed the signed Android 10 APK on a physical Huawei phone running Android 10 (API 29) on ARM64. The installed APK matched the release checksum, and the saved profile remained selected after the update to build `2232`. [Tested release](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/tag/coldwire-spa-19e809562970)

The phone reached the lab entry node A over USB and used Wi-Fi for direct routes. A confirmed SPA access. We imported each list separately with **Replace site list** and selected **Directly**. App-based split tunneling was off throughout.

| Mode | Address in both lists | Control address outside both lists | Address only in `ru-direct` |
| --- | --- | --- | --- |
| Full tunnel | B | B | B |
| `ru-services` | Wi-Fi | B | B |
| `ru-direct` | Wi-Fi | B | Wi-Fi |

An HTTP server recorded the lab exit B as the source of the tunneled requests. For the bypassed addresses, we checked which network interface Android selected. With each list, a separate HTTP server on the local network also received a request directly from the phone over Wi-Fi.

We removed the test profile and restored the phone's previous split-tunneling settings after the run.
