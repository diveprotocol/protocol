# DIVE Protocol — Draft RFC Repository

This repository contains the working materials used to author and maintain the _Domain-based Integrity Verification Enforcement (DIVE)_ Internet-Draft.

## Purpose

The goal of this repository is to provide a structured environment to:

- Write and iterate on the DIVE Internet-Draft
- Track changes and discussions before publication
- Generate formatted outputs suitable for submission to the IETF Datatracker

This repository is **not** the canonical publication source. The authoritative version of the draft is the one submitted to the IETF.

## Draft Status

The current draft is located in:

```
drafts/draft-callec-dive-xx.md
```

Generated outputs are available in:

```
generated/draft-callec-dive-xx/
```

Including:

- XML (for IETF submission)
- HTML
- TXT
- PDF

## Tooling

This project uses a Makefile and helper scripts to manage dependencies and generate outputs.

### Install dependencies

```
./scripts/install.sh
```

This script installs all required tooling (e.g., kramdown-rfc and related dependencies) to build the draft.

### Generate draft outputs

```
./scripts/generate.sh
```

This will generate all output formats in the `generated/` directory:

- `.xml`
- `.html`
- `.txt`
- `.pdf`

## Workflow

Typical workflow:

1. Edit the draft in `drafts/`
2. Run `scripts/generate.sh`
3. Review generated outputs
4. Commit changes
5. Submit the `.xml` file to the IETF Datatracker when ready

## Licensing

### Repository Code

All scripts, tooling, and repository infrastructure are licensed under the MIT License. See [LICENSE](./LICENSE).

### Draft Document

The Internet-Draft itself is subject to the:

> IETF Trust's Legal Provisions Relating to IETF Documents
> https://trustee.ietf.org/license-info

This means:

- The draft is **not** MIT licensed
- Contributions to the draft are subject to IETF rules and policies
- Rights and restrictions follow IETF Trust provisions

## Contributing

Contributions are welcome.

Before contributing, please read:

- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)

## Contact

Author: Matéo Florian Callec
Email: [mateo@callec.net](mailto:mateo@callec.net)

---

This repository is part of an ongoing effort to design and standardize the DIVE protocol through the IETF process.
