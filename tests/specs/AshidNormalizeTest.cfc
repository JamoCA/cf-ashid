component {
	public array function run() {
		var t = new tests.Assert();
		var ashid = new ashid.Ashid();
		var BigInt = createObject("java", "java.math.BigInteger");

		// Ashid.normalize
		t.it("normalize: returns identical output for already-canonical input", function() {
			var id = ashid.create("user", 1778025600000, BigInt.valueOf(javaCast("long", 42)));
			t.assertEquals(id, ashid.normalize(id));
		});
		t.it("normalize: lowercases mixed-case prefix", function() {
			// Hand-craft a mangled ID by uppercasing the prefix portion of a canonical ID.
			var canonical = ashid.create("user", 1778025600000, BigInt.valueOf(javaCast("long", 42)));
			// canonical = "user_<ts><13-rand>"
			var prefix_part = mid(canonical, 1, 5);  // "user_"
			var body = mid(canonical, 6, len(canonical) - 5);
			var mangled = ucase(prefix_part) & body;  // "USER_<ts><13-rand>"
			t.assertEquals(canonical, ashid.normalize(mangled));
		});
		t.it("normalize: maps lookalike chars in body via re-encode", function() {
			var canonical = ashid.create("user", 1, BigInt.valueOf(javaCast("long", 1)));
			// canonical = "user_10000000000001"
			// mangle: replace the timestamp '1' with 'L' (which decodes to 1)
			var mangled = "user_L0000000000001";
			t.assertEquals(canonical, ashid.normalize(mangled));
		});

		t.it("normalizes ashid4 form (no prefix) with low-bit randoms", function() {
			// Both randoms < Long.MAX_VALUE - would have worked under the old logic too.
			var canonical = ashid.create4("", BigInt.valueOf(javaCast("long", 1)), BigInt.valueOf(javaCast("long", 2)));
			t.assertEquals(canonical, ashid.normalize(canonical));
		});

		t.it("normalizes ashid4 form with high-bit random1 (>Long.MAX_VALUE) - the upstream bug we fixed", function() {
			// 2^64 - 2 has the top bit set; old normalize would throw "timestamp must be non-negative"
			// because Long.parseLong of that value is negative.
			var hugeRandom = BigInt.init("18446744073709551614");
			var canonical = ashid.create4("token", hugeRandom, BigInt.valueOf(javaCast("long", 7)));
			t.assertEquals(canonical, ashid.normalize(canonical));
		});

		t.it("normalizes ashid4 form with high-bit random2", function() {
			var hugeRandom = BigInt.init("18446744073709551614");
			var canonical = ashid.create4("evt", BigInt.valueOf(javaCast("long", 7)), hugeRandom);
			t.assertEquals(canonical, ashid.normalize(canonical));
		});

		return t.getResults();
	}
}
