component {
	public array function run() {
		// Note: ACF 2016's CFML parser chokes when a chained Java-method call
		// (e.g. foo.bar(...).baz(...)) is used directly inside an assertion. It also
		// sometimes mis-parses variables with two-letter mixed-case names like `dI`
		// when used densely. Throughout this file we split chains into intermediate
		// variables and use longer names like `bigI`/`smU` -- works on every engine.

		var t = new tests.Assert();
		var encoder = new ashid.EncoderBase32Crockford();
		var BigInt = createObject("java", "java.math.BigInteger");

		// EncoderBase32Crockford.encode (unpadded)
		t.it("encode (unpadded): encodes 0 as '0'", function() {
			var encoded = encoder.encode(BigInt.ZERO, false);
			t.assertEquals("0", encoded);
		});
		t.it("encode (unpadded): encodes 31 as 'z' (last char of lowercase Crockford alphabet)", function() {
			var v31 = BigInt.valueOf(javaCast("long", 31));
			t.assertEquals("z", encoder.encode(v31, false));
		});
		t.it("encode (unpadded): encodes 32 as '10'", function() {
			var v32 = BigInt.valueOf(javaCast("long", 32));
			t.assertEquals("10", encoder.encode(v32, false));
		});
		t.it("encode (unpadded): uses lowercase alphabet only", function() {
			var ts = BigInt.valueOf(javaCast("long", 1778025600000));
			var encoded = encoder.encode(ts, false);
			t.assertEquals(lcase(encoded), encoded);
			t.assertGT(reFind("^[0-9a-hjkmnp-tv-z]+$", encoded), 0);
		});
		t.it("encode (unpadded): throws on negative input", function() {
			var negOne = BigInt.valueOf(javaCast("long", -1));
			t.assertThrows(function() { encoder.encode(negOne, false); }, "ashid.InvalidValue");
		});

		// EncoderBase32Crockford.encode padded
		t.it("encode (padded): zero-pads to 13 chars when padded=true", function() {
			t.assertEquals("0000000000000", encoder.encode(BigInt.ZERO, true));
			var one = BigInt.valueOf(javaCast("long", 1));
			t.assertEquals("0000000000001", encoder.encode(one, true));
		});
		t.it("encode (padded): does not truncate when value already exceeds 13 chars", function() {
			// 2^65 produces a 14-char unpadded encoding; padding to 13 must not truncate.
			var one = BigInt.valueOf(javaCast("long", 1));
			var v = one.shiftLeft(65);
			var encoded = encoder.encode(v, true);
			t.assertEquals(14, len(encoded));
			t.assertEquals("10000000000000", encoded);
		});

		// EncoderBase32Crockford.decode
		t.it("decode: decodes '0' to BigInteger.ZERO", function() {
			var d = encoder.decode("0");
			t.assertTrue(d.equals(BigInt.ZERO));
		});
		t.it("decode: decodes 'z' to 31", function() {
			var d = encoder.decode("z");
			var v31 = BigInt.valueOf(javaCast("long", 31));
			t.assertTrue(d.equals(v31));
		});
		t.it("decode: decodes 'Z' (uppercase) the same as 'z'", function() {
			var dz = encoder.decode("Z");
			var dlz = encoder.decode("z");
			t.assertTrue(dz.equals(dlz));
		});
		t.it("decode: maps lookalikes I/L -> 1, O -> 0, U -> V (decode only)", function() {
			var one = BigInt.valueOf(javaCast("long", 1));
			var bigI = encoder.decode("I");
			var bigL = encoder.decode("L");
			var bigO = encoder.decode("O");
			var bigU = encoder.decode("U");
			var bigV = encoder.decode("V");
			var smU = encoder.decode("u");
			var smV = encoder.decode("v");
			t.assertTrue(bigI.equals(one));
			t.assertTrue(bigL.equals(one));
			t.assertTrue(bigO.equals(BigInt.ZERO));
			t.assertTrue(bigU.equals(bigV));
			t.assertTrue(smU.equals(smV));
		});
		t.it("decode: round-trips a year-2026 ms timestamp", function() {
			var ts = BigInt.valueOf(javaCast("long", 1778025600000));
			var enc = encoder.encode(ts, false);
			var dec = encoder.decode(enc);
			t.assertTrue(dec.equals(ts));
		});
		t.it("decode: round-trips Long.MAX_VALUE (63-bit max)", function() {
			var maxLong = createObject("java", "java.lang.Long").MAX_VALUE;
			var v = BigInt.valueOf(javaCast("long", maxLong));
			var enc = encoder.encode(v, true);
			var dec = encoder.decode(enc);
			t.assertTrue(dec.equals(v));
		});
		t.it("decode: round-trips a 64-bit ULong-equivalent value", function() {
			var v = createObject("java", "java.math.BigInteger").init("18446744073709551615");  // 2^64 - 1
			var enc = encoder.encode(v, true);
			var dec = encoder.decode(enc);
			t.assertTrue(dec.equals(v));
		});
		t.it("decode: throws on illegal characters", function() {
			t.assertThrows(function() { encoder.decode("!"); }, "ashid.InvalidChar");
		});
		t.it("decode: throws on empty string", function() {
			t.assertThrows(function() { encoder.decode(""); }, "ashid.InvalidValue");
		});

		// EncoderBase32Crockford secure-random
		t.it("secureRandomLong returns a BigInteger in [0, 2^63 - 1]", function() {
			var ZERO = BigInt.ZERO;
			var maxLongJ = createObject("java", "java.lang.Long").MAX_VALUE;
			var MAX_LONG = BigInt.valueOf(javaCast("long", maxLongJ));
			for (var i = 1; i lte 20; i++) {
				var v = encoder.secureRandomLong();
				t.assertTrue(isInstanceOf(v, "java.math.BigInteger"));
				t.assertGTE(v.signum(), 0);
				t.assertGTE(0, v.compareTo(MAX_LONG));
			}
		});
		t.it("secureRandomULong returns a BigInteger in [0, 2^64 - 1]", function() {
			var MAX_ULONG = createObject("java", "java.math.BigInteger").init("18446744073709551615");
			for (var i = 1; i lte 20; i++) {
				var v = encoder.secureRandomULong();
				t.assertTrue(isInstanceOf(v, "java.math.BigInteger"));
				t.assertGTE(v.signum(), 0);
				t.assertGTE(0, v.compareTo(MAX_ULONG));
			}
		});
		t.it("secureRandomLong produces different values across calls", function() {
			var a = encoder.secureRandomLong();
			var b = encoder.secureRandomLong();
			t.assertFalse(a.equals(b));
		});

		return t.getResults();
	}
}
