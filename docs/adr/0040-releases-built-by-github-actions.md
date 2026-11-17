<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0040 — Releases are built and published by GitHub Actions

- Status: Proposed (workflow written; not yet run on GitHub)
- Date: 2026-11-17
- Deciders: Harald Lapp (project owner)

## Context

The packages of a release are built by scripts on the developer machines: `tools/package.sh` on Windows (portable
zip; with `--velopack` the installer `QueryMole-win-Setup.exe` and the update feed, ADR-0014) and
`tools/package-appimage.sh` on a Linux host with podman and the `freepascal` distrobox (AppImage, ADR-0027; with
`--velopack` the self-updating AppImage, ADR-0037). Every release needs both machines, the right tool versions on
each, and two `vpk upload github` runs into the same tag. The repository now has a GitHub remote
(`aurora/querymole`), and the update feed is that repository's releases (ADR-0018, ADR-0037).

## Decision

- **`.github/workflows/release.yml`** builds the release. A push of a tag `v<VERSION>` builds Windows and Linux and
  publishes them; a manual run builds only and keeps the packages as workflow artifacts (for checking the workflow
  without publishing). The tag must equal `v` + the `VERSION` file.
- **The same scripts as locally.** The workflow calls `tools/package.sh --velopack` and
  `tools/package-appimage.sh --velopack`; what CI needs differently goes into the scripts as options, so a local
  release and a CI release stay the same thing.
  - Windows: a hosted `windows-2025` runner. Its preinstalled MSYS2 is `C:\msys64`, Lazarus 4.8 / FPC 3.2.2 is
    installed from the official installer to `C:\lazarus` (cached), the paths the scripts expect.
  - Linux: a hosted `ubuntu-24.04` runner with its podman. There is no distrobox, so
    `QBR_FPC_IMAGE=<name>` makes `package-appimage.sh` build the Pascal program in a plain container from
    `tools/appimage/Containerfile.fpc` (Fedora 44, the toolchain part of `tools/distrobox-setup.sh`) instead. The
    backend and the AppDir are built in the AlmaLinux 9 container as before (ADR-0027).
- **One publish job** after both builds: `vpk upload github` for channel `win`, then for channel `linux` with
  `--merge` (one release per version, ADR-0037), pre-release when the version has a pre-release part. It adds the
  portable zip and the AppImage without updater (ADR-0026) and takes the release notes from
  `docs/release-notes/<VERSION>.md` if that file exists. Before packing, each build job fetches the previous release
  with `vpk download github`, so that Velopack can build the delta package.
- **Pinned tools:** vpk as in ADR-0037, Lazarus 4.8 (installer URL in the workflow), appimagetool 1.9.0.

## Consequences

- A release is: set `VERSION`, write the release notes, commit, tag `v<VERSION>`, push the tag.
- The Windows package is **not code-signed**; SmartScreen warns when the installer is started. Signing needs a
  certificate and a secret in the repository; that is a decision of its own.
- The Linux Pascal toolchain of CI comes from Fedora 44's packages; when Fedora updates Lazarus, CI follows, the
  distrobox only when it is updated. The Lazarus version is in the build log.
- The tests on the server matrix are not part of the release workflow; a test workflow is separate work (ROADMAP).
- Building locally stays possible and unchanged (without `QBR_FPC_IMAGE` the distrobox is used as before).

## Alternatives

- **Keep releasing by hand.** Works, but needs two machines and the tool versions on each; easy to get the two
  uploads or versions out of step.
- **Cross-build the Windows program on Linux** (the distrobox can, `docs/linux-port.md`). The package also needs
  the MSYS2 DLLs and their licence data (`pacman`), and the self-test of the staged program; a Windows runner does
  that natively.
- **Separate workflows per platform, each uploading.** Two jobs creating the same release race each other; one
  publish job after both builds does not.

## Related

ADR-0014, ADR-0018, ADR-0026, ADR-0027, ADR-0037.
