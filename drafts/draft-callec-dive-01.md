---
title: "Domain-based Integrity Verification Enforcement (DIVE) Version 0.1"
abbrev: "DIVE"
docname: draft-callec-dive-01
submissiontype: IETF
date: 2026-04-16
category: exp
ipr: trust200902
area: Security
workgroup:
keyword:
  - integrity
  - dns
  - dnssec
  - signature
  - http

stand-alone: yes
smart-quotes: no

author:
  - ins: M. F. Callec
    name: Mateo Florian Callec
    org: Independent
    email: mateo@callec.net
    orcid: 0009-0000-8025-5350
    country: France

--- abstract

Domain-based Integrity Verification Enforcement (DIVE) is an application-layer
protocol that provides cryptographic integrity and authenticity verification of
HTTP resources. It consists of two separable components:

1. **Object security layer**: HTTP Message Signatures (RFC 9421) applied to
   response content, using keys whose identifiers are carried in HTTP response
   headers.

2. **Key distribution layer**: public keys and policy configuration published as
   DNSSEC-protected DNS TXT records, constituting an out-of-band trust anchor
   independent of the origin server.

An attacker must therefore compromise both the DNS infrastructure and the origin
server simultaneously to deliver a tampered resource to a DIVE-compliant client.

--- middle

# Introduction

TLS protects data in transit but does not defend against a compromised origin
server that serves malicious content over a legitimate TLS session. Subresource
Integrity (SRI) embeds expected hashes in HTML markup, but the markup itself is
delivered by the compromised host, allowing an attacker to modify both content
and hashes.

DIVE binds resource integrity to an independent trust anchor: DNSSEC-validated
DNS records. The origin server signs response content (RFC 9421) and publishes
the corresponding public key in DNS. A client accepts a resource only when its
signature verifies against a DNSSEC-validated public key.

This document defines:

- The DNS record format for policy and key distribution (Section 4).
- The HTTP header profile for carrying key identifiers (Section 5).
- How RFC 9421 is applied to construct and verify signatures (Section 6).
- The client verification algorithm (Section 7).
- Reporting (Section 8) and operational guidance (Section 9).

DIVE is intended for non-browser clients (package managers, CLI tools, automated
agents). Browser clients MUST NOT implement DIVE enforcement.

# Terminology {#terminology}

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 {{!RFC2119}} {{!RFC8174}}.

DIVE client:
: An HTTP client (library, tool, or agent) implementing the verification
  algorithm in this document.

DIVE server:
: An HTTP origin server publishing DIVE DNS records and including RFC 9421
  signatures on covered responses.

Key ID:
: An operator-assigned identifier naming a specific key record, carried in the
  `DIVE-Keys` HTTP response header and referenced in RFC 9421 signature metadata.

Policy record:
: The `_dive` DNS TXT record publishing DIVE configuration for a domain.

Key record:
: A DNS TXT record publishing a public key at `<Key-ID>._divekey.<domain>`.

Scope:
: A named category of resources subject to DIVE verification.

# Design Overview {#design-overview}

DIVE has two distinct functional layers that MAY be reasoned about independently.

## Object Security Layer

The object security layer provides cryptographic binding between an HTTP response
and a specific key, using HTTP Message Signatures {{!RFC9421}}. The server signs
a defined set of response components (see Section 6) and includes the signature
in the `Signature` and `Signature-Input` headers. The `DIVE-Keys` header (Section
5) maps each Key ID referenced in the signature metadata to a DNS lookup path.

This layer does not prescribe how the public key is obtained. Any out-of-band
mechanism that delivers a trustworthy public key for the Key ID is sufficient.

## Key Distribution Layer

The key distribution layer uses DNSSEC-protected DNS TXT records to distribute
public keys and verification policy. It answers the question: "for this domain,
what public key corresponds to this Key ID, and what verification policy applies?"

By separating these layers, operators can in principle substitute an alternative
key distribution mechanism (e.g., a transparency log) while reusing the object
security layer as defined here.

