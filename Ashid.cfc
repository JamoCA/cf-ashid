component {

	variables.MAX_TIMESTAMP = 35184372088831;
	variables.RANDOM_ENCODED_LENGTH = 13;
	variables.TIMESTAMP_ENCODED_LENGTH = 9;
	variables.STANDARD_BASE_LENGTH = 22;
	variables.ASHID4_BASE_LENGTH = 26;

	public any function init() {
		variables.encoder = new EncoderBase32Crockford();
		variables.encoder.init();
		variables.BigInt = createObject("java", "java.math.BigInteger");
		variables.MAX_LONG_BIG = variables.BigInt.valueOf(
			javaCast("long", createObject("java", "java.lang.Long").MAX_VALUE)
		);
		return this;
	}

	/**
	 * Returns normalized prefix (with trailing "_") or empty string if cleaned input
	 * is empty. Mirrors upstream Ashid.normalizePrefix.
	 */
	private string function _normalizePrefix(string prefix = "") {
		if (!len(arguments.prefix)) return "";
		var cleaned = lcase(reReplace(arguments.prefix, "[^a-zA-Z0-9]", "", "all"));
		if (!len(cleaned)) return "";
		return cleaned & "_";
	}

	public string function create(string prefix = "", numeric time, any randomLong) {
		if (!structKeyExists(arguments, "time")) arguments.time = getTickCount();
		if (!structKeyExists(arguments, "randomLong")) arguments.randomLong = variables.encoder.secureRandomLong();

		var normalizedPrefix = _normalizePrefix(arguments.prefix);

		if (arguments.time lt 0) {
			throw(type="ashid.InvalidArgument", message="Ashid timestamp must be non-negative");
		}
		if (arguments.time gt variables.MAX_TIMESTAMP) {
			throw(type="ashid.InvalidArgument", message="Ashid timestamp must not exceed 35184372088831 (Dec 12, 3084)");
		}

		var rndBig = _coerceBigInt(arguments.randomLong);
		if (rndBig.signum() lt 0) {
			throw(type="ashid.InvalidArgument", message="Ashid random value must be non-negative");
		}

		var timeBig = variables.BigInt.valueOf(javaCast("long", arguments.time));
		var baseId = "";

		if (len(normalizedPrefix)) {
			// With prefix: variable length (no padding on timestamp when 0)
			var randomEncoded = (arguments.time gt 0)
				? variables.encoder.encode(rndBig, true)
				: variables.encoder.encode(rndBig, false);
			baseId = (arguments.time gt 0)
				? variables.encoder.encode(timeBig, false) & randomEncoded
				: randomEncoded;
		} else {
			// No prefix: pad timestamp to 9, random to 13 = 22 chars
			var timeEncoded = variables.encoder.encode(timeBig, false);
			while (len(timeEncoded) lt variables.TIMESTAMP_ENCODED_LENGTH) {
				timeEncoded = "0" & timeEncoded;
			}
			var randomEncoded = variables.encoder.encode(rndBig, true);
			baseId = timeEncoded & randomEncoded;
		}

		return normalizedPrefix & baseId;
	}

	private any function _coerceBigInt(required any value) {
		if (isInstanceOf(arguments.value, "java.math.BigInteger")) return arguments.value;
		if (isInstanceOf(arguments.value, "java.lang.Long")) {
			return variables.BigInt.valueOf(arguments.value);
		}
		return variables.BigInt.valueOf(javaCast("long", arguments.value));
	}

	public string function generate(string prefix = "") {
		return create(arguments.prefix);
	}

	public any function encoderRef() {
		return variables.encoder;
	}

	public any function parse(required string id, string returnType = "array") {
		if (arguments.returnType neq "array" && arguments.returnType neq "struct") {
			throw(type="ashid.InvalidArgument", message="parse returnType must be 'array' or 'struct', got: " & arguments.returnType);
		}
		if (!len(arguments.id)) {
			throw(type="ashid.InvalidId", message="Invalid Ashid: cannot be empty");
		}

		var prefixLength = 0;
		var hasDelimiter = false;
		var i = 0;
		for (i = 1; i lte len(arguments.id); i++) {
			var ch = mid(arguments.id, i, 1);
			if (reFind("[a-zA-Z]", ch)) {
				prefixLength++;
			} else if ((ch eq "_" || ch eq "-") && prefixLength gt 0) {
				prefixLength++;
				hasDelimiter = true;
				break;
			} else {
				prefixLength = 0;
				break;
			}
		}

		var prefix = "";
		var baseId = "";
		if (hasDelimiter) {
			prefix = mid(arguments.id, 1, prefixLength);
			// Normalize trailing "-" to "_"
			if (right(prefix, 1) eq "-") {
				prefix = left(prefix, len(prefix) - 1) & "_";
			}
			baseId = mid(arguments.id, prefixLength + 1, len(arguments.id) - prefixLength);
		} else {
			baseId = arguments.id;
		}

		if (!len(baseId)) {
			throw(type="ashid.InvalidId", message="Invalid Ashid: must have a base ID");
		}

		var encodedTimestamp = "";
		var encodedRandom = "";

		if (hasDelimiter) {
			if (len(baseId) lte variables.RANDOM_ENCODED_LENGTH) {
				encodedTimestamp = "0";
				encodedRandom = baseId;
			} else {
				encodedTimestamp = mid(baseId, 1, len(baseId) - variables.RANDOM_ENCODED_LENGTH);
				encodedRandom = right(baseId, variables.RANDOM_ENCODED_LENGTH);
			}
		} else if (len(baseId) eq variables.ASHID4_BASE_LENGTH) {
			encodedTimestamp = mid(baseId, 1, variables.RANDOM_ENCODED_LENGTH);
			encodedRandom = mid(baseId, variables.RANDOM_ENCODED_LENGTH + 1, variables.RANDOM_ENCODED_LENGTH);
		} else if (len(baseId) eq variables.STANDARD_BASE_LENGTH) {
			encodedTimestamp = mid(baseId, 1, variables.TIMESTAMP_ENCODED_LENGTH);
			encodedRandom = mid(baseId, variables.TIMESTAMP_ENCODED_LENGTH + 1, variables.RANDOM_ENCODED_LENGTH);
		} else {
			throw(type="ashid.InvalidId", message="Invalid Ashid: base ID must be 22 or 26 characters without delimiter (got " & len(baseId) & ")");
		}

		if (arguments.returnType eq "array") {
			return [prefix, encodedTimestamp, encodedRandom];
		}
		return { "prefix": prefix, "timestamp": encodedTimestamp, "random": encodedRandom };
	}

	public string function prefix(required string id) {
		return parse(arguments.id)[1];
	}

	public numeric function timestamp(required string id) {
		var parts = parse(arguments.id);
		return variables.encoder.decode(parts[2]).longValue();
	}

	public any function random(required string id) {
		var parts = parse(arguments.id);
		return createObject("java", "java.lang.Long").valueOf(variables.encoder.decode(parts[3]).longValue());
	}

	public any function randomULong(required string id) {
		var parts = parse(arguments.id);
		return variables.encoder.decode(parts[3]);
	}

	public boolean function isValid(required string id) {
		if (!len(arguments.id)) return false;
		try {
			var parts = parse(arguments.id);
			var prefix = parts[1];
			if (len(prefix) gt 0 && !reFind("^[a-zA-Z0-9]+_$", prefix)) {
				return false;
			}
			variables.encoder.decode(parts[2]);
			variables.encoder.decode(parts[3]);
			return true;
		} catch (any e) {
			return false;
		}
	}

	public string function normalize(required string id) {
		var parts = parse(arguments.id);
		var prefix = parts[1];

		// Detect form. ashid4 form has parts[2] (the slot upstream calls "encodedTimestamp")
		// exactly 13 chars long, holding random1 instead of a real timestamp. Standard form's
		// timestamp encodes to <= 9 chars (45-bit MAX_TIMESTAMP).
		var isAshid4 = (len(parts[2]) eq variables.RANDOM_ENCODED_LENGTH);

		var normalizedPrefix = lcase(prefix);
		// Strip trailing "_" so create()/create4() can re-add it during normalization.
		if (right(normalizedPrefix, 1) eq "_") {
			normalizedPrefix = left(normalizedPrefix, len(normalizedPrefix) - 1);
		}

		if (isAshid4) {
			var r1 = variables.encoder.decode(parts[2]);
			var r2 = variables.encoder.decode(parts[3]);
			return create4(normalizedPrefix, r1, r2);
		}

		var ts = variables.encoder.decode(parts[2]);
		var rnd = variables.encoder.decode(parts[3]);
		return create(normalizedPrefix, ts.longValue(), rnd);
	}

	public string function create4(string prefix = "", any random1, any random2) {
		if (!structKeyExists(arguments, "random1")) arguments.random1 = variables.encoder.secureRandomULong();
		if (!structKeyExists(arguments, "random2")) arguments.random2 = variables.encoder.secureRandomULong();

		var r1 = _coerceBigInt(arguments.random1);
		var r2 = _coerceBigInt(arguments.random2);
		if (r1.signum() lt 0 || r2.signum() lt 0) {
			throw(type="ashid.InvalidArgument", message="Ashid random values must be non-negative");
		}

		var normalizedPrefix = _normalizePrefix(arguments.prefix);
		var encoded1 = variables.encoder.encode(r1, true);
		var encoded2 = variables.encoder.encode(r2, true);
		return normalizedPrefix & encoded1 & encoded2;
	}

	public string function generate4(string prefix = "") {
		return create4(arguments.prefix);
	}
}
