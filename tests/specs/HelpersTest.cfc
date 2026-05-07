component {
	public array function run() {
		var t = new tests.Assert();
		request.ashid = new ashid.Ashid();
		// helpers.cfm defines top-level UDFs; including it inside run() makes
		// them available to the closures defined below (the spec file only
		// ever calls run(), so there's no risk of those UDFs leaking).
		include "/ashid/helpers.cfm";

		// helpers.cfm
		t.it("helpers: ashid() generates a 22-char no-prefix ID", function() {
			t.assertEquals(22, len(ashid()));
		});
		t.it("helpers: ashid('user') generates a prefixed ID", function() {
			t.assertEquals("user_", left(ashid("user"), 5));
		});
		t.it("helpers: ashid4('token') generates a 26-char-base prefixed ID", function() {
			var id = ashid4("token");
			t.assertEquals("token_", left(id, 6));
			t.assertEquals(32, len(id));
		});
		t.it("helpers: parseAshid returns 3-element array", function() {
			var parts = parseAshid(ashid("u"));
			t.assertEquals(3, arrayLen(parts));
		});
		t.it("helpers: throws when no singleton wired", function() {
			structDelete(request, "ashid");
			t.assertThrows(function() { ashid(); }, "ashid.NotWired");
			request.ashid = new ashid.Ashid();  // restore for any subsequent tests
		});

		return t.getResults();
	}
}
