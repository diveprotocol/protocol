---

title: "Domain-based Integrity Verification Enforcement (DIVE) Version 0.1"
abbrev: "DIVE"
docname: draft-callec-dive-01
submissiontype: IETF
date: 2026-04-01
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

Domain-based Integrity Verification Enforcement (DIVE) is an application-layer protocol that provides cryptographic integrity and authenticity verification of HTTP response bodies by leveraging the Domain Name System Security Extensions (DNSSEC) as an out-of-band distribution channel for public keys.

DIVE has two independent components: (1) an object-security layer, which uses HTTP Message Signatures {{!RFC9421}} to carry per-resource signatures in HTTP response headers, and (2) a DNS key-distribution layer, which publishes public keys and policy in DNSSEC-protected TXT records. A client implementing DIVE verifies each covered resource against the corresponding DNS-published public key before accepting it. An attacker must therefore compromise both the DNS infrastructure and the origin server simultaneously to deliver a tampered resource to a DIVE-compliant client.

--- middle

# Introduction

Transport-layer security protects data in transit but does not protect against a compromised origin server that serves malicious content over a legitimate TLS session. Subresource Integrity (SRI) embeds expected hashes in HTML markup, but because that markup is itself served by the potentially compromised host, it provides limited security during a full infrastructure breach.

DIVE addresses this threat by separating two concerns:

- **Object security**: HTTP Message Signatures {{!RFC9421}} carry a cryptographic signature over the response body. The signature travels with the resource and can be verified at any point after receipt.
- **Key distribution**: DNSSEC-protected DNS TXT records publish the authoritative public keys and policy. Because DNS is administered independently from the origin server, an attacker who controls only the origin cannot forge a valid DNS-published key.

DIVE is designed for non-browser automated clients such as package managers, CLI tools, and software-update agents. Browser clients MUST NOT implement or enforce DIVE.

DIVE is incrementally deployable: servers add DNS records and HTTP signatures; clients that do not implement DIVE are unaffected.

# Terminology {#terminology}

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 {{!RFC2119}} {{!RFC8174}} when, and only when, they appear in all capitals, as shown here.

DIVE client:
: An HTTP client that implements the verification algorithm defined in this document.

DIVE server:
: An HTTP origin server that publishes DIVE DNS records and includes DIVE-conformant HTTP Message Signatures on covered resources.

Resource:
: A single HTTP response body received with status code 200.

Scope:
: A named category of resources subject to DIVE verification ({{scopes}}).

Key ID:
: An operator-assigned label that names a specific DNS key record and is referenced in HTTP Message Signatures via the `keyid` parameter ({{!RFC9421}} Section 2.3).

Policy record:
: The `_dive` DNS TXT record that publishes the DIVE configuration for a domain ({{dive-record}}).

Key record:
: A DNS TXT record that publishes a public key, placed at `<Key-ID>._divekey.<domain>` ({{key-records}}).

Structured Field:
: A value encoded per {{!RFC9651}}.

Unix timestamp:
: Seconds since 1970-01-01T00:00:00Z (UTC), excluding leap seconds, as a signed integer.

# Architecture

DIVE separates object security from key distribution:

~~~
  Origin Server                  DNS (DNSSEC)
  +------------------+           +----------------------+
  | Signs response   |           | _dive TXT: policy    |
  | body with Ed25519|           | <keyid>._divekey TXT:|
  | private key      |           |   public key, params |
  +--------+---------+           +-----------+----------+
           |                                 |
           | HTTP response                   | DNS/DNSSEC query
           | (Signature: header)             |
           v                                 v
  +--------+---------------------------------+----------+
  |                   DIVE Client                       |
  |  1. Discover policy via _dive DNS record            |
  |  2. Determine resource scope                        |
  |  3. Resolve public key from _divekey DNS record     |
  |  4. Verify HTTP Message Signature over response body|
  +-----------------------------------------------------+
~~~

The Signature and Signature-Input headers are defined by {{!RFC9421}}. The DNS records are defined by this document.

# Scopes {#scopes}

A scope identifies the category of resources to which DIVE verification applies.

## Standard Scopes

`strict`:
: DIVE verification MUST be applied to ALL resources served under the domain covered by the policy record.

## Custom Scopes

Operators MAY define custom scopes for application-specific resource categories. Custom scope names MUST begin with `x-`, be entirely lowercase, and contain only `a-z` and `-` after the prefix.

