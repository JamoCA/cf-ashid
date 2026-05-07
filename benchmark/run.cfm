<cfsetting requestTimeout="900" showDebugOutput="false">
<cfscript>
param name="url.n" default="100000";
n = val(url.n);

jarPath       = expandPath("/ashid/lib/ashid-1.0.0.jar");
kotlinJarPath = expandPath("/ashid/lib/kotlin-stdlib-2.0.0.jar");
jarPresent    = fileExists(jarPath) && fileExists(kotlinJarPath);
jarLoadError  = "";
if (jarPresent) {
	// kotlin-stdlib is required for the JAR's prefix-normalization Regex (and parse()'s Triple).
	// The 3-arg createObject(type, class, [paths]) form is Lucee/BoxLang -- ACF rejects it.
	// We try it and fall back to CFML-only timings if the engine doesn't support it.
	try {
		JarAshidKt = createObject("java", "agency.wilde.ashid.AshIdKt", [jarPath, kotlinJarPath]);
	} catch (any e) {
		jarPresent  = false;
		jarLoadError = e.message;
	}
}
cfml = new ashid.Ashid();

function timeBlock(callback, iters) {
	for (var i = 1; i lte 1000; i++) callback();
	var s = getTickCount();
	for (var j = 1; j lte iters; j++) callback();
	return getTickCount() - s;
}

results = [];

// generate("user") -- note: JAR v1.0.0 produces "user<...>" while CFML v1.0.3 produces "user_<...>"
// Output format differs but the operation timed is the same.
arrayAppend(results, [
	op: 'generate("user")',
	cfml: timeBlock(function(){ cfml.generate("user"); }, n),
	jar:  jarPresent ? timeBlock(function(){ JarAshidKt.ashid("user"); }, n) : -1,
	note: jarPresent ? "JAR v1.0.0: no underscore in output; CFML v1.0.3: with underscore" : ""
]);

// generate() unprefixed -- both v1.0.0 and v1.0.3 produce 22-char output, formats agree
arrayAppend(results, [
	op: 'generate()',
	cfml: timeBlock(function(){ cfml.generate(); }, n),
	jar:  jarPresent ? timeBlock(function(){ JarAshidKt.ashid(""); }, n) : -1,
	note: jarPresent ? "Both produce 22-char no-prefix output" : ""
]);

// parse -- CFML only (JAR's parse() returns kotlin.Triple; unwrapping it from CFML would
// skew the timing toward CFML overhead rather than the Kotlin parse path itself).
sample = cfml.generate("user");
arrayAppend(results, [
	op: 'parse(id)',
	cfml: timeBlock(function(){ cfml.parse(sample); }, n),
	jar:  -1,
	note: "JAR not benchmarked: parse() returns kotlin.Triple; CFML-side unwrap skews timing"
]);

// generate4 -- CFML only (JAR v1.0.0 has no ashid4)
arrayAppend(results, [
	op: 'generate4("tok")',
	cfml: timeBlock(function(){ cfml.generate4("tok"); }, n),
	jar:  -1,
	note: "JAR v1.0.0 has no ashid4 API; comparison unavailable"
]);
</cfscript>

<cfoutput>
<h2>ashid benchmark</h2>
<p><strong>Engine:</strong> #server.coldfusion.productname# #server.coldfusion.productversion#<br>
<strong>JAR:</strong> #(jarPresent ? "agency.wilde:ashid:1.0.0 (v1.0.0)" : "not loaded#(len(jarLoadError) ? ' (' & htmlEditFormat(jarLoadError) & ')' : '')#")#<br>
<strong>CFML port:</strong> v1.0.3-equivalent<br>
<strong>Iterations:</strong> #numberFormat(n)# (plus 1,000 warmup per implementation)</p>

<table border="1" cellpadding="6" cellspacing="0">
	<thead>
		<tr><th>Op</th><th>CFML ms</th><th>JAR ms</th><th>Ratio (CFML/JAR)</th><th>ops/sec CFML</th><th>ops/sec JAR</th><th>Notes</th></tr>
	</thead>
	<tbody>
		<cfloop array="#results#" index="r">
			<tr>
				<td>#r.op#</td>
				<td>#r.cfml#</td>
				<td>#(r.jar gte 0 ? r.jar : "n/a")#</td>
				<td>#(r.jar gte 0 ? numberFormat(r.cfml / max(r.jar, 1), "0.00") & "x" : "n/a")#</td>
				<td>#numberFormat(int(n / max(r.cfml, 1) * 1000))#</td>
				<td>#(r.jar gte 0 ? numberFormat(int(n / max(r.jar, 1) * 1000)) : "n/a")#</td>
				<td>#r.note#</td>
			</tr>
		</cfloop>
	</tbody>
</table>

<p><em>Note: JAR is v1.0.0 (currently the only version on Maven Central). CFML port targets v1.0.3 source. Output formats differ for prefixed IDs but the timed operations are equivalent.</em></p>
</cfoutput>
