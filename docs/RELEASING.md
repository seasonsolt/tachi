# Releasing Tachi

Tachi releases must be signed with a Developer ID Application certificate and notarized by Apple. Do not publish an ad-hoc signed build as a final release.

## One-time GitHub configuration

Add these Actions secrets to `seasonsolt/tachi`:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Base64-encoded Developer ID Application certificate exported as PKCS#12 |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the PKCS#12 file |
| `MACOS_SIGNING_IDENTITY` | Full identity, such as `Developer ID Application: Name (TEAMID)` |
| `APPLE_API_KEY_ID` | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APPLE_API_PRIVATE_KEY` | Complete contents of the matching `.p8` private key |

The certificate can be encoded without placing it on the command line:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## Publish a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `eacc-panel/Info.plist`.
2. Merge the release commit to `main` and create a matching tag, for example `v1.4.0`.
3. Push the tag. The **Release notarized macOS app** workflow builds an Apple Silicon binary, signs it, notarizes and staples both the app and DMG, verifies the result, and publishes the DMG as a final GitHub Release.
4. Download the published DMG on a clean Mac and verify that it opens without an `xattr` command or **Open Anyway**.

The workflow can also be run manually for an existing tag. It refuses to proceed when the tag and `Info.plist` version differ or when the signing identity is missing.

## Local validation

Local builds remain ad-hoc signed by default:

```bash
cd eacc-panel
TACHI_INSTALL_APP=0 ./build.sh
codesign -dvvv Tachi.app
```

With a Developer ID identity installed, use:

```bash
cd eacc-panel
TACHI_INSTALL_APP=0 SIGN_IDENTITY='Developer ID Application: Name (TEAMID)' ./build.sh
codesign --verify --deep --strict --verbose=2 Tachi.app
```