Custom scopes are intended for closed environments where server and client are under the same operator's control. Detection logic for custom scopes is application-defined.

A DIVE client that does not recognise a custom scope MUST ignore it.

# DNS Configuration {#dns-configuration}

## DNSSEC Requirement

A DIVE server SHOULD enable DNSSEC {{!RFC4033}} for all zones publishing DIVE records. If a client retrieves a `_dive` record without DNSSEC validation, it MUST treat DIVE as not supported for that domain.

## Record Format

All DIVE DNS records are DNS TXT records. Values MUST be formatted as Structured Field Values {{!RFC9651}}. Parameter names and values MUST be lowercase unless otherwise stated. Timestamps are Unix timestamps represented as Structured Field Integers.

## Policy Record (`_dive`) {#dive-record}

The `_dive` TXT record is placed at the `_dive` label of the domain or subdomain it governs (e.g., `_dive.example.com`). A record at a given level applies to all subordinate labels unless overridden by a more specific record.

### Example

~~~ dns-rr
_dive.example.com.  900  IN  TXT  (
  "v=\"dive-draft-01\", "
  "scopes=(\"strict\"), "
  "directives=(\"https-required\"), "
  "cache=900, "
  "invalidate-keys-cache=1700000000, "
  "report-to=\"https://reports.example.com/dive\""
)
~~~

### Parameters

`v` (REQUIRED):
: Protocol version string. MUST be `"dive-draft-01"`. If absent, unrecognised, or unparseable, the client MUST treat DIVE as not supported for this domain.

`scopes` (OPTIONAL):
: Structured Field List of scope names (Strings). If absent or empty, no resource-level verification is performed, though other directives still apply.

`directives` (OPTIONAL):
: Structured Field List of behavioural directives (Strings):

- `"https-required"`: the client MUST refuse or upgrade plain-HTTP requests for resources under the covered domain.
- `"report-only"`: the client MUST NOT block resources that fail DIVE verification; it MUST report failures per {{reporting}} instead.

Unrecognised directive values MUST be ignored.

`cache` (OPTIONAL):
: Structured Field Integer. Number of seconds the client MAY cache this record (default: 0). MUST NOT exceed 86400 ({{cache-management}}).

`invalidate-keys-cache` (OPTIONAL):
: Structured Field Integer (Unix timestamp). When present, the client MUST purge cached key records for the domain stored at or before this timestamp. If the timestamp is in the future, the client MUST issue a fresh DNS query on each verification attempt until the timestamp has passed.

`report-to` (OPTIONAL):
: Structured Field String. An absolute HTTPS URL to which failure reports MUST be sent ({{reporting}}). Plain HTTP URLs MUST be ignored.

Unrecognised parameters MUST be ignored.

**Operational note:** Operators SHOULD set the DNS TTL of `_dive` records to 900 seconds.

## Key Records {#key-records}

When one or more scopes are declared, at least one key record MUST be present and valid. If no valid key record is reachable, the client MUST refuse all resources in the declared scopes.

Key records are DNS TXT records at `<Key-ID>._divekey.<domain>`. A Key ID MAY contain `A-Z`, `a-z`, `0-9`, and `_`; it MUST NOT contain other characters; it is case-sensitive.

### Example

~~~ dns-rr
keyABC._divekey.example.com.  900  IN  TXT  (
  "sig=\"ed25519\", "
  "key=:BASE64RAWKEY:, "
  "allowed-hash=(\"sha256\" \"sha384\" \"sha3-256\"), "
  "cache=900"
)
~~~

### Parameters

`sig` (REQUIRED):
: Signature algorithm. MUST be one of `"ed25519"` ({{!RFC8032}} Section 5.1) or `"ed448"` ({{!RFC8032}} Section 5.2). All other algorithms MUST be rejected.

`key` (REQUIRED):
: Structured Field Byte Sequence containing the raw public key bytes for the declared algorithm (32 bytes for Ed25519, 57 bytes for Ed448).

`allowed-hash` (OPTIONAL):
: Structured Field List of permitted hash algorithms (Strings). Permitted values: `"sha256"`, `"sha384"`, `"sha512"`, `"sha3-256"`, `"sha3-384"`, `"sha3-512"`. MD5, CRC32, and SHA-1 MUST NOT be listed and MUST be rejected. When present, the hash algorithm used in the corresponding signature MUST appear in this list; otherwise verification MUST be treated as failed.

