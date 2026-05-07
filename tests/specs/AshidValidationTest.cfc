component {
	public array function run() {
		var t = new tests.Assert();
		var ashid = new ashid.Ashid();

		// Ashid.isValid
		t.it("isValid: accepts a freshly generated unprefixed ID", function() {
			t.assertTrue(ashid.isValid(ashid.generate()));
		});
		t.it("isValid: accepts a freshly generated prefixed ID", function() {
			t.assertTrue(ashid.isValid(ashid.generate("user")));
		});
		t.it("isValid: rejects empty string", function() {
			t.assertFalse(ashid.isValid(""));
		});
		t.it("isValid: rejects no-prefix body of unsupported length", function() {
			t.assertFalse(ashid.isValid("00000000000"));
		});
		t.it("isValid: rejects prefix that contains underscore in the middle", function() {
			// "us_er_..." - first underscore terminates prefix at "us_", then "er_..."
			// doesn't fit the expected base form, so parse will throw -> isValid returns false
			t.assertFalse(ashid.isValid("us_er_10000000000001"));
		});
		t.it("isValid: rejects body chars outside Crockford alphabet", function() {
			t.assertFalse(ashid.isValid("user_!!!!!!!!!!!!!"));
		});
		t.it("isValid: rejects prefix with digits because parse walker accepts only letters", function() {
			// Upstream parse() uses isLetter() - digits in the prefix terminate the walker
			// before any delimiter is found, causing parse to throw.
			t.assertFalse(ashid.isValid("u1_10000000000001"));
		});
		t.it("isValid: rejects pure-digit prefix for the same reason", function() {
			t.assertFalse(ashid.isValid("123_10000000000001"));
		});

		return t.getResults();
	}
}