# DNS Configuration {#dns-configuration}

## DNSSEC Requirement

DIVE servers MUST enable DNSSEC {{!RFC4033}} for zones publishing DIVE records.
Clients MUST treat any DNS record retrieved without successful DNSSEC validation
as absent.

## Record Format

All DIVE DNS records are TXT records whose values are Structured Field Values
{{!RFC9651}}. Parameter names and string values MUST be lowercase. All timestamps
are Unix timestamps represented as Structured Field Integers.

## Policy Record (`_dive`) {#dive-record}

The `_dive` TXT record is placed at `_dive.<domain>` and applies to that label
and all subordinate labels. A more specific record at a deeper label takes
precedence.

### Parameters

`v` (REQUIRED):
: Protocol version string. MUST be `"dive-draft-01"`. If absent, wrong, or
  unparseable, the client MUST treat DIVE as unsupported for this domain.

`scopes` (OPTIONAL):
: A Structured Field List of scope name strings. If absent, no resource-level
  verification is performed (other directives still apply).

`directives` (OPTIONAL):
: A Structured Field List of directive strings. Defined values:
  - `"https-required"`: the client MUST refuse or upgrade plain-HTTP requests.
  - `"report-only"`: the client MUST NOT block failing resources; it MUST report
    failures if `report-to` is set.

  Unknown directives MUST be ignored.

`cache` (OPTIONAL):
: Cache duration in seconds. Default: `0`. Maximum: `86400`.

`invalidate-keys-cache` (OPTIONAL):
: Unix timestamp. The client MUST purge cached key records with a storage
  timestamp at or before this value. Until the timestamp is reached, the client
  MUST re-query DNS rather than use its cache.

`report-to` (OPTIONAL):
: HTTPS URL for failure reports (Section 8). Plain HTTP URLs MUST be ignored.

Unrecognised parameters MUST be ignored.

### Example

~~~ dns-rr
_dive.example.com.  900  IN  TXT  (
  "v=\"dive-draft-01\", "
  "scopes=(\"strict\"), "
  "directives=(\"https-required\"), "
  "cache=900, "
  "report-to=\"https://reports.example.com/dive\""
)
~~~

## Key Records {#key-records}

Key records are placed at `<Key-ID>._divekey.<domain>`. A Key ID consists of
characters `[A-Za-z0-9_]` and is case-sensitive. At least one valid key record
MUST exist when scopes are declared; if none is reachable, the client MUST refuse
all in-scope resources.

### Parameters

`sig` (REQUIRED):
: Signature algorithm. MUST be `"ed25519"` ({{!RFC8032}} Section 5.1) or
  `"ed448"` ({{!RFC8032}} Section 5.2). All other algorithms MUST be rejected.

`key` (REQUIRED):
: Raw public key bytes as a Structured Field Byte Sequence (base64 within
  colons, per {{!RFC9651}} Section 3.3.5). 32 bytes for Ed25519; 57 bytes for
  Ed448.

`allowed-hash` (OPTIONAL):
: A Structured Field List of permitted hash algorithm names. Permitted values:
  `"sha256"`, `"sha384"`, `"sha512"`, `"sha3-256"`, `"sha3-384"`, `"sha3-512"`.
  MD5, CRC32, and SHA-1 MUST NOT be listed and MUST be rejected. When present,
  the hash algorithm used in the signature MUST appear in this list.

`cache` (OPTIONAL):
: Cache duration in seconds. Default: `0`. Maximum: `86400`.

Unrecognised parameters MUST be ignored.

### Example

~~~ dns-rr
keyABC._divekey.example.com.  900  IN  TXT  (
  "sig=\"ed25519\", "
  "key=:BASE64RAWKEY:, "
  "allowed-hash=(\"sha256\" \"sha384\" \"sha3-256\"), "
  "cache=900"
)
~~~

### Key ID Resolution {#key-resolution}

