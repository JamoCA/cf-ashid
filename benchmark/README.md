# ashid benchmarks

Compares the pure-CFML implementation against the upstream Kotlin JAR (`lib/ashid-1.0.0.jar`).

## Caveat: JAR version

The shipped JAR is `agency.wilde:ashid:1.0.0` (the only version on Maven Central). The CFML port targets v1.0.3 of the upstream Kotlin source (HEAD on the GitHub `main` branch). The two implementations produce **different output formats** for prefixed IDs:

- **JAR v1.0.0** `create("user", ...)` -> `user<...>` (no underscore)
- **CFML v1.0.3** `create("user", ...)` -> `user_<...>` (with underscore)

For benchmark purposes the timing comparison is still meaningful -- both implementations run the same primitive operations (CSPRNG draw + Crockford Base32 encode + string concatenation). The difference in output format does not affect timing.

The JAR also depends on `kotlin-stdlib` at runtime (its prefix-normalization regex and `parse()`'s `Triple` are kotlin-stdlib types). The benchmark loads `lib/kotlin-stdlib-2.0.0.jar` alongside `ashid-1.0.0.jar` via `createObject("java", ..., [jar1, jar2])`. If the kotlin-stdlib jar is missing the benchmark falls back to CFML-only timings.

`parse()` and `ashid4` operations cannot be cross-compared:

- The JAR's `parse()` returns `kotlin.Triple`. Iterating the result through CFML for a fair comparison would skew toward the CFML overhead of unwrapping the Triple. Excluded for simplicity -- CFML-only timing reported.
- The JAR has no `ashid4`/`create4Long`. v1.0.3 introduced this -- pure-CFML only.

## Run

1. Ensure `lib/ashid-1.0.0.jar` and `lib/kotlin-stdlib-2.0.0.jar` are present (kotlin-stdlib is downloaded from Maven Central; `curl -L -o lib/kotlin-stdlib-2.0.0.jar https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/2.0.0/kotlin-stdlib-2.0.0.jar`).
2. Start a server: `box server start cfengine=lucee@5 --port=8123 --background`
3. Visit `http://127.0.0.1:8123/benchmark/run.cfm`
4. Override iteration count via `?n=500000`

## Methodology

- 1,000-iteration warmup per implementation before timing.
- `getTickCount()` deltas in ms.
- Same `for` harness for both implementations.
- Single-threaded; no concurrent load.
- Not a JMH-style micro-benchmark -- gives a rough ratio, not a research-grade number.

## Results

50,000 iterations on a Windows 11 dev box (Java 11/AdoptOpenJDK for Lucee 5 & ACF 2016, Java 21/AdoptOpenJDK for BoxLang & ACF 2025). Numbers vary by ~10-30% run-to-run from JIT/GC noise; treat as order-of-magnitude. The CFML port uses reflective Method.invoke for `BigInteger.add`/`.multiply` calls (BoxLang 1.x routes the bare member calls through its CFML Number BIF when the receiver is `BigInteger.ZERO`), which costs ~25-30% throughput vs. the original direct calls but is portable across all four engines.

| Engine | Op | CFML ms | JAR ms | Ratio |
|---|---|---|---|---|
| Lucee 5 | generate("user") | 4971 | 213 | 23.34x |
| Lucee 5 | generate() | 4513 | 67 | 67.36x |
| Lucee 5 | parse(id) | 275 | n/a | n/a |
| Lucee 5 | generate4("tok") | 6504 | n/a | n/a |
| ACF 2016 | generate("user") | 7546 | n/a* | n/a |
| ACF 2016 | generate() | 7238 | n/a* | n/a |
| ACF 2016 | parse(id) | 383 | n/a | n/a |
| ACF 2016 | generate4("tok") | 10781 | n/a | n/a |
| ACF 2025 | generate("user") | 5000 | 173 | 28.90x |
| ACF 2025 | generate() | 4413 | 65 | 67.89x |
| ACF 2025 | parse(id) | 230 | n/a | n/a |
| ACF 2025 | generate4("tok") | 5952 | n/a | n/a |
| BoxLang 1 | generate("user") | 9669 | 327 | 29.57x |
| BoxLang 1 | generate() | 8525 | 149 | 57.21x |
| BoxLang 1 | parse(id) | 1648 | n/a | n/a |
| BoxLang 1 | generate4("tok") | 13389 | n/a | n/a |

\* ACF 2016's `createObject("java", classname, [jarPaths])` syntax is a Lucee/BoxLang extension; ACF 2016 rejects the third positional argument, so the JAR isn't loaded for those comparison rows. ACF 2025 *does* accept that form, so the JAR comparison is available there.

ops/sec by engine (50k iters):

| Engine | Op | CFML ops/sec | JAR ops/sec |
|---|---|---|---|
| Lucee 5 | generate("user") | 10,058 | 234,741 |
| Lucee 5 | generate() | 11,079 | 746,268 |
| Lucee 5 | parse(id) | 181,818 | n/a |
| Lucee 5 | generate4("tok") | 7,687 | n/a |
| ACF 2016 | generate("user") | 6,626 | n/a |
| ACF 2016 | generate() | 6,907 | n/a |
| ACF 2016 | parse(id) | 130,548 | n/a |
| ACF 2016 | generate4("tok") | 4,637 | n/a |
| ACF 2025 | generate("user") | 10,000 | 289,017 |
| ACF 2025 | generate() | 11,330 | 769,230 |
| ACF 2025 | parse(id) | 217,391 | n/a |
| ACF 2025 | generate4("tok") | 8,400 | n/a |
| BoxLang 1 | generate("user") | 5,171 | 152,905 |
| BoxLang 1 | generate() | 5,865 | 335,570 |
| BoxLang 1 | parse(id) | 30,339 | n/a |
| BoxLang 1 | generate4("tok") | 3,734 | n/a |

The JAR is 23-67x faster than the CFML port -- expected, since CFML allocates per-call `BigInteger` objects, pays string-concat overhead on every iteration, and (now) goes through Java reflection for the chained add/multiply ops. Lucee 5 and ACF 2025 are the fastest engines for the CFML port (both clearing ~10,000 prefixed-id ops/sec); ACF 2016 sits in the middle; BoxLang is slowest, but still clears 5,000 prefixed-id ops/sec which is plenty for any typical id-generation workload.
