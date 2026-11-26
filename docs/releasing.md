# Verify and publish a client release

Run **COLDWIRE builds and releases** from `feature/spa-admission`. A full build produces four installers. The workflow installs the Mac package on Apple Silicon runners for macOS 15, 26 and 27. It checks the upgrade, saved profiles, direct routes, VPN routes and SPA renewal while the window is inactive.

Download the four artifacts from that run. In the test lab, use the MSI and both APKs to check a clean install, an update over the published version, and a connection with an existing profile. For each exclusion list, check an excluded address and an address that should use the tunnel. The observer should see the provider address for the first and the address of B for the second. Verify a reconnect after changing networks.

Record each successful Windows or Android run on the candidate commit. Use `windows`, `android-9-10` or `android-11-plus` as `PLATFORM`. Write the SHA-256 of the tested installer in `SHA256` and link to its test report in `REPORT_URL`. The report can use lab addresses and must omit profiles, keys and production addresses.

```bash
gh api --method POST "repos/bgunn9in/COLDWIRE-amnezia-client/statuses/$COMMIT" \
  -f state=success -f "context=coldwire/e2e/$PLATFORM" \
  -f "description=sha256:$SHA256" -f "target_url=$REPORT_URL"
```

Run the same workflow again with `existing_run` set to the original build run ID. The build commit must still be the head of `feature/spa-admission`. GitHub Actions checks the macOS jobs and the three installer digests before publishing the four files as Latest. Android packages keep the signature and bytes that were tested.