`cache` (OPTIONAL):
: Structured Field Integer. Number of seconds the client MAY cache this record (default: 0). MUST NOT exceed 86400 ({{cache-management}}).

Unrecognised parameters MUST be ignored.

**Operational note:** Operators SHOULD set the DNS TTL of key records to 900 seconds and SHOULD perform regular key rotation ({{key-rotation}}). A Key ID SHOULD NOT be reused after its associated record has been removed.

## Subdomain-Specific Records

Operators MAY publish policy and key records at any subdomain level. The most specific matching record takes precedence.

# HTTP Signatures {#http-signatures}

DIVE uses HTTP Message Signatures {{!RFC9421}} to carry per-resource signatures. A DIVE server MUST include `Signature` and `Signature-Input` response headers on all 200 responses for resources within a declared scope.

## Signature Coverage

Each DIVE signature MUST cover the `content-digest` derived component ({{!RFC9421}} Section 2.4), which commits the signature to the response body. Servers MUST include a `Content-Digest` header {{!RFC9530}} in each covered response.

## Key Identification and Multiple Signatures

The `keyid` parameter in `Signature-Input` MUST be set to the Key ID of the DNS key record used to create the signature. The `alg` parameter MUST be set to `"ed25519"` or `"ed448"` as appropriate.

To support key rotation ({{key-rotation}}), a server MAY include multiple signatures in a single response by providing multiple `Signature` and `Signature-Input` entries ({{!RFC9421}} Section 4.2), each referencing a different Key ID. A DIVE client MUST attempt verification with each signature entry in order and MUST accept the resource as soon as one verification succeeds.

### Example

The following example illustrates two concurrent signatures for key rotation. `keyABC` is the current signing key; `keyDEF` is a newly introduced key being rolled in.

~~~ http-message
Content-Digest: sha-256=:BASE64DIGEST:
Signature-Input: sigABC=("content-digest");keyid="keyABC";alg="ed25519", \
                 sigDEF=("content-digest");keyid="keyDEF";alg="ed25519"
Signature: sigABC=:BASE64SIG1:, \
           sigDEF=:BASE64SIG2:
~~~

Clients that have already cached `keyABC` will verify with `sigABC`; clients that have already rotated to `keyDEF` will verify with `sigDEF`.

The list of signatures SHOULD contain no more than three entries to maintain compatibility with HTTP implementations that impose header-length limits.

## Hash Algorithm Binding

The hash algorithm used to compute `Content-Digest` MUST be consistent with the `allowed-hash` parameter of the key record ({{key-records}}), when that parameter is present.

Permitted hash algorithms for `Content-Digest`: `sha-256`, `sha-384`, `sha-512`, `sha3-256`, `sha3-384`, `sha3-512`. MD5, CRC32, and SHA-1 MUST NOT be used and MUST be rejected by the client.

# Client Implementation {#client-implementation}

## Step 1: Policy Discovery {#policy-discovery}

The client MUST locate the applicable `_dive` TXT record by querying from the resource's full FQDN upward, one label at a time, until a record is found or no labels remain. The most specific (deepest) record found applies.

If no record is found, DIVE is not supported; the client MUST NOT block the resource on DIVE grounds.

If the policy record was retrieved without DNSSEC validation, the client MUST treat DIVE as not supported.

If a valid cached copy of the policy record has not expired, the client MUST use it.

Upon retrieving the record, the client MUST verify the `v` parameter and parsability. It MUST apply `invalidate-keys-cache` and the `https-required` directive as specified in {{dive-record}}. It MUST cache the record per the `cache` parameter, subject to the 86400-second cap.

DIVE verification is based on the resource's own origin. If a resource is fetched from a third-party domain, the client MUST look up that domain's `_dive` record, not the referring domain's.

## Step 2: Scope Determination

If `scopes` is absent or empty, no resource-level verification is performed. Other directives (e.g., `https-required`) still apply.

If the resource falls within at least one declared scope, proceed to Step 3. Standard scope detection:

- `strict`: all resources under the covered domain are in scope.

Custom scope detection is application-defined.

## Step 3: Signature Header Validation

The client MUST verify that `Signature` and `Signature-Input` headers are present and syntactically conformant per {{!RFC9421}}. If either header is absent or invalid, the client MUST refuse the resource.

The client MUST also verify that a `Content-Digest` header is present and parseable per {{!RFC9530}}.

## Step 4: Key Resolution {#key-resolution}

