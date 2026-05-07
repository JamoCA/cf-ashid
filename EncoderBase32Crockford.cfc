/**
 * Crockford Base32 encoder/decoder.
 *
 * Alphabet and lookalike-character mappings per Douglas Crockford's spec:
 * https://www.crockford.com/base32.html
 *
 * Lowercase canonical alphabet. Decode tolerates uppercase plus the lookalikes
 * I/L -> 1, O -> 0, U -> V.
 */
component {

	variables.ALPHABET = "0123456789abcdefghjkmnpqrstvwxyz";

	public any function init() {
		variables.BigInt = createObject("java", "java.math.BigInteger");
		variables.ZERO   = variables.BigInt.ZERO;
		variables.BIG_32 = variables.BigInt.valueOf(javaCast("long", 32));
		variables.BIG_256 = variables.BigInt.valueOf(javaCast("long", 256));
		variables.MAX_LONG_BIG = variables.BigInt.valueOf(
			javaCast("long", createObject("java", "java.lang.Long").MAX_VALUE)
		);
		variables.secureRandom = createObject("java", "java.security.SecureRandom").init();
		// Decode lookup: case-sensitive struct because some CFML engines (ACF 2016)
		// run switch statements case-insensitively, which would collide o/O, a/A, etc.
		variables.DECODE_MAP = _buildDecodeMap();
		// Cache reflective Method handles for BigInteger.add / .multiply. BoxLang
		// 1.x resolves a bare `bigInteger.add(...)` call against the CFML Number.add
		// BIF when the receiver is numerically zero (BigInteger.ZERO or valueOf(0)),
		// which fails with "Required argument number is missing for function add".
		// Going through java.lang.reflect.Method.invoke bypasses the BIF dispatcher
		// and forces the actual Java instance method on every engine.
		var BigIntClass = variables.BigInt.getClass();
		variables._addMethod = BigIntClass.getMethod("add", [BigIntClass]);
		variables._mulMethod = BigIntClass.getMethod("multiply", [BigIntClass]);
		return this;
	}

	private any function _bigAdd(required any a, required any b) {
		return variables._addMethod.invoke(arguments.a, [arguments.b]);
	}

	private any function _bigMul(required any a, required any b) {
		return variables._mulMethod.invoke(arguments.a, [arguments.b]);
	}

	private struct function _buildDecodeMap() {
		var m = {};
		// Crockford alphabet: 0-9, a-h, j-k, m-n, p-t, v-z (32 chars)
		var alpha = "0123456789abcdefghjkmnpqrstvwxyz";
		for (var i = 1; i lte len(alpha); i++) {
			var ch = mid(alpha, i, 1);
			m[ch] = i - 1;
			m[ucase(ch)] = i - 1;
		}
		// Crockford lookalike normalisations
		m["o"] = 0;  m["O"] = 0;   // letter O -> 0
		m["i"] = 1;  m["I"] = 1;   // letter I -> 1
		m["l"] = 1;  m["L"] = 1;   // letter L -> 1
		m["u"] = 27; m["U"] = 27;  // letter U -> V (decode only)
		return m;
	}

	public string function encode(required any value, boolean padded = false) {
		if (!structKeyExists(variables, "ZERO")) init();
		var bigInt = _coerceBigInt(arguments.value);
		if (bigInt.signum() lt 0) {
			throw(type="ashid.InvalidValue", message="Input must be a non-negative number");
		}
		var encoded = _encodeRecursive(bigInt);
		if (arguments.padded) {
			while (len(encoded) lt 13) {
				encoded = "0" & encoded;
			}
		}
		return encoded;
	}

	private string function _encodeRecursive(required any bigInt) {
		if (arguments.bigInt.equals(variables.ZERO)) {
			return "0";
		}
		var remainder = arguments.bigInt.mod(variables.BIG_32).intValue();
		var quotient = arguments.bigInt.divide(variables.BIG_32);
		if (quotient.equals(variables.ZERO)) {
			return mid(variables.ALPHABET, remainder + 1, 1);
		}
		return _encodeRecursive(quotient) & mid(variables.ALPHABET, remainder + 1, 1);
	}

	private any function _coerceBigInt(required any value) {
		if (isInstanceOf(arguments.value, "java.math.BigInteger")) return arguments.value;
		return variables.BigInt.valueOf(javaCast("long", arguments.value));
	}

	public any function decode(required string str) {
		if (!structKeyExists(variables, "ZERO")) init();
		if (!len(arguments.str)) {
			throw(type="ashid.InvalidValue", message="Input string cannot be empty");
		}
		var result = variables.ZERO;
		var i = 0;
		for (i = 1; i lte len(arguments.str); i++) {
			var ch = mid(arguments.str, i, 1);
			var v = _decodeChar(ch);
			if (v eq -1) {
				throw(type="ashid.InvalidChar", message="Invalid character in Base32 string: '" & ch & "'");
			}
			result = _bigAdd(
				_bigMul(result, variables.BIG_32),
				variables.BigInt.valueOf(javaCast("long", v))
			);
		}
		return result;
	}

	private numeric function _decodeChar(required string ch) {
		// Use struct lookup -- portable across ACF/Lucee/BoxLang. ACF 2016's switch
		// statement is case-insensitive (o == O, a == A, etc.) which would break
		// the Crockford lookalike map below if expressed as cases.
		if (structKeyExists(variables.DECODE_MAP, arguments.ch)) {
			return variables.DECODE_MAP[arguments.ch];
		}
		return -1;
	}

	/**
	 * Reproduces upstream `secureRandomLong()`: 8 bytes from SecureRandom built into a
	 * 64-bit value, then masked with Long.MAX_VALUE. Returns BigInteger in [0, 2^63 - 1].
	 */
	public any function secureRandomLong() {
		if (!structKeyExists(variables, "ZERO")) init();
		var bytes = javaCast("byte[]", listToArray(repeatString("0,", 8), ","));
		variables.secureRandom.nextBytes(bytes);
		var v = variables.ZERO;
		for (var i = 1; i lte 8; i++) {
			var unsignedByte = bitAnd(bytes[i], 255);
			v = _bigAdd(
				_bigMul(v, variables.BIG_256),
				variables.BigInt.valueOf(javaCast("long", unsignedByte))
			);
		}
		return v.and(variables.MAX_LONG_BIG);
	}

	/**
	 * Reproduces upstream `secureRandomULong()`: 8 bytes from SecureRandom built into a
	 * 64-bit unsigned value. Returns BigInteger in [0, 2^64 - 1].
	 */
	public any function secureRandomULong() {
		if (!structKeyExists(variables, "ZERO")) init();
		var bytes = javaCast("byte[]", listToArray(repeatString("0,", 8), ","));
		variables.secureRandom.nextBytes(bytes);
		var v = variables.ZERO;
		for (var i = 1; i lte 8; i++) {
			var unsignedByte = bitAnd(bytes[i], 255);
			v = _bigAdd(
				_bigMul(v, variables.BIG_256),
				variables.BigInt.valueOf(javaCast("long", unsignedByte))
			);
		}
		return v;
	}
}
