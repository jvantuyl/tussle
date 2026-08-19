# Upstream Compatibility and Upgrade Assessment

Status of Tussle against upstream tus clients and the tus protocol, and an
estimate of the work required to close the remaining gaps.

Last reviewed: 2026-08-19, against Tussle v0.4.0.

## Upstream state

### tus-js-client

| Channel | Version | Released |
|---|---|---|
| `latest` | **4.3.1** | 2025-01-16 |
| `next` | 5.0.0-pre2 | 2026-01-13 |

`5.0.0-pre2` is a pre-release created to exercise automated publishing from
GitHub; it carries no functional changes over the 4.x line. The last release
with behavioural changes is 4.3.0, which added experimental support for IETF
draft revisions 04 and 05.

tus-js-client still defaults to `protocol: 'tus-v1'`, i.e. the tus 1.0.0
protocol that Tussle implements. **Nothing released upstream breaks Tussle, and
no work is required to keep current clients working.**

### tus protocol / IETF standardisation

The tus 1.0.0 protocol is stable and unchanged. Its successor is being
standardised in the IETF HTTP working group as
[Resumable Uploads for HTTP](https://datatracker.ietf.org/doc/draft-ietf-httpbis-resumable-upload/),
currently at **draft-12 / interop version 9**, intended status Proposed
Standard.

Note the version skew: tus-js-client's experimental modes speak draft-03 and
draft-05, while the specification has advanced to draft-12. Interop versions
are deliberately incompatible across draft revisions, so a server built against
draft-12 today would not interoperate with any shipping client, and a server
built against draft-05 would target an obsolete revision.

## Gap analysis

What Tussle implements today: the tus 1.0.0 core, plus the Creation (without
deferred length), Creation With Upload, Termination and Expiration extensions.

### Closed in v0.4.0

| Gap | Resolution |
|---|---|
| `expiration` missing from `Tus-Extension` | Advertised whenever an `:expiration_period` is configured |
| `Tus-Resumable` absent from some error responses | Added to the `PATCH` 404/409/413/400 and `POST` 413 branches |
| `400` instead of `412` for a missing `Tus-Resumable` | Now `412 Precondition Failed` with a `Tus-Version` header |
| CORS response header guidance | Documented in the README with a worked example |
| `creation-with-upload` | Implemented; body accepted on creation when labelled `application/offset+octet-stream` |

### Still open

| # | Gap | Client trigger | State today | Effort |
|---|---|---|---|---|
| 1 | `checksum` | `Upload-Checksum` supplied via client hooks | Unsupported; header ignored | S–M, ~1 day |
| 2 | `creation-defer-length` | `uploadLengthDeferred: true`, needed for streaming sources | `Upload-Defer-Length` ignored and size falls back to 0, so the first PATCH fails the size check | M, ~1–2 days |
| 3 | `concatenation` | `parallelUploads > 1` | Unsupported. Requires partial uploads plus a final concatenation, which extends the `Tussle.Storage` behaviour and therefore affects `tus_storage_s3` | L, ~3–5 days |
| 4 | IETF Resumable Uploads for HTTP | `protocol: 'ietf-draft-05'` | None | XL, ~2–3 weeks |

### What the IETF draft actually involves

Beyond a second request/response vocabulary, IETF draft support needs:

- `104 (Upload Resumption Supported)` interim responses, i.e. `Plug.Conn.inform/3`
  plus an adapter that can send 1xx informational responses.
- Structured Fields parsing and serialisation for `Upload-Complete` (Boolean),
  `Upload-Offset`, `Upload-Length` and the `Upload-Limit` Dictionary. Elixir has
  no Structured Fields implementation in this dependency tree.
- The `application/partial-upload` media type for append requests.
- RFC 9457 problem types for mismatching offset and inconsistent length.
- `Upload-Draft-Interop-Version` negotiation, which must be bumped on every
  breaking draft revision.

## Recommendation

**Do on demand.** Items 1, 2 and 3, driven by real requirements. Item 3 is the
one that reaches into the storage backends, so it should not be started without
a concrete need for parallel uploads.

**Defer item 4.** Implementing it now means choosing between a draft revision no
client speaks (draft-12) and one the specification has left behind (draft-05).
The sensible trigger to revisit is the draft reaching RFC status, or
tus-js-client shipping non-experimental support for a later revision. Watch
[tus/rufh-implementations](https://github.com/tus/rufh-implementations) for the
interop matrix.

## Unrelated follow-up noted while reviewing

`test/test_helper.exs` builds test connections through
Plug.Adapters.Test.Conn.conn/4, which is `@moduledoc false` private API rather
than the public `Plug.Test.conn/3`. It still works on Plug 1.20.3, but it is the
most likely thing to break on a future Plug upgrade. Migrating the helper to
`Plug.Test.conn/3` plus `put_req_header/3` would touch all six request test
files.