For each signature entry in `Signature-Input`, the client resolves the key record as follows:

If `keyid` contains an `@`-qualified FQDN (e.g., `keyABC@example.com`), the client MUST verify that the specified FQDN is equal to or a parent of the resource's origin FQDN. If not, the entry MUST be treated as invalid. The client MUST query exactly `<Key-ID>._divekey.<fqdn>` and MUST NOT search at levels above the specified FQDN.

Otherwise, the client queries from the resource's FQDN upward, label by label, stopping at the level of the applicable policy record, querying `<Key-ID>._divekey.<level>` at each step. The first record found is used.

In all cases, the DNS query MUST be DNSSEC-validated. A record retrieved without DNSSEC validation MUST be treated as absent.

If no key record is found after cache eviction and a fresh DNS query, the Key ID is unresolvable and verification fails for that entry.

The client MUST cache a valid key record per its `cache` parameter, subject to the 86400-second cap and any `invalidate-keys-cache` constraint.

## Step 5: Signature Verification

For each signature entry, the client MUST:

1. Recompute the `Content-Digest` over the received response body using the hash algorithm declared in the `Content-Digest` header and verify it matches.
2. Reconstruct the signature base as defined by {{!RFC9421}} Section 2.5 from the `Signature-Input` components.
3. Retrieve the public key from the resolved key record.
4. If `allowed-hash` is present in the key record, verify the hash algorithm in `Content-Digest` is listed; if not, fail this entry.
5. Verify the decoded signature over the signature base using the algorithm declared in `sig` of the key record.

If at least one entry verifies successfully, the resource MUST be accepted.

If all entries fail:

- By default, the resource MUST be rejected.
- If `report-only` is present, the resource MUST be accepted; a report MUST be sent per {{reporting}}.

The client MUST NOT act upon the resource body before completing verification. The body MAY be downloaded concurrently with DNS resolution, but MUST NOT be delivered to the application until verification is complete.

## Step 6: Reporting {#reporting}

When a resource fails verification (whether blocked or allowed under `report-only`), and `report-to` is set, the client MUST POST to that URL with `Content-Type: application/json`:

~~~ json
{
  "report-version": "0.1",
  "timestamp": 1700000000,
  "client": {
    "user-agent": "ExampleClient/1.0"
  },
  "policy": {
    "domain": "example.com",
    "fqdn": "sub.example.com",
    "dnssec-validated": true
  },
  "resource": {
    "url": "https://sub.example.com/static/app.js",
    "method": "GET",
    "status-code": 200,
    "scope": "strict"
  },
  "headers-received": {
    "signature-input": "sig1=(\"content-digest\");keyid=\"keyABC\";alg=\"ed25519\"",
    "content-digest": "sha-256=:BASE64DIGEST:"
  },
  "key-resolution": [
    {
      "key-id": "keyABC",
      "fqdn-queried": "keyABC._divekey.sub.example.com",
      "found": true,
      "dnssec-validated": true,
      "sig-algorithm": "ed25519"
    }
  ],
  "validation": {
    "hash-algorithm": "sha-256",
    "hash-computed": "BASE64HASHVALUE",
    "signature-valid": false,
    "failure-reason": "signature-mismatch",
    "final-decision": "blocked"
  }
}
~~~

Fields that are absent or not applicable MUST be set to JSON `null`.

`failure-reason` permitted values: `"missing-headers"`, `"key-not-found"`, `"key-invalid"`, `"dnssec-unavailable"`, `"hash-algorithm-not-allowed"`, `"signature-mismatch"`, `"no-valid-key"`.

`final-decision` permitted values: `"blocked"`, `"allowed-report-only"`.

Failure to deliver a report MUST NOT affect the resource acceptance decision.

## Cache Management {#cache-management}

Clients MUST enforce an absolute maximum cache duration of 86400 seconds for all DIVE records, regardless of the `cache` parameter. When a key record cannot be resolved, the client MUST evict any cached entry and issue a fresh DNS query before failing.

# Operational Security {#operational-security}

## Key Rotation {#key-rotation}

To rotate a signing key without service disruption:

1. Generate a new key pair and publish the new public key under a new Key ID in DNS.
2. Wait for the old key record's DNS TTL to expire.
3. Begin including both the old and new signatures in HTTP responses (using multiple `Signature` entries per {{http-signatures}}).
4. Once all clients have had the opportunity to cache the new key, remove the old signature from responses.
5. Remove the old key record from DNS.