The client resolves a Key ID to a key record by walking up from the resource's
FQDN toward the policy-record domain, querying `<Key-ID>._divekey.<level>` at
each step. The first record found is used. If a `DIVE-Keys` entry includes an
explicit FQDN qualifier (`keyID@fqdn`), the client MUST query only at that exact
level (and below, toward the resource FQDN); the FQDN MUST be the resource origin
or a parent thereof.

# HTTP Headers {#http-headers}

## `DIVE-Keys`

Maps Key IDs to DNS lookup paths. This header allows the client to locate the
appropriate key record without hardcoding DNS naming conventions.

Format: a comma-separated list of entries. Each entry is either `keyID` (resolve
starting at the resource's FQDN) or `keyID@fqdn` (resolve starting at the
specified FQDN, which MUST be the resource origin or a parent thereof).

~~~ http-message
DIVE-Keys: keyABC, keyDEF@example.com
~~~

The list SHOULD contain no more than three entries.

## RFC 9421 Signature Headers

Signatures are carried in `Signature` and `Signature-Input` as defined in
{{!RFC9421}}. The `keyid` parameter in the signature metadata MUST match a Key ID
listed in `DIVE-Keys`. The DIVE-specific signature components and parameters are
defined in Section 6.

# Applying RFC 9421 to DIVE {#signatures}

DIVE uses HTTP Message Signatures {{!RFC9421}} as its object security mechanism.

## Covered Components

Each DIVE signature MUST cover the following derived components, as defined in
{{!RFC9421}} Section 2.2:

- `"@method"`: the HTTP request method.
- `"@target-uri"`: the full request URI.
- `"@status"`: the HTTP response status code.

In addition, the signature MUST cover the response content using the
`content-digest` component ({{!RFC9421}} Section 2.1). The `Content-Digest`
header MUST be present in the response and MUST be computed per {{!RFC9530}}.
Permitted digest algorithms are: `sha-256`, `sha-384`, `sha-512`, `sha3-256`,
`sha3-384`, `sha3-512`. MD5, CRC32, and SHA-1 MUST NOT be used.

Servers MUST NOT include `content-digest` as a covered component without also
including `Content-Digest` in the response.

## Signature Parameters

The `Signature-Input` header MUST include the following parameters
({{!RFC9421}} Section 2.3):

- `keyid`: MUST match a Key ID listed in `DIVE-Keys`.
- `alg`: MUST be `"ed25519"` or `"ed448"`, consistent with the key record.
- `created`: Unix timestamp of signature creation.
- `expires` (OPTIONAL but RECOMMENDED): Unix timestamp after which the
  signature MUST be rejected.
- `nonce` (OPTIONAL): a unique value to prevent replay across identical
  responses.

## Example

~~~ http-message
Content-Digest: sha-256=:BASE64HASH:
Signature-Input: dive-sig=("@method" "@target-uri" "@status" \
    "content-digest");keyid="keyABC";alg="ed25519";\
    created=1700000000;expires=1700003600
Signature: dive-sig=:BASE64SIG:
DIVE-Keys: keyABC
~~~

# Client Verification Algorithm {#client-implementation}

DIVE applies based on the origin of the fetched resource. Third-party resources
are verified against the DIVE policy of their own origin domain.

## Step 1: Policy Discovery

Query `_dive.<FQDN>` for a TXT record, walking up the DNS hierarchy (removing
the leftmost label) until a record is found or no labels remain. Use the most
specific match. If no record is found, or if DNSSEC validation failed, DIVE does
not apply.

Validate the `v` parameter; if missing or incorrect, DIVE does not apply.
Apply `invalidate-keys-cache`, `https-required`, and cache the record per `cache`.

## Step 2: Scope Determination

If `scopes` is absent or empty, no resource-level verification is performed.
Otherwise, determine whether the resource falls within a declared scope:

- `strict`: all resources under the covered domain are in scope.
- Custom (`x-` prefix): detection logic is application-defined. Unknown custom
  scopes MUST be ignored.

If the resource is not in any declared scope, no verification is performed.

## Step 3: Header Validation

For in-scope resources, the client MUST verify:

1. `DIVE-Keys` is present and syntactically valid.
2. `Content-Digest` is present and its algorithm is permitted.
3. `Signature` and `Signature-Input` are present and parse per {{!RFC9421}}.
4. At least one `Signature-Input` entry references a `keyid` listed in
   `DIVE-Keys`.

If any check fails, the client MUST refuse the resource.

## Step 4: Key Resolution

For each Key ID in `DIVE-Keys` that is referenced by a `Signature-Input` entry,
resolve the key record per Section 4.4. DNSSEC validation is required. Cache
the record per its `cache` parameter, subject to the 86400-second maximum.

## Step 5: Signature Verification

For each Key ID with a resolved key record:

1. Reconstruct the signature base per {{!RFC9421}} Section 2.5 from the
   covered components.
2. Verify the `Signature` value against the signature base using the public key
   and algorithm from the key record.
3. If `allowed-hash` is present, confirm the `Content-Digest` algorithm is
   listed; if not, treat verification as failed for this Key ID.
4. If `expires` is present, confirm the current time is before the expiry; if
   not, treat verification as failed.

If at least one Key ID verifies successfully, the resource MUST be accepted.
If all Key IDs fail, the client MUST refuse the resource (subject to
`report-only`).

The client MUST NOT act on the resource body before verification completes.
DNS queries MAY be issued concurrently with body download (Section 7.6).

## Step 6: Enforcement and Reporting

On failure, if `report-only` is present: accept the resource and send a report
(Section 8) if `report-to` is set. Otherwise: block the resource.

## Parallelism

The client MAY download the response body concurrently with DNS resolution but
MUST NOT deliver or act upon the body until verification is complete.

# Verification Failure Reporting {#reporting}

When a resource fails verification and `report-to` is set, the client MUST POST
to that URL with `Content-Type: application/json`.

~~~ json
{
  "report-version": "0.1",
  "timestamp": 1700000000,
  "client": { "user-agent": "ExampleClient/1.0" },
  "policy": {
    "domain": "example.com",
    "fqdn": "sub.example.com",
    "dnssec-validated": true
  },
  "resource": {
    "url": "https://sub.example.com/app.js",
    "method": "GET",
    "status-code": 200,
    "scope": "strict"
  },
  "headers-received": {
    "dive-keys": "keyABC",
    "signature-input": "dive-sig=(...)",
    "content-digest": "sha-256=:BASE64HASH:"
  },
  "key-resolution": [
    {
      "key-id": "keyABC",
      "fqdn-queried": "keyABC._divekey.example.com",
      "found": true,
      "dnssec-validated": true,
      "sig-algorithm": "ed25519"
    }
  ],
  "validation": {
    "failure-reason": "signature-mismatch",
    "final-decision": "blocked"
  }
}
~~~

Absent or unavailable fields MUST be `null`. Failure to deliver the report has
no effect on the acceptance or refusal of the resource.

`failure-reason` permitted values: `"missing-headers"`, `"key-not-found"`,
`"key-invalid"`, `"dnssec-unavailable"`, `"hash-algorithm-not-allowed"`,
`"signature-mismatch"`, `"signature-expired"`, `"no-valid-key"`.

`final-decision` permitted values: `"blocked"`, `"allowed-report-only"`.

# Operational Guidance {#operational-security}

## Key Rotation

1. Generate a new key pair; publish the new public key under a new Key ID in DNS.
2. Wait for the old key record's TTL to expire.
3. Update all resources to use signatures under the new Key ID.
4. Remove the old key record from DNS.

Key IDs MUST NOT be reused after their key record is removed.

## Key Compromise

Upon key compromise:

