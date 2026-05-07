<cfsetting requestTimeout="120" showDebugOutput="false">
<cfscript>
ashid = new ashid.Ashid();

// Form defaults
param name="form.action"   default="";
param name="form.prefix"   default="";
param name="form.count"    default="10";
param name="form.parse_id" default="";

count = max(1, min(1000, val(form.count)));   // clamp 1..1000

// Run on submit
generated = [];
ashid4Generated = [];
parsed = "";
parseError = "";

if (form.action eq "generate") {
	for (i = 1; i lte count; i++) {
		id = ashid.generate(form.prefix);
		ts = ashid.timestamp(id);
		rnd = ashid.random(id);
		arrayAppend(generated, [
			"id": id,
			"length": len(id),
			"prefix": ashid.prefix(id),
			"timestamp_ms": ts,
			"timestamp_iso": dateTimeFormat(dateAdd("s", int(ts/1000), "1970-01-01"), "yyyy-mm-dd HH:nn:ss") & "Z",
			"random_long": rnd.toString(),
			"isValid": ashid.isValid(id),
			"normalized": ashid.normalize(id)
		]);
	}
}

if (form.action eq "generate4") {
	for (i = 1; i lte count; i++) {
		id = ashid.generate4(form.prefix);
		arrayAppend(ashid4Generated, [
			"id": id,
			"length": len(id),
			"prefix": ashid.prefix(id),
			"isValid": ashid.isValid(id)
		]);
	}
}

