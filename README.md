# ashid - CFML port

[![ForgeBox Version](https://www.forgebox.io/api/v1/entry/ashid/badges/version)](https://www.forgebox.io/view/ashid)
[![ForgeBox Downloads](https://www.forgebox.io/api/v1/entry/ashid/badges/downloads)](https://www.forgebox.io/view/ashid)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Time-sortable, prefixed unique identifiers using Crockford Base32. Pure-CFML port of [`agency.wilde:ashid`](https://github.com/wildeagency/ashid). IDs produced by this library are byte-for-byte interchangeable with the **upstream v1.0.3** Kotlin and TypeScript implementations (see [Upstream version notes](#upstream-version-notes) below - note that the published Maven JAR is older v1.0.0 and produces different output for prefixed IDs).

```
ashid("user")    // user_1kbg1jmtt4v3x8k9p2m1np0
ashid()          // 01kbg1jmtt4v3x8k9p2m1n0w
ashid4("token")  // token_<13 random><13 random>
```

## Why

UUIDs are opaque. ashid IDs are self-documenting (`user_...`, `evt_...`), lexicographically time-sortable, double-click-selectable, and case-insensitive. Inspired by Stripe's ID format, Crockford's Base32, ULID, and TypeID.

## Install

CommandBox / ForgeBox:

```bash
box install ashid
```

Or copy `Ashid.cfc`, `EncoderBase32Crockford.cfc`, and `helpers.cfm` into your project and reference them via a CFML mapping.

## Quick start

**Try it without setup:** Visit `http://127.0.0.1:8123/demo.cfm` after starting any CFML server in this directory. The demo lets you generate IDs, parse them, and verify every API method without installing anything else.

```cfc
// Direct CFC use
var ashid = new ashid.Ashid();

ashid.generate("user");                   // user_1kbg1jmtt4v3x8k9p2m1np0
ashid.generate4("token");                 // token_<26-char base, two random components>
ashid.parse(id);                          // ["user_", "1kbg1jmtt", "4v3x8k9p2m1np0"]
ashid.parse(id, "struct");                // { prefix, timestamp, random }
ashid.timestamp(id);                      // 1778025600000 (ms since epoch)
ashid.isValid(id);                        // true / false
ashid.normalize(id);                      // canonical lowercase form
```

Top-level UDF style (matches the upstream calling convention):

```cfc
// In Application.cfc onApplicationStart:
application.ashid = new ashid.Ashid();
include "/ashid/helpers.cfm";

// Then anywhere:
var id = ashid("user");
var parts = parseAshid(id);          // [prefix, ts, random]
```

The `helpers.cfm` resolver looks for the singleton in `request -> application -> server` scope and throws `ashid.NotWired` if none is set.

## API

| Method | Returns | Description |
|---|---|---|
| `generate([prefix])` | string | Time-sortable ID with optional prefix |
| `generate4([prefix])` | string | Two-random ID (no timestamp), 26-char base - UUID-v4 equivalent |
| `create(prefix, time, randomLong)` | string | Deterministic factory (testing, replication) |
| `create4(prefix, random1, random2)` | string | Deterministic ashid4 factory |
| `parse(id, [returnType])` | array or struct | `["user_", ts, rnd]` or `{prefix, timestamp, random}` |
| `prefix(id)` | string | Prefix incl. trailing `_` (empty for unprefixed IDs) |
| `timestamp(id)` | numeric | Recovered ms-since-epoch |
| `random(id)` | java.lang.Long | Random component (standard ID; signed 63-bit) |
| `randomULong(id)` | java.math.BigInteger | Random component preserving full 64-bit (for ashid4) |
| `isValid(id)` | boolean | Format check |
| `normalize(id)` | string | Canonical form via parse -> decode -> re-encode |

Top-level UDFs in `helpers.cfm`: `ashid([prefix])`, `ashid4([prefix])`, `parseAshid(id)`.

## ID format

**With prefix** (variable length): `<normalizedPrefix><optionalTimestamp><random>`

- Prefix is auto-stripped of non-alphanumeric chars, lowercased, with `_` auto-appended. So `ashid("user")`, `ashid("user_")`, `ashid("user-")`, `ashid("USER")`, and `ashid("u-s-e-r")` all produce the same `user_...` prefix.
- When `time == 0`, the timestamp portion is omitted entirely and the random is unpadded. Otherwise the timestamp is unpadded Crockford Base32 and the random is padded to 13 chars.

**Without prefix** (fixed 22 chars): `<9-char zero-padded timestamp><13-char zero-padded random>`

**ashid4 form** (fixed 26-char base, no timestamp): `<13-char random1><13-char random2>` - UUID-v4-equivalent. Use when unpredictability matters more than time-sortability.

**Alphabet:** `0123456789abcdefghjkmnpqrstvwxyz` (lowercase, 32 chars). Decode tolerates uppercase and Crockford lookalikes (`I`, `L -> 1`; `O -> 0`; `U -> V`).

## Known quirks

**Prefixes must be letters only at parse time.** The upstream `parse()` walker uses `isLetter()`, which rejects digits. So `ashid("u1")` will produce an ID, but the resulting string can't be parsed back (the walker bails on the digit). `isValid()` returns false. **Use letter-only prefixes** (`"user"`, `"event"`, `"token"`, etc.) - this matches upstream Kotlin behavior. We have not patched this in the CFML port to preserve byte-for-byte parity.

**`normalize()` works on ashid4 IDs in this port (upstream divergence).** Upstream's `normalize()` round-trips through `create()`, which validates the first encoded slot as a timestamp. For ashid4 form, that slot holds `random1`, and roughly half of all `random1` values exceed `Long.MAX_VALUE` once decoded - so upstream throws "Ashid timestamp must be non-negative" on those inputs. This CFML port detects ashid4 form (first encoded slot is exactly 13 chars) and routes to `create4()` instead, so `normalize()` works on every ID that `parse()` and `isValid()` accept. If you need exact upstream behavior here, catch `ashid.InvalidArgument` from `normalize()` yourself and treat ashid4 inputs as already-canonical.

## Engine support

| Engine | Status |
|---|---|
| Adobe ColdFusion 2016+ | Tested (2016 + 2025) - see [tests/specs/](tests/specs/) |
| Lucee 5+ | Tested |
| BoxLang 1+ | Tested |

The library uses only Java standard library classes (`java.security.SecureRandom`, `java.math.BigInteger`) - no third-party JARs required at runtime.

No third-party CFML test framework dependency - tests use a tiny in-tree runner at `tests/run.cfm`. No `box install` needed before running tests.

The library is thread-safe when used as a singleton (typically wired in `Application.cfc` `onApplicationStart`). The internal `java.security.SecureRandom` instance is documented thread-safe by the JVM, and the encoder holds no mutable state.

## Compatibility with upstream

IDs produced by this CFML port are byte-for-byte interchangeable with the upstream **v1.0.3** Kotlin and TypeScript implementations. Verified by `tests/specs/KnownVectorsTest.cfc` (13 frozen vectors, 5 hand-derived from the algorithm + 8 self-locked CFML output).

### Upstream version notes

- **Source of truth:** [github.com/wildeagency/ashid](https://github.com/wildeagency/ashid) `main` branch (v1.0.3 per the repo's CHANGELOG.md). The cached upstream source we ported from is at [`AshId.kt`](https://github.com/wildeagency/ashid/blob/main/kotlin/src/main/kotlin/agency/wilde/ashid/AshId.kt) and [`EncoderBase32Crockford.kt`](https://github.com/wildeagency/ashid/blob/main/kotlin/src/main/kotlin/agency/wilde/ashid/EncoderBase32Crockford.kt) on the upstream repo.
- **Maven Central** currently ships `agency.wilde:ashid:1.0.0` only. v1.0.0 predates the `ashid4` API and the auto-underscore prefix normalization. **Our CFML port and the published Maven JAR will NOT produce identical IDs for prefixed inputs**: the JAR's `create("user", ...)` produces `user...` (no underscore), while ours produces `user_...`. If you need identical-bytes parity with the published Maven JAR specifically, build a v1.0.3 JAR from upstream source yourself.
- The JAR in `lib/ashid-1.0.0.jar` is kept for benchmarking only, not as a runtime parity oracle.

## Performance

CFML vs. v1.0.0 JAR (`benchmark/run.cfm`, 50,000 iterations):

| Engine | Op | CFML ms | JAR ms | Ratio | CFML ops/sec |
|---|---|---|---|---|---|
| Lucee 5 | `generate("user")` | 4971 | 213 | 23.34x | ~10,058 |
| Lucee 5 | `generate()` | 4513 | 67 | 67.36x | ~11,079 |
| Lucee 5 | `parse(id)` | 275 | n/a | n/a | ~181,818 |
| Lucee 5 | `generate4("tok")` | 6504 | n/a | n/a | ~7,687 |
| ACF 2016 | `generate("user")` | 7546 | n/a* | n/a | ~6,626 |
| ACF 2016 | `generate()` | 7238 | n/a* | n/a | ~6,907 |
| ACF 2025 | `generate("user")` | 5000 | 173 | 28.90x | ~10,000 |
| ACF 2025 | `generate()` | 4413 | 65 | 67.89x | ~11,330 |
| ACF 2025 | `parse(id)` | 230 | n/a | n/a | ~217,391 |
| ACF 2025 | `generate4("tok")` | 5952 | n/a | n/a | ~8,400 |
| BoxLang 1 | `generate("user")` | 9669 | 327 | 29.57x | ~5,171 |
| BoxLang 1 | `generate()` | 8525 | 149 | 57.21x | ~5,865 |

\* ACF 2016 doesn't accept the 3-arg `createObject("java", class, [jars])` form so the JAR isn't loaded for those rows; CFML-only timing. ACF 2025 *does* accept that form, so JAR comparison is available there.

CFML is 23-67x slower than the Java JAR - expected for `BigInteger`-heavy code without HotSpot inlining of CFML-internal calls. The chained `BigInteger.add().multiply()` operations now go through `java.lang.reflect.Method.invoke` (BoxLang 1.x routes a bare `bigInteger.add(...)` through its Number BIF when the receiver is numerically zero, which fails with "Required argument number is missing for function add"), costing ~25-30% throughput vs. direct member calls but making the same code work on every target engine. At 5,000-11,000 ops/sec for prefixed generation, that's still plenty for any typical CFML workload (you'd be allocating IDs at three orders of magnitude slower than this in any realistic request).

Run your own benchmark:

```bash
box server start cfengine=lucee@5 --port=8123 --background
# Visit: http://127.0.0.1:8123/benchmark/run.cfm?n=100000
```

See [`benchmark/README.md`](benchmark/README.md) for methodology and caveats.

## Building from source

No third-party CFML dependencies are required - tests use a tiny in-tree runner (`tests/Assert.cfc` + `tests/run.cfm`).

```bash
git clone https://github.com/jamoCA/cf-ashid
cd cf-ashid
box server start cfengine=lucee@5 --port=8123 --background

# Run tests (HTML view):
open http://127.0.0.1:8123/tests/run.cfm

# Run tests (plain text, for CI):
curl "http://127.0.0.1:8123/tests/run.cfm?format=text"

# Run benchmark:
curl "http://127.0.0.1:8123/benchmark/run.cfm?n=100000"
```

## Articles

- [ashid for CFML: time-sortable, prefixed IDs without a JAR](https://www.mycfml.com/articles/ashid-for-cfml-time-sortable-prefixed-ids-without-a-jar/) - announcement post on myCFML covering the why, the BigInteger gotcha, and cross-engine performance.

## License

MIT, mirrored from upstream `agency.wilde:ashid`. See [LICENSE](LICENSE).

## Credits

- [Crockford Base32](https://www.crockford.com/base32.html) - Douglas Crockford's encoding spec (alphabet + lookalike-character mapping). Designed for human-readable identifiers.
- Original Kotlin/TypeScript implementation: [Wilde Agency](https://github.com/wildeagency/ashid).
- CFML port: James Moberg.