1. Begin key rotation immediately.
2. Set `invalidate-keys-cache` in all affected `_dive` records to a timestamp
   at or after the moment of compromise.
3. Remove the compromised key record once the new key is operational.

Do NOT set `report-only` during compromise remediation; doing so disables
enforcement.

## Private Key Storage

Private signing keys SHOULD NOT reside on servers that generate or serve HTTP
responses. Keys SHOULD be kept offline or in hardware security modules (HSMs),
with signatures pre-computed at deployment time.

## DNS TTL Recommendations

Operators SHOULD set the DNS TTL of both `_dive` and `_divekey` records to 900
seconds to allow rapid key revocation while supporting caching.

# Security Considerations {#security-considerations}

## Threat Model

DIVE protects against an attacker who controls the origin web server but not
the DNS infrastructure. Such an attacker can serve arbitrary HTTP responses but
cannot forge DNSSEC-validated records and cannot therefore publish a replacement
public key.

DIVE does NOT protect against simultaneous compromise of the origin server and
DNS infrastructure, nor against compromise of private signing keys.

## DNSSEC as Trust Anchor

DNSSEC is DIVE's root of trust. Clients MUST implement DNSSEC validation, either
directly (stub validator, RECOMMENDED) or by delegating to a resolver over an
encrypted channel (DoH {{?RFC8484}} or DoT {{?RFC7858}}) with the AD bit
{{!RFC4035}}. The AD bit MUST NOT be trusted over an unencrypted channel or from
a resolver outside the client's control.

## Algorithm Restrictions

Only Ed25519 and Ed448 are permitted for signing. Only SHA-2 and SHA-3 variants
(256-bit or wider) are permitted for hashing. These restrictions prevent
downgrade attacks.

## Cache Poisoning

The 86400-second cache cap (Section 7.4) limits the window during which a
poisoned cache entry remains effective. DNSSEC substantially mitigates cache
poisoning since an attacker without the DNS signing key cannot inject validated
records.

## Relationship to RFC 9421

DIVE profiles RFC 9421 by mandating a specific set of covered components and
constraining algorithm choices. Implementations MUST comply with the full
requirements of {{!RFC9421}} in addition to the DIVE-specific constraints in
Section 6.

## Privacy

DNS queries for `_dive` and `_divekey` records may reveal resource access
patterns to the resolver. DoH or DoT SHOULD be used. The `report-to` endpoint
receives request metadata; operators MUST ensure the endpoint complies with
applicable privacy regulations.

## HTTP Cache Interaction

DIVE headers in a cached HTTP response MUST be re-verified against current DNS
at the time the cached response is used. Operators SHOULD purge affected cache
entries as part of key rotation to prevent stale-header verification failures.

# IANA Considerations {#iana-considerations}

## HTTP Response Header Fields

IANA is requested to register the following in the "HTTP Field Name Registry":

| Field Name  | Status      | Reference     |
|-------------|-------------|---------------|
| `DIVE-Keys` | provisional | This document |

## DIVE Scope Registry

IANA is requested to create a "DIVE Scope Names" registry under a new "DIVE"
registry group, with "Specification Required" registration policy ({{!RFC8126}}).

| Scope Name | Description                          | Reference     |
|------------|--------------------------------------|---------------|
| `strict`   | All resources under the covered domain | This document |

Custom scopes using the `x-` prefix are not subject to IANA registration.

## DIVE Directive Registry

IANA is requested to create a "DIVE Directive Names" registry under the same
group, with "Specification Required" registration policy.

| Directive Name   | Description                                             | Reference     |
|------------------|---------------------------------------------------------|---------------|
| `https-required` | Client MUST NOT issue or accept plain-HTTP requests.   | This document |
| `report-only`    | Client MUST NOT block failures; MUST report them.      | This document |

# Implementation Status

An experimental implementation is available at:

- OpenDIVE Client: https://github.com/diveprotocol/opendive-client
- Protocol information: https://diveprotocol.org

{backmatter}