if (form.action eq "parse" && len(form.parse_id) gt 0) {
	try {
		s = ashid.parse(form.parse_id, "struct");

		// Detect form by inspecting the parsed slots.
		// - ashid4 form: both encoded slots are exactly 13 chars (two 13-char random components).
		// - standard form: ts slot is 1-9 chars (45-bit max ms timestamp encodes to <= 9 chars).
		isAshid4 = (len(s.timestamp) eq 13);

		parsed = [
			"input": form.parse_id,
			"form": (isAshid4 ? "ashid4 (two random components, no timestamp)" : "standard (timestamp + random)"),
			"isValid": ashid.isValid(form.parse_id),
			"prefix": s.prefix,
			"normalized": ashid.normalize(form.parse_id),
			"isAshid4": isAshid4
		];

		if (isAshid4) {
			// Both slots are randoms.
			parsed["random1_encoded"] = s.timestamp;
			parsed["random2_encoded"] = s.random;
			// Decode each as a BigInteger to preserve full 64-bit ULong values.
			parsed["random1_value"] = ashid.encoderRef().decode(s.timestamp).toString();
			parsed["random2_value"] = ashid.encoderRef().decode(s.random).toString();
		} else {
			// Standard form.
			parsed["timestamp_encoded"] = s.timestamp;
			parsed["random_encoded"] = s.random;
			try {
				parsed["timestamp_ms"] = ashid.timestamp(form.parse_id);
				parsed["timestamp_iso"] = dateTimeFormat(dateAdd("s", int(parsed.timestamp_ms/1000), "1970-01-01"), "iso");
				parsed["random_long"] = ashid.random(form.parse_id).toString();
			} catch (any e) {
				parsed["timestamp_decode_error"] = e.message;
			}
		}
	} catch (any e) {
		parseError = e.message;
	}
}
</cfscript>
<!doctype html>
<html><head><meta charset="utf-8"><title>ashid demo</title>
<style>
* { box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 1100px; margin: 2em auto; padding: 0 1em; color: #222; line-height: 1.5; }
h1 { font-size: 1.5em; margin-bottom: .2em; }
.sub { color: #666; margin-bottom: 2em; }
.engine { color: #888; font-size: .85em; }
.panel { background: #f7f7f8; padding: 1em 1.5em; border-radius: 6px; margin-bottom: 1.5em; }
.panel h2 { margin-top: 0; font-size: 1.05em; color: #333; }
form { margin: 0; }
.row { display: flex; gap: 1em; align-items: flex-end; flex-wrap: wrap; margin-bottom: .5em; }
.row label { display: block; font-size: .85em; color: #555; margin-bottom: .25em; }
.row input[type=text], .row input[type=search], .row input[type=number] { padding: .4em .6em; border: 1px solid #ccc; border-radius: 3px; font-size: 1em; }
.row button { padding: .5em 1em; background: #2a6df4; color: white; border: 0; border-radius: 3px; font-size: .95em; cursor: pointer; }
.row button:hover { background: #1d54c4; }
.row button.alt { background: #555; }
.row button.alt:hover { background: #333; }
table { border-collapse: collapse; width: 100%; font-size: .85em; }
th, td { padding: .35em .6em; border-bottom: 1px solid #e2e2e2; text-align: left; vertical-align: top; }
th { background: #efefef; font-weight: 600; }
td.id { font-family: SFMono-Regular, Consolas, monospace; }
.note { color: #888; font-size: .85em; margin-top: .5em; }
.error { color: #c0392b; padding: .5em 1em; background: #fde8e8; border-radius: 3px; }
.invalid { color: #c0392b; }
.valid { color: #2a8a2a; }
</style>
</head><body>

<cfoutput>
<h1>ashid demo</h1>
<p class="sub">Verify the library works on this engine. Generate IDs, parse them, watch every API method round-trip.<br>
<span class="engine">Running on #server.coldfusion.productname# #server.coldfusion.productversion#</span></p>

<!-- Generate panel -->
<div class="panel">
<h2>Generate standard IDs</h2>
<form method="post">
	<input type="hidden" name="action" value="generate">
	<div class="row">
		<div>
			<label>Prefix (letters only - see README quirks)</label>
			<input type="search" name="prefix" value="#encodeForHtmlAttribute(form.prefix)#" placeholder="e.g. user, evt, order" maxlength="20">
		</div>
		<div>
			<label>Count (1-1000)</label>
			<input type="number" name="count" value="#encodeForHtmlAttribute(form.count)#" min="1" max="1000">
		</div>
		<div>
			<button type="submit">Generate</button>
		</div>
	</div>
</form>

<cfif arrayLen(generated)>
	<p class="note">Showing #arrayLen(generated)# IDs. Each row exercises <code>generate</code>, <code>prefix</code>, <code>timestamp</code>, <code>random</code>, <code>isValid</code>, <code>normalize</code>.</p>
	<table>
		<thead>
			<tr>
				<th>##</th>
				<th>ID</th>
				<th>len</th>
				<th>prefix()</th>
				<th>timestamp()</th>
				<th>ISO</th>
				<th>random()</th>
				<th>isValid()</th>
				<th>normalize() == ID</th>
			</tr>
		</thead>
		<tbody>
			<cfloop from="1" to="#arrayLen(generated)#" index="i">
				<cfset g = generated[i]>
				<tr>
					<td>#i#</td>
					<td class="id">#encodeForHtml(g.id)#</td>
					<td>#g.length#</td>
					<td><code>#encodeForHtml(g.prefix)#</code></td>
					<td>#g.timestamp_ms#</td>
					<td>#g.timestamp_iso#</td>
					<td>#g.random_long#</td>
					<td class="#(g.isValid ? 'valid' : 'invalid')#">#g.isValid#</td>
					<td class="#(compare(g.normalized, g.id) eq 0 ? 'valid' : 'invalid')#">#(compare(g.normalized, g.id) eq 0)#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>
</div>

<!-- ashid4 panel -->
<div class="panel">
<h2>Generate ashid4 IDs (UUID-v4 equivalent)</h2>
<form method="post">
	<input type="hidden" name="action" value="generate4">
	<input type="hidden" name="count" value="#encodeForHtmlAttribute(form.count)#">
	<div class="row">
		<div>
			<label>Prefix</label>
			<input type="search" name="prefix" value="#encodeForHtmlAttribute(form.prefix)#" placeholder="e.g. token, key" maxlength="20">
		</div>
		<div>
			<button type="submit" class="alt">Generate ashid4</button>
		</div>
	</div>
</form>

<cfif arrayLen(ashid4Generated)>
	<p class="note">26-char base, two random components, no timestamp.</p>
	<table>
		<thead>
			<tr><th>##</th><th>ID</th><th>len</th><th>prefix()</th><th>isValid()</th></tr>
		</thead>
		<tbody>
			<cfloop from="1" to="#arrayLen(ashid4Generated)#" index="i">
				<cfset g = ashid4Generated[i]>
				<tr>
					<td>#i#</td>
					<td class="id">#encodeForHtml(g.id)#</td>
					<td>#g.length#</td>
					<td><code>#encodeForHtml(g.prefix)#</code></td>
					<td class="#(g.isValid ? 'valid' : 'invalid')#">#g.isValid#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfif>
</div>

<!-- Parse panel -->
<div class="panel">
<h2>Parse / inspect an ID</h2>
<form method="post">
	<input type="hidden" name="action" value="parse">
	<div class="row">
		<div style="flex:1">
			<label>Paste an ashid here (try mixing case or substituting I/L/O/U to test normalization)</label>
			<input type="search" name="parse_id" value="#encodeForHtmlAttribute(form.parse_id)#" style="width:100%" placeholder="user_1kbg1jmtt4v3x8k9p2m1np0">
		</div>
	<div>
		<button type="submit">Parse</button>
	</div>
	</div>
</form>

<cfif len(parseError)>
	<div class="error">parse() threw: #encodeForHtml(parseError)#</div>
</cfif>

<cfif isStruct(parsed)>
	<table>
		<tbody>
			<tr><th>method</th><th>result</th></tr>
			<tr><td><code>input</code></td><td class="id">#encodeForHtml(parsed.input)#</td></tr>
			<tr><td>form</td><td>#encodeForHtml(parsed.form)#</td></tr>
			<tr><td><code>isValid()</code></td><td class="#(parsed.isValid ? 'valid' : 'invalid')#">#parsed.isValid#</td></tr>
			<tr><td><code>parse(id, "struct").prefix</code></td><td><code>#encodeForHtml(parsed.prefix)#</code></td></tr>
			<cfif parsed.isAshid4>
				<tr><td><code>parse(id, "struct").timestamp</code> <em>(slot holds random1 in ashid4 form)</em></td><td class="id">#encodeForHtml(parsed.random1_encoded)#</td></tr>
				<tr><td><code>parse(id, "struct").random</code> <em>(slot holds random2 in ashid4 form)</em></td><td class="id">#encodeForHtml(parsed.random2_encoded)#</td></tr>
				<tr><td>random1 decoded (BigInteger)</td><td>#parsed.random1_value#</td></tr>
				<tr><td>random2 decoded (BigInteger)</td><td>#parsed.random2_value#</td></tr>
				<tr><td colspan="2" style="color:##888;font-size:.85em;font-style:italic;">timestamp() and random() are nonsensical for ashid4 form (no timestamp; two independent randoms). Use parse() and decode the slots directly, or use randomULong() to get either as a BigInteger.</td></tr>
			<cfelse>
				<tr><td><code>parse(id, "struct").timestamp</code> (encoded)</td><td class="id">#encodeForHtml(parsed.timestamp_encoded)#</td></tr>
				<tr><td><code>parse(id, "struct").random</code> (encoded)</td><td class="id">#encodeForHtml(parsed.random_encoded)#</td></tr>
				<cfif structKeyExists(parsed, "timestamp_ms")>
				<tr><td><code>timestamp(id)</code> (ms)</td><td>#parsed.timestamp_ms#</td></tr>
				<tr><td>timestamp ISO</td><td>#parsed.timestamp_iso#</td></tr>
				<tr><td><code>random(id).toString()</code></td><td>#parsed.random_long#</td></tr>
				<cfelseif structKeyExists(parsed, "timestamp_decode_error")>
				<tr><td colspan="2" class="error">timestamp/random decode failed: #encodeForHtml(parsed.timestamp_decode_error)#</td></tr>
				</cfif>
			</cfif>
			<tr><td><code>normalize(id)</code></td><td class="id">#encodeForHtml(parsed.normalized)#</td></tr>
			<tr><td>normalize == input?</td><td class="#(compare(parsed.normalized, parsed.input) eq 0 ? 'valid' : 'invalid')#">#compare(parsed.normalized, parsed.input) eq 0#</td></tr>
		</tbody>
	</table>
</cfif>
</div>

<p class="note">
Library home: <a href="https://github.com/jamoCA/cf-ashid">github.com/jamoCA/cf-ashid</a> &middot;
Upstream: <a href="https://github.com/wildeagency/ashid">wildeagency/ashid</a> &middot;
Run the test suite: <a href="tests/run.cfm">tests/run.cfm</a>
</p>

</cfoutput>
</body></html>
