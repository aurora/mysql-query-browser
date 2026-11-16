# ADR-0037 — Updates with Velopack: AppImage on Linux, Velopack's standard packages on Windows and macOS

- Status: Accepted (principle); Linux implemented, Windows update cycle and macOS open. Since velopack-pas
  v0.1.0-beta.1 the native library comes from its release (built for glibc 2.28, the alternative named below); the
  container build stays as fallback (`docs/linux-port.md`)
- Date: 2026-11-16
- Deciders: Harald Lapp (project owner)
- Supersedes in part: ADR-0026 ("Updates": the release without an update mechanism); amends ADR-0014 and ADR-0018

## Context

ADR-0014 and ADR-0018 chose Velopack and velopack-pas for installing and updating, ADR-0026 switched the update
mechanism off for the first alpha. The alpha is out; the project owner wants updates now, with one rule per
platform: on Linux only the AppImage, on Windows and macOS the standard mechanism (Velopack's own packages).

What was found out before deciding:

- **Velopack on Linux is AppImage only.** `vpk pack` takes a ready AppDir as it is if the folder name ends in
  `.AppDir`; it adds `usr/bin/UpdateNix` and `usr/bin/sq.version` and packs the image itself. The AppDir of ADR-0027
  (GTK2 and libraries from AlmaLinux 9, `RUNPATH`s, own `AppRun`) can therefore be used unchanged; the program sits in
  `usr/bin/qbr` where Velopack looks for it. An update replaces the `.AppImage` file in place (with `pkexec` if the
  file is in a folder the user cannot write).
- **Native library.** velopack-pas loads `libvelopack_libc.so` / `velopack_libc.dll` / `libvelopack_libc.dylib`
  from the program's folder. velopack-pas has no release with these files yet, and its release workflow would build
  the Linux library on Ubuntu 22.04 (glibc 2.35), newer than the minimum of the AppImage (glibc 2.34).
- **Versions.** velopack-pas is written against Velopack commit `301077f4`
  (`third_party/velopack-pas/third_party/velopack/VERSION`). The first `vpk` release that contains it is
  `1.3.39-g8d2844f`.
- **Feed.** All releases of the revival are GitHub pre-releases (`0.1.0-alpha.N`); the feed of ADR-0018 excludes
  pre-releases, so no update would ever be found.

## Decision

- **Linux: the AppImage is the only package and it updates itself.** `tools/package-appimage.sh --velopack` stages
  the AppDir as before, adds `libvelopack_libc.so` to `usr/bin` and packs the AppDir a second time with `vpk pack`
  (`--packId QueryMole`, channel `linux`) into `dist/Releases-linux`. No `.deb`, `.rpm`, Flatpak or Snap. The
  AppImage built without `--velopack` stays possible (no native library, the menu item is disabled).
- **Native library for Linux** is built in the AlmaLinux 9 container (`tools/appimage/build-velopack.sh`, `cargo`
  added to `tools/appimage/Containerfile`) from the commit velopack-pas pins, so it needs no newer glibc than the
  rest of the image. `VELOPACK_LIBRARY` can name a ready file instead.
- **vpk** is `1.3.39-g8d2844f` (the first release with the pinned commit), installed as a .NET tool
  (`dotnet tool install vpk --version 1.3.39-g8d2844f --tool-path tools/cache/vpk`, run with
  `DOTNET_ROLL_FORWARD=Major`). vpk and the native library move together with the pin of velopack-pas.
- **Windows:** Velopack's `Setup.exe` (per-user installation) and its update packages, as in `tools/package.sh
  --velopack` (channel `win`). The portable zip stays as a download without updates.
- **macOS:** Velopack's `.app` bundle with its `.pkg` installer (channel `osx`), once a macOS build exists
  (`docs/macos-setup.md`). Apple requires signing and notarisation for programs downloaded by users; that needs an
  Apple Developer account and is decided with the macOS port.
- **One GitHub release per version** carries the packages of all platforms; Velopack tells them apart by channel.
  `vpk upload github` is run once per platform for the same tag.
- **Pre-releases.** A program whose version has a pre-release part (`-alpha.N`, `-beta.N`) looks at pre-releases too
  (`GitHubPrerelease`); a release version only at releases. This replaces "pre-releases excluded" of ADR-0018.
- **Menu.** "Check for Updates ..." is visible again (`UpdateMenuVisible`); it is disabled where the native library
  is missing.
- **Testing without publishing:** `QBR_UPDATE_URL` replaces the GitHub feed by a folder or URL with a vpk release,
  and the developer mode `--selftest-update <report>` runs check, download and apply without dialogs.

## Consequences

- An installed AppImage finds, downloads and applies newer versions; users no longer download by hand.
- The Velopack AppImage is packed by vpk with gzip (squashfs), not zstd as in ADR-0027: slightly larger.
- The release process gains `vpk` (.NET) and `cargo` as tools, and one more step per platform (`vpk upload github`,
  needs a token).
- The Windows update cycle is still not verified (velopack-pas tests Windows x64 only by build, ADR-0018).
- The package id `QueryMole` (ADR-0030) is now fixed: changing it later cuts installed versions off from updates.
- Users who started the alpha AppImage without Velopack get no update offer; they download once more.

## Alternatives considered

- **Distribution packages (`.deb`, `.rpm`) or Flatpak on Linux:** each needs its own build and repository and does
  not fit Velopack; the AppImage already runs on the supported distributions (ADR-0027).
- **AppImageUpdate / zsync instead of Velopack on Linux:** works without a library in the program, but would be a
  second update mechanism next to Velopack on the other platforms.
- **Native library from a velopack-pas release:** simpler once it exists, but built on glibc 2.35; can replace the
  container build when velopack-pas builds on an older base.
- **Native installers (MSI, winget, DMG with Sparkle):** three different mechanisms instead of one; rejected in
  ADR-0014.

## Related

- ADR-0014 (packaging), ADR-0018 (update check), ADR-0026 (alpha without updater), ADR-0027 (AppImage),
  ADR-0030 (package id `QueryMole`).
