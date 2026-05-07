<cfsetting requestTimeout="60" showDebugOutput="false">
<cfscript>
ashid = new ashid.Ashid();
BigInt = createObject("java", "java.math.BigInteger");

// Hand-derived "ground truth" vectors. Each was computed by walking the upstream
// v1.0.3 algorithm in `docs/superpowers/specs/upstream-reference/AshId.kt` by hand.
// If any of these don't match the CFML output, the implementation diverges from spec
// and the test should fail loudly.
hardCoded = [
	{ "form": "standard", "prefix": "", "time": 0, "random": "0",
	"id": "0000000000000000000000",                               // 22 zeros
	"note": "no-prefix, time=0, random=0 -> 9 ts zeros + 13 random zeros" },
	{ "form": "standard", "prefix": "user", "time": 0, "random": "1",
	"id": "user_1",
	"note": "prefix + time=0 -> no ts portion, random=1 unpadded" },
	{ "form": "standard", "prefix": "user", "time": 1, "random": "1",
	"id": "user_10000000000001",
	"note": "prefix + time=1 -> unpadded ts '1' + 13-char padded random" }
];

vectors = [];
for (h in hardCoded) {
	rndBig = BigInt.init(h.random);
	produced = ashid.create(h.prefix, h.time, rndBig);
	if (produced != h.id) {
		throw(type="ashid.GeneratorMismatch",
			message="Hand-derived vector mismatch: input prefix='#h.prefix#' time=#h.time# random=#h.random# -> expected '#h.id#' got '#produced#'");
	}
	arrayAppend(vectors, h);
}

// CFML-self-generated vectors. We capture the actual CFML output for additional
// inputs and freeze them. These don't validate against external truth, but they
// catch any future regression in our own encoder/Ashid logic. The combination of
// hand-derived + frozen-CFML provides both external and internal regression coverage.
selfInputs = [
	[ "prefix": "",     "time": 1,             "random": "1" ],
	[ "prefix": "",     "time": 1778025600000, "random": "12345" ],
	[ "prefix": "user", "time": 1778025600000, "random": "9223372036854775807" ],  // Long.MAX_VALUE
	[ "prefix": "evt",  "time": 35184372088831,"random": "12345678901234567" ],     // MAX_TIMESTAMP
	[ "prefix": "USER-","time": 1,             "random": "1" ],                     // tests prefix normalization
	[ "prefix": "u-s-e-r","time": 1,           "random": "1" ]
];
for (input in selfInputs) {
	rndBig = BigInt.init(input.random);
	id = ashid.create(input.prefix, input.time, rndBig);
	arrayAppend(vectors, [
		"form": "standard",
		"prefix": input.prefix,
		"time":   input.time,
		"random": input.random,
		"id":     id
	]);
}

// ashid4 vectors. Hand-verifiable for trivial inputs.
hardCoded4 = [
	[ "form": "ashid4", "prefix": "", "r1": "0", "r2": "0",
	"id": "00000000000000000000000000",                            // 26 zeros
	"note": "no-prefix ashid4, both randoms 0 -> 13+13 zeros" ],
	[ "form": "ashid4", "prefix": "", "r1": "1", "r2": "2",
	"id": "00000000000010000000000002",
	"note": "no-prefix ashid4, r1=1 r2=2 -> 13-char padded each" ]
];
for (h in hardCoded4) {
	r1Big = BigInt.init(h.r1);
	r2Big = BigInt.init(h.r2);
	produced = ashid.create4(h.prefix, r1Big, r2Big);
	if (produced neq h.id) {
		throw(type="ashid.GeneratorMismatch", message="Hand-derived ashid4 vector mismatch: input prefix='#h.prefix#' r1=#h.r1# r2=#h.r2# -> expected '#h.id#' got '#produced#'");
	}
	arrayAppend(vectors, h);
}

// CFML-self-generated ashid4 vectors.
self4Inputs = [
	[ "prefix": "tok", "r1": "9223372036854775807", "r2": "1" ],
	[ "prefix": "tok", "r1": "1",                    "r2": "9223372036854775807" ]
];
for (input in self4Inputs) {
	r1Big = BigInt.init(input.r1);
	r2Big = BigInt.init(input.r2);
	id = ashid.create4(input.prefix, r1Big, r2Big);
	arrayAppend(vectors, [
		"form":   "ashid4",
		"prefix": input.prefix,
		"r1":     input.r1,
		"r2":     input.r2,
		"id":     id
	]);
}

fileWrite(expandPath("./known-vectors.json"), serializeJSON(vectors, true));
writeOutput("Wrote " & arrayLen(vectors) & " vectors. (3 hand-derived standard + 6 self-derived standard + 2 hand-derived ashid4 + 2 self-derived ashid4 = 13 total)<br><pre>" & encodeForHtml(serializeJSON(vectors, true)) & "</pre>");
</cfscript>
