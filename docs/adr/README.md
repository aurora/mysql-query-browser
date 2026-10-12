# Architecture Decision Records

Binding decisions for query-browser-revival. Each ADR is immutable once
accepted; to change a decision, add a new ADR that supersedes the old one (and
mark the old one `Superseded by ADR-XXXX`).

Template: Status · Context · Decision · Consequences · Alternatives ·
Related.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-revive-as-fork-windows-ui-as-blueprint.md) | Revive the Query Browser as a fork; the Windows UI is the blueprint | Accepted |
| [0002](0002-port-ui-to-lazarus-lcl.md) | Port the UI to Free Pascal / Lazarus (LCL) | Accepted |
| [0003](0003-keep-c-backend-as-transition-layer.md) | Keep the C backend as a transitional layer, built with CMake | Accepted (transitional) |
| [0004](0004-mariadb-connector-c-and-server-support-matrix.md) | MariaDB Connector/C as client library; server support matrix | Accepted |
| [0005](0005-tls-preferred-with-plaintext-fallback.md) | TLS "preferred" with fallback to an unencrypted connection | Accepted (default); UI option deferred |
| [0006](0006-generated-pascal-interface-layer-with-original-names.md) | Generate the Pascal interface layer under the original unit and type names | Accepted |
| [0007](0007-replace-third-party-delphi-libraries.md) | Replace third-party Delphi libraries with LCL equivalents and thin shims | Accepted |
| [0008](0008-ui-fidelity-via-dfm-conversion-and-screenshots.md) | UI fidelity: convert the DFMs, review by screenshots | Accepted; reference screenshots outstanding |
| [0009](0009-hidpi-and-vector-icons.md) | HiDPI scaling and vector icons come after functional parity | Proposed (deferred) |
| [0010](0010-multi-database-support-via-driver-seam.md) | Other RDBMS (PostgreSQL) via a driver seam, after parity | Proposed (design seam only) |
| [0011](0011-license-gpl-2-or-later.md) | License: GPL-2.0-or-later, as the original | Accepted |
| [0012](0012-sql-editor-compatibility-layer-over-synedit.md) | SQL editor: a UniCodeEditor-compatible layer over SynEdit | Accepted; visual review outstanding |
| [0013](0013-inline-help-reference-and-multiple-servers.md) | Inline help (reference) with several servers and versions | Superseded in part by ADR-0016 |
| [0014](0014-release-packaging-and-updates-with-velopack.md) | Release packaging and updates with Velopack | Proposed (packaging implemented) |
| [0015](0015-mpl-1-1-only-components-and-the-help-viewer.md) | MPL-1.1-only components and the help viewer | Proposed (IpHtml part resolved by ADR-0016; SynEdit part open) |
| [0016](0016-help-from-the-connected-server.md) | Help reference from the connected server | Accepted by implementation (to confirm) |

## Numbering

`NNNN-kebab-title.md`, zero-padded, monotonically increasing. Do not reuse
numbers. Status values: `Proposed`, `Accepted`, `Deprecated`, `Superseded by
ADR-XXXX`; compound values such as `Accepted (principle); implementation
deferred` are used where plain `Accepted` would overstate how built a decision
is.
