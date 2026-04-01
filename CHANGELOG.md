# Changelog

All notable changes to this project will be documented in this file.

This project follows a draft-oriented workflow aligned with Internet-Draft evolution.

---

## [draft-callec-dive-00] — Initial version

### Added

- Initial version of the **Domain-based Integrity Verification Enforcement (DIVE)** protocol draft

- Definition of:

  - DNS-based policy distribution via `_dive` TXT records
  - DNSSEC as a trust anchor
  - Key distribution via `_divekey` records
  - HTTP response header `DIVE-Sig`
  - Client-side verification algorithm
  - Scope mechanism (`strict` and custom scopes)
  - Reporting format and failure handling
  - Cache management and invalidation logic
  - Security considerations and threat model

- Support for modern cryptographic primitives:

  - Ed25519 and Ed448 signature algorithms
  - SHA-256 / SHA-384 / SHA-512 hashing

### Tooling

- Repository structure for Internet-Draft authoring

- Draft source in Markdown (`kramdown-rfc` compatible)

- Generation pipeline via:

  ```bash
  scripts/generate.sh
  ```

- Output formats generated in `generated/`:

  - XML (IETF submission format)
  - HTML
  - TXT
  - PDF

- Environment setup script:

  ```bash
  scripts/install.sh
  ```

  to install required tooling and dependencies

---

## Notes

- This changelog tracks both:

  - Protocol-level changes (draft evolution)
  - Repository/tooling changes

- Future entries will follow Internet-Draft versioning (e.g., `-01`, `-02`, etc.)
