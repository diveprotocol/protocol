# Contributing to DIVE

Thank you for your interest in contributing to the DIVE protocol.

This repository hosts the working version of an Internet-Draft intended for submission to the IETF. Contributions are welcome, but must align with both GitHub collaboration practices and IETF processes.

## Before You Contribute

Please make sure you:

- Understand the goals and scope of the DIVE protocol
- Have read the current draft in `drafts/`
- Are familiar with basic IETF expectations (clarity, interoperability, security considerations)

## Ways to Contribute

You can contribute in several ways:

### 1. Report Issues

Use GitHub Issues to report:

- Ambiguities or unclear wording
- Technical inconsistencies
- Missing edge cases
- Security concerns (see `SECURITY.md` for sensitive disclosures)

### 2. Suggest Improvements

You may propose:

- Editorial improvements (grammar, structure, clarity)
- Better terminology
- Additional examples
- Improved security or deployment guidance

### 3. Submit Changes

Pull requests are welcome for:

- Text improvements
- Clarifications
- Non-breaking technical refinements

For significant protocol changes, it is recommended to open an issue first to discuss the proposal.

## Contribution Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes in `drafts/draft-callec-dive-xx.md`
4. Generate outputs:

```bash
./scripts/generate.sh
```

5. Verify that generated files are consistent
6. Submit a pull request with a clear description

## Style Guidelines

- Use precise and unambiguous language
- Follow RFC-style writing conventions:

  - Normative keywords (MUST, SHOULD, etc.) per BCP 14
  - Consistent terminology

- Keep changes minimal and focused
- Avoid unnecessary reformatting

## IETF Considerations

By contributing to this repository, you acknowledge that:

- Contributions may be included in an Internet-Draft
- The resulting document is governed by the
  IETF Trust Legal Provisions: https://trustee.ietf.org/license-info
- Discussions or proposals may be taken to IETF mailing lists or working groups

## Large or Breaking Changes

For substantial modifications (e.g., new mechanisms, protocol redesign):

- Open an issue first
- Clearly describe:

  - Motivation
  - Problem being solved
  - Proposed approach
  - Security implications

Unreviewed large changes may be declined.

## Code and Scripts

Contributions to scripts (`scripts/`) or tooling are also welcome:

- Keep them simple and portable
- Avoid unnecessary dependencies
- Document any new requirements

## Contact

For direct questions or coordination:

Matéo Florian Callec
[mateo@callec.net](mailto:mateo@callec.net)

---

Your contributions help improve the clarity, security, and interoperability of the DIVE protocol.
