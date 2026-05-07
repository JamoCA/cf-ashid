/**
 * Minimal in-house assertion helpers + result accumulator.
 *
 * Pattern in a spec file:
 *
 *	public array function run() {
 *		var t = new tests.Assert();
 *		t.it("does the thing", function() {
 *			t.assertEquals("user_", ashid.prefix("user_..."));
 *		});
 *		return t.getResults();
 *	}
 */
component {

	public any function init() {
		variables.results = [];
		return this;
	}

	public void function it(required string name, required any callback) {
		try {
			arguments.callback();
			arrayAppend(variables.results, [
				"name": arguments.name,
				"status": "pass",
				"message": ""
			]);
		} catch (any e) {
			arrayAppend(variables.results, [
				"name": arguments.name,
				"status": "fail",
				"message": (structKeyExists(e, "message") ? e.message : toString(e)) & (structKeyExists(e, "detail") && len(e.detail) ? " | " & e.detail : "")
			]);
		}
	}

	public void function assertTrue(required boolean cond, string msg = "") {
		if (!arguments.cond) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg : "Expected true; was false"));
		}
	}

	public void function assertFalse(required boolean cond, string msg = "") {
		if (arguments.cond) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg : "Expected false; was true"));
		}
	}

	/**
	 * Case-sensitive equality. Both args coerced to string for comparison so this
	 * works for primitives and Java types whose toString() yields the canonical form.
	 */
	public void function assertEquals(required any expected, required any actual, string msg = "") {
		var e = toString(arguments.expected);
		var a = toString(arguments.actual);
		if (compare(e, a) neq 0) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg & " | " : "") & "Expected '" & e & "'; was '" & a & "'");
		}
	}

	public void function assertNotEquals(required any expected, required any actual, string msg = "") {
		if (compare(toString(arguments.expected), toString(arguments.actual)) eq 0) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg : "Expected values to differ; both were '" & toString(arguments.expected) & "'"));
		}
	}

	/**
	 * Asserts the callback throws. If expectedType is non-empty, the throw's type
	 * must match exactly.
	 */
	public void function assertThrows(required any callback, string expectedType = "", string msg = "") {
		var threw = false;
		var caughtType = "";
		try {
			arguments.callback();
		} catch (any e) {
			threw = true;
			caughtType = (structKeyExists(e, "type") ? e.type : "");
		}
		if (!threw) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg : "Expected callback to throw; it did not"));
		}
		if (len(arguments.expectedType) gt 0 && caughtType neq arguments.expectedType) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg & " | " : "") & "Expected throw type '" & arguments.expectedType & "'; got '" & caughtType & "'");
		}
	}

	public void function assertGTE(required numeric a, required numeric b, string msg = "") {
		if (arguments.a lt arguments.b) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg : "Expected " & arguments.a & " >= " & arguments.b));
		}
	}

	public void function assertGT(required numeric a, required numeric b, string msg = "") {
		if (arguments.a lte arguments.b) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg : "Expected " & arguments.a & " > " & arguments.b));
		}
	}

	public void function assertReFind(required string pattern, required string str, string msg = "") {
		if (reFindNoCase(arguments.pattern, arguments.str) eq 0) {
			throw(type="ashid.AssertionFailed", message=(len(arguments.msg) ? arguments.msg : "String '" & arguments.str & "' did not match pattern '" & arguments.pattern & "'"));
		}
	}

	public array function getResults() {
		return variables.results;
	}
}
