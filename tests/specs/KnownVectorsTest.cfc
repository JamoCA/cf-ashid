component {
	public array function run() {
		var t = new tests.Assert();
		var ashid = new ashid.Ashid();
		var BigInt = createObject("java", "java.math.BigInteger");
		var raw = fileRead(expandPath("/ashid/tests/resources/known-vectors.json"));
		var vectors = deserializeJSON(raw);

		// Known vectors (locked at v1.0.3 spec)
		t.it("known vectors: CFML reproduces every captured standard ID byte-for-byte", function() {
			for (var v in vectors) {
				if (v.form != "standard") continue;
				var rnd = BigInt.init(v.random);
				var produced = ashid.create(v.prefix, javaCast("long", v.time), rnd);
				// assertEquals uses compare() internally for case-sensitive equality - Crockford
				// output is lowercase-only, and any uppercase regression must fail the test loudly.
				t.assertEquals(v.id, produced, "Mismatch: prefix='" & v.prefix & "' time=" & v.time & " random=" & v.random);
			}
		});
		t.it("known vectors: CFML reproduces every captured ashid4 ID byte-for-byte", function() {
			for (var v in vectors) {
				if (v.form != "ashid4") continue;
				var produced = ashid.create4(v.prefix, BigInt.init(v.r1), BigInt.init(v.r2));
				t.assertEquals(v.id, produced, "Mismatch: prefix='" & v.prefix & "' r1=" & v.r1 & " r2=" & v.r2);
			}
		});
		t.it("known vectors: loaded the expected vector counts from the JSON", function() {
			var stdCount = 0;
			var a4Count = 0;
			for (var v in vectors) {
				if (v.form eq "standard") stdCount++;
				if (v.form eq "ashid4") a4Count++;
			}
			t.assertEquals(9, stdCount);  // 3 hand-derived + 6 self-derived
			t.assertEquals(4, a4Count);   // 2 hand-derived + 2 self-derived
		});

		return t.getResults();
	}
}
