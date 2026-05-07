component {
	public array function run() {
		var t = new tests.Assert();
		var ashid = new ashid.Ashid();
		var BigInt = createObject("java", "java.math.BigInteger");

		// Ashid prefix normalization
		t.it("prefix normalize: strips non-alphanumeric and adds underscore", function() {
			var id = ashid.create("user", 0, BigInt.valueOf(javaCast("long", 0)));
			t.assertEquals("user_", left(id, 5));
		});
		t.it("prefix normalize: strips trailing underscore from input (auto-re-added)", function() {
			var id = ashid.create("user_", 0, BigInt.valueOf(javaCast("long", 0)));
			t.assertEquals("user_", left(id, 5));
		});
		t.it("prefix normalize: strips trailing dash from input (auto-replaced with underscore)", function() {
			var id = ashid.create("user-", 0, BigInt.valueOf(javaCast("long", 0)));
			t.assertEquals("user_", left(id, 5));
		});
		t.it("prefix normalize: lowercases mixed-case input", function() {
			var id = ashid.create("UseR", 0, BigInt.valueOf(javaCast("long", 0)));
			t.assertEquals("user_", left(id, 5));
		});
		t.it("prefix normalize: strips embedded non-alphanumeric chars", function() {
			var id = ashid.create("u-s-e-r", 0, BigInt.valueOf(javaCast("long", 0)));
			t.assertEquals("user_", left(id, 5));
		});
		t.it("prefix normalize: treats prefix that becomes empty after cleaning as no-prefix", function() {
			var id = ashid.create("___", 0, BigInt.valueOf(javaCast("long", 0)));
			t.assertEquals(22, len(id));
			t.assertGT(reFind("^[0-9a-hjkmnp-tv-z]{22}$", id), 0);
		});

		// Ashid.create validation
		t.it("create validation: throws on negative time", function() {
			t.assertThrows(function() {
				ashid.create("user", -1, BigInt.ZERO);
			}, "ashid.InvalidArgument");
		});
		t.it("create validation: throws on time > MAX_TIMESTAMP (35184372088831)", function() {
			t.assertThrows(function() {
				ashid.create("user", 35184372088832, BigInt.ZERO);
			}, "ashid.InvalidArgument");
		});
		t.it("create validation: throws on negative randomLong", function() {
			t.assertThrows(function() {
				ashid.create("user", 0, BigInt.valueOf(javaCast("long", -1)));
			}, "ashid.InvalidArgument");
		});

		// Ashid.create form selection
		t.it("create form: no prefix produces fixed 22-char base", function() {
			var id = ashid.create("", 1778025600000, BigInt.valueOf(javaCast("long", 1)));
			t.assertEquals(22, len(id));
		});
		t.it("create form: prefix with time=0 omits timestamp and unpads random", function() {
			var id = ashid.create("user", 0, BigInt.valueOf(javaCast("long", 1)));
			t.assertEquals("user_1", id);
		});
		t.it("create form: prefix with time>0 uses unpadded timestamp + padded 13-char random", function() {
			var id = ashid.create("user", 1, BigInt.valueOf(javaCast("long", 1)));
			// time=1 encodes to "1" (unpadded), random=1 padded to 13 chars: "0000000000001"
			t.assertEquals("user_10000000000001", id);
		});
		t.it("create form: no-prefix at time=1, random=1 zero-pads both: 9 + 13", function() {
			var id = ashid.create("", 1, BigInt.valueOf(javaCast("long", 1)));
			t.assertEquals("000000001" & "0000000000001", id);
		});

		// Ashid.generate
		t.it("generate: returns 22 chars when no prefix", function() {
			t.assertEquals(22, len(ashid.generate()));
		});
		t.it("generate: returns prefix_<variable>_<13 random> for prefixed call", function() {
			var id = ashid.generate("user");
			t.assertEquals("user_", left(id, 5));
			t.assertGTE(len(id), 19);  // 5 (prefix) + 1 (ts at min) + 13 (random)
		});
		t.it("generate: uses lowercase canonical alphabet only", function() {
			var id = ashid.generate("u");
			t.assertGT(reFind("^[a-z]+_[0-9a-hjkmnp-tv-z]+$", id), 0);
		});
		t.it("generate: two consecutive calls produce different IDs", function() {
			t.assertNotEquals(ashid.generate("u"), ashid.generate("u"));
		});

		// Ashid.parse - variable form (with prefix)
		t.it("parse variable: returns [prefix_, ts, random] with random padded to 13 when time>0", function() {
			var id = ashid.create("user", 1, BigInt.valueOf(javaCast("long", 1)));
			var parts = ashid.parse(id);
			t.assertTrue(isArray(parts));
			t.assertEquals(3, arrayLen(parts));
			t.assertEquals("user_", parts[1]);
			t.assertEquals("1", parts[2]);
			t.assertEquals("0000000000001", parts[3]);
		});
		t.it("parse variable: returns [prefix_, '0', random] when prefixed and time=0", function() {
			var id = ashid.create("user", 0, BigInt.valueOf(javaCast("long", 1)));
			var parts = ashid.parse(id);
			t.assertEquals("user_", parts[1]);
			t.assertEquals("0", parts[2]);
			t.assertEquals("1", parts[3]);
		});
		t.it("parse variable: normalizes trailing dash to underscore in prefix", function() {
			var id = "user-10000000000001";
			var parts = ashid.parse(id);
			t.assertEquals("user_", parts[1]);
		});

		// Ashid.parse - fixed forms (no prefix)
		t.it("parse fixed: parses standard 22-char form into [empty, 9-char ts, 13-char random]", function() {
			var id = ashid.create("", 1778025600000, BigInt.valueOf(javaCast("long", 42)));
			var parts = ashid.parse(id);
			t.assertEquals("", parts[1]);
			t.assertEquals(9, len(parts[2]));
			t.assertEquals(13, len(parts[3]));
		});
		t.it("parse fixed: parses ashid4 26-char form into [empty, 13-char r1, 13-char r2]", function() {
			var r1 = ashid.encoderRef().encode(BigInt.valueOf(javaCast("long", 1)), true);
			var r2 = ashid.encoderRef().encode(BigInt.valueOf(javaCast("long", 2)), true);
			var id = r1 & r2;
			var parts = ashid.parse(id);
			t.assertEquals("", parts[1]);
			t.assertEquals(r1, parts[2]);
			t.assertEquals(r2, parts[3]);
		});
		t.it("parse fixed: throws on no-prefix body of unsupported length", function() {
			t.assertThrows(function() { ashid.parse("0000000000"); }, "ashid.InvalidId");
		});

		// Ashid.parse - returnType
		t.it("parse returnType: struct return has prefix/timestamp/random keys", function() {
			var id = ashid.create("u", 1, BigInt.valueOf(javaCast("long", 1)));
			var s = ashid.parse(id, "struct");
			t.assertTrue(isStruct(s));
			t.assertTrue(structKeyExists(s, "prefix"));
			t.assertTrue(structKeyExists(s, "timestamp"));
			t.assertTrue(structKeyExists(s, "random"));
		});
		t.it("parse returnType: throws on unknown returnType", function() {
			var id = ashid.generate("u");
			t.assertThrows(function() { ashid.parse(id, "json"); }, "ashid.InvalidArgument");
		});
		t.it("parse returnType: throws on empty input", function() {
			t.assertThrows(function() { ashid.parse(""); }, "ashid.InvalidId");
		});

		// Ashid accessors
		t.it("accessors: prefix() returns the parsed prefix incl. trailing _", function() {
			var id = ashid.create("user", 1, BigInt.valueOf(javaCast("long", 1)));
			t.assertEquals("user_", ashid.prefix(id));
		});
		t.it("accessors: prefix() returns empty for unprefixed IDs", function() {
			var id = ashid.create("", 1, BigInt.valueOf(javaCast("long", 1)));
			t.assertEquals("", ashid.prefix(id));
		});
		t.it("accessors: timestamp() recovers ms time", function() {
			var ms = 1778025600000;
			var id = ashid.create("user", ms, BigInt.valueOf(javaCast("long", 7)));
			t.assertEquals(ms, ashid.timestamp(id));
		});
		t.it("accessors: random() returns java.lang.Long matching the input", function() {
			var rndJavaLong = createObject("java", "java.lang.Long").valueOf(javaCast("long", 12345));
			var id = ashid.create("user", 1, rndJavaLong);
			var got = ashid.random(id);
			t.assertTrue(isInstanceOf(got, "java.lang.Long"));
			t.assertEquals(12345, got.longValue());
		});
		t.it("accessors: randomULong() returns BigInteger preserving full 64-bit values", function() {
			var hugeRandom = BigInt.init("18446744073709551614");  // 2^64 - 2
			var anyRand = ashid.encoderRef().encode(BigInt.ZERO, true);
			var encoded = ashid.encoderRef().encode(hugeRandom, true);
			var id = anyRand & encoded;  // 26 chars total, no prefix -> ashid4; huge in random2 slot
			var rOut = ashid.randomULong(id);
			t.assertTrue(isInstanceOf(rOut, "java.math.BigInteger"));
			t.assertTrue(rOut.equals(hugeRandom));
		});
		t.it("accessors: randomULong() on a standard ID returns the random component (matches random() value)", function() {
			var id = ashid.create("user", 1, BigInt.valueOf(javaCast("long", 12345)));
			t.assertEquals(12345, ashid.randomULong(id).longValue());
			t.assertEquals(ashid.random(id).longValue(), ashid.randomULong(id).longValue());
		});

		// Ashid.create4 / generate4 (UUID-v4 equivalent)
		t.it("create4/generate4: produces 26-char base when no prefix", function() {
			var id = ashid.generate4();
			t.assertEquals(26, len(id));
		});
		t.it("create4/generate4: produces normalized prefix + 26-char base when prefixed", function() {
			var id = ashid.generate4("token");
			t.assertEquals("token_", left(id, 6));
			t.assertEquals(32, len(id));  // "token_" + 26
		});
		t.it("create4/generate4: create4 with explicit randoms is deterministic", function() {
			var r1 = BigInt.init("123456789012345678");
			var r2 = BigInt.init("987654321098765432");
			var a = ashid.create4("u", r1, r2);
			var b = ashid.create4("u", r1, r2);
			t.assertEquals(a, b);
		});
		t.it("create4/generate4: create4 emits two 13-char padded random components", function() {
			var r1 = BigInt.valueOf(javaCast("long", 1));
			var r2 = BigInt.valueOf(javaCast("long", 2));
			var id = ashid.create4("", r1, r2);
			t.assertEquals("0000000000001" & "0000000000002", id);
		});
		t.it("create4/generate4: create4 throws on negative random when given as Long", function() {
			t.assertThrows(function() {
				ashid.create4("u", javaCast("long", -1), javaCast("long", 0));
			}, "ashid.InvalidArgument");
		});

		return t.getResults();
	}
}