Key IDs MUST NOT be reused after their associated key records have been removed from DNS.

## Response to Key Compromise

Upon discovering a compromised private key, the operator MUST:

1. Immediately begin key rotation ({{key-rotation}}).
2. Set `invalidate-keys-cache` in all applicable `_dive` policy records to a timestamp at or after the time of compromise.
3. Remove the compromised key record from DNS as soon as the new key is operational.

Operators MUST NOT set `report-only` as a temporary measure during key compromise remediation.

## Private Key Storage

Operators SHOULD NOT store private signing keys on HTTP servers. Keys SHOULD be kept in offline or HSM environments, with signatures pre-computed and injected at deployment time.

# Security Considerations {#security-considerations}

## Threat Model

DIVE protects against an attacker who has compromised the origin web server but not the DNS infrastructure. Such an attacker cannot publish a forged DNSSEC-validated key record, so a DIVE-compliant client will reject any response not signed with a DNS-published key.

DIVE does NOT protect against simultaneous compromise of both the DNS infrastructure and the origin server, or against compromise of the private signing keys.

## DNSSEC as Trust Anchor

DNSSEC is the root of trust for DIVE. Clients MUST obtain DNSSEC validation status for all DNS records they retrieve. Two models are recognised:

- **Stub validator** (RECOMMENDED): the client performs DNSSEC verification itself.
- **Validating resolver**: the client trusts the AD bit from a resolver. The connection to the resolver MUST be over DoH {{?RFC8484}} or DoT {{?RFC7858}}.

A record for which DNSSEC validation cannot be confirmed MUST be treated as absent.

## Algorithm Restrictions

Only Ed25519 and Ed448 are permitted for signing. Only SHA-256, SHA-384, SHA-512, SHA3-256, SHA3-384, and SHA3-512 are permitted for hashing. Clients MUST reject records or responses referencing any other algorithm. This prevents downgrade attacks.

## Cache Poisoning

The 86400-second cache cap limits the impact of cache-poisoning attacks in which a malicious record with an artificially long `cache` value is injected. DNSSEC substantially mitigates this attack.

## Privacy

DNS queries for `_dive` and `_divekey` records may reveal resource-access patterns to the resolver. Clients SHOULD use DoH or DoT.

Failure reports sent to `report-to` include the resource URL and User-Agent. Operators MUST handle report data in accordance with applicable privacy regulations.

## Scope of Protection

DIVE verifies response body integrity and authenticity. It does not protect HTTP response headers other than those defined in {{!RFC9421}} and {{!RFC9530}}, nor request parameters or cookies.

## Interaction with HTTP Caches

DIVE headers in a cached response MUST be re-verified against current DNS records when the cached response is used. Operators SHOULD purge cached entries as part of key rotation to avoid stale-signature verification failures.

# IANA Considerations {#iana-considerations}

## DIVE Scope Registry

IANA is requested to create the registry "DIVE Scope Names" under a new registry group "Domain-based Integrity Verification Enforcement (DIVE)", with policy "Specification Required" {{!RFC8126}}.

Initial contents:

| Scope Name | Description                          | Detection Criterion          | Reference     |
| ---------- | ------------------------------------ | ---------------------------- | ------------- |
| `strict`   | All resources in the covered domain  | Applies to all resources.    | This document |

Custom scopes using the `x-` prefix are not subject to IANA registration.

## DIVE Directive Registry

IANA is requested to create the registry "DIVE Directive Names" under the same registry group, with policy "Specification Required" {{!RFC8126}}.

Initial contents:

| Directive Name   | Description                                                          | Reference     |
| ---------------- | -------------------------------------------------------------------- | ------------- |
| `https-required` | Client MUST NOT issue plain-HTTP requests; MUST upgrade or abort.    | This document |
| `report-only`    | Client MUST NOT block failures; MUST report them instead.            | This document |

## DNS Resource Record Types

No new DNS resource record types are defined. DIVE uses DNS TXT records (type 16) {{!RFC1035}}.

# Implementation Status

An experimental implementation of the DIVE protocol is available:

- OpenDIVE Client: [https://github.com/diveprotocol/opendive-client](https://github.com/diveprotocol/opendive-client)
- Protocol information: [https://diveprotocol.org](https://diveprotocol.org)

# Acknowledgements

The author would like to thank Benjamin Schwartz for his review and constructive feedback on earlier versions of this document.

{backmatter}
