# Android relay administration

Build `coldwire-spa-linux-amd64` from `servers/spa` in the COLDWIRE panel checkout with `GOOS=linux`, `GOARCH=amd64`, and `CGO_ENABLED=0`. The installer uploads this executable to the relay server.

From the panel checkout, stage the Android payload in a new directory.

```bash
python scripts/prepare_android_admin.py --output "$PWD/android-admin-bundle" \
  --spa-binary "$PWD/dist/coldwire-spa-linux-amd64"
```

Put the Android wheels for `cryptography==50.0.2` and `cffi==2.0.0` in one directory. Include both packages for each target ABI. The embedded CPython version is 3.13. The native extension in the `cryptography` wheel must link to `libpython3.13.so`. [Chaquopy build configuration](https://chaquo.com/chaquopy/doc/current/android.html)

Set these variables to absolute paths before running `deploy/build.sh` from the client checkout.

```bash
export ORG_GRADLE_PROJECT_coldwireAdminBundle=/path/to/android-admin-bundle
export ORG_GRADLE_PROJECT_coldwireAdminWheels=/path/to/android-wheels
deploy/build.sh -t android --abi arm64-v8a
```

To administer an existing COLDWIRE installation from Android, open **Relay administration** and restore an encrypted `.cwoperator` backup. The system file picker handles backups and exported `.vpn` profiles.
