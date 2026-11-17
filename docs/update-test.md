<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# Testing the update mechanism

The program reads the GitHub releases of `aurora/querymole` (ADR-0037). The environment variable `QBR_UPDATE_URL`
replaces that feed, so that an update cycle can be tested without publishing on the project:

| Value of `QBR_UPDATE_URL` | Feed | Use |
|---|---|---|
| `owner/name` or `https://github.com/owner/name` | the GitHub releases of that repository, read like the real feed | the real GitHub path: API, pre-releases, download |
| anything else: a folder (an existing one always counts as a folder, also a relative `dist/Releases-linux`) or a URL | a vpk release (`releases.<channel>.json`) in that place | quick local cycle, no network |

While it is set, every dialog of "Check for Updates ..." ends with a note
that names the feed and the variable: a redirected update is visible before anything is downloaded (someone could
have been talked into setting the variable), and the source is known when debugging. The variable does not add a way
in: whoever can set it for the program can already replace the program itself.

It works for the menu ("Check for Updates ...") and for the developer mode `--selftest-update <report>`, which needs
it and writes `feed`, `installed`, then `no update` or
`available`, `downloaded`, `updater started` (or `not writable <folder>` for an AppImage in a read-only folder).
Velopack logs to `%LOCALAPPDATA%\QueryMole\velopack.log` on Windows (look next to the installation if it is not
there) and to `/tmp/velopack_QueryMole.log` on Linux.

## Local cycle (Linux)

1. `tools/package-appimage.sh --velopack` with `VERSION` at the older version; copy
   `dist/Releases-linux/QueryMole.AppImage` somewhere else (the "installed" copy).
2. Set `VERSION` to the newer version, `tools/package-appimage.sh --velopack` again (vpk adds it to the feed).
3. `QBR_UPDATE_URL="$PWD/dist/Releases-linux" <copy>/QueryMole.AppImage`, then "Check for Updates ...".
4. Clean up: `git checkout VERSION` and `rm -rf /var/tmp/velopack/QueryMole` (Velopack
   keeps downloaded packages there and applies them on the next start of any QueryMole AppImage).

## GitHub cycle with a test repository (Windows)

Needs: a **public** repository with at least one commit (for example `aurora/querymole-update-test`, created with a
README), a GitHub token that may write its releases, vpk as in the header of `tools/package.sh`, the MSYS2 shell.

1. **Older version.** Set `VERSION` to `0.1.0-alpha.3`, then:

   ```bash
   tools/package.sh --velopack
   DOTNET_ROLL_FORWARD=Major tools/cache/vpk/vpk.exe upload github --outputDir dist/Releases --channel win \
     --repoUrl https://github.com/aurora/querymole-update-test --tag v0.1.0-alpha.3 --pre --publish --token "$GITHUB_TOKEN"
   ```

2. **Install it** with `QueryMole-win-Setup.exe` from that release (a per-user installation under
   `%LOCALAPPDATA%\QueryMole`).
3. **Newer version.** Set `VERSION` to `0.1.0-alpha.4`. Fetch the previous release first, so that vpk can build the
   delta package, then pack and upload:

   ```bash
   DOTNET_ROLL_FORWARD=Major tools/cache/vpk/vpk.exe download github --outputDir dist/Releases --channel win \
     --repoUrl https://github.com/aurora/querymole-update-test --pre
   tools/package.sh --velopack
   DOTNET_ROLL_FORWARD=Major tools/cache/vpk/vpk.exe upload github --outputDir dist/Releases --channel win \
     --repoUrl https://github.com/aurora/querymole-update-test --tag v0.1.0-alpha.4 --pre --publish --token "$GITHUB_TOKEN"
   ```

4. **Update.** Start the installed alpha.3 with the override, in `cmd`:

   ```bat
   set QBR_UPDATE_URL=aurora/querymole-update-test
   "%LOCALAPPDATA%\QueryMole\current\querymole.exe"
   ```

   "Check for Updates ..." should offer 0.1.0-alpha.4, download it, restart and show alpha.4 in the About dialog; a
   second check says it is the latest version. Without the variable the program would look at `aurora/querymole`.
5. **Clean up:** `git checkout VERSION`; uninstall QueryMole in the Windows settings; delete
   the test releases or the repository when done.

The Linux AppImage can be tested against the same repository: pack it with the same versions and upload with
`--channel linux --merge` into the same tags.
