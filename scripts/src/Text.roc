## Pure text helpers shared by the scripts.
Text := [].{

	## Sort text by its bytes, which does not depend on the locale.
	sort : List(Str) -> List(Str)
	sort = |values| List.sort_with(values, |left, right| Text.compare(left, right))

	## Order two strings by their bytes.
	compare : Str, Str -> [Before, Same, After]
	compare = |left, right| compare_bytes(Str.to_utf8(left), Str.to_utf8(right))

	## Whether `value` is one or more ASCII digits.
	is_digits : Str -> Bool
	is_digits = |value| value != "" and Str.to_utf8(value).all(is_digit)

	## Whether `value` is one or more ASCII letters and digits.
	is_alphanumeric : Str -> Bool
	is_alphanumeric = |value| value != "" and Str.to_utf8(value).all(|byte| is_digit(byte) or is_letter(byte))

	## Whether `value` is non-empty and made only of ASCII letters, digits and
	## the bytes of `extra`.
	is_plain : Str, Str -> Bool
	is_plain = |value, extra| {
		allowed = Str.to_utf8(extra)
		value != "" and Str.to_utf8(value).all(|byte| is_digit(byte) or is_letter(byte) or allowed.contains(byte))
	}

	## Non-empty lines of `text`, without their line endings.
	lines : Str -> List(Str)
	lines = |text| Str.split_on(text, "\n").map(|line| line.drop_suffix("\r")).keep_if(|line| line != "")
}

is_digit = |byte| byte >= '0' and byte <= '9'

is_letter = |byte| (byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z')

compare_bytes = |left, right|
	match (left, right) {
		([a, .. as left_rest], [b, .. as right_rest]) =>
			if (a < b) Before else if (a > b) After else compare_bytes(left_rest, right_rest)
		([], []) => Same
		([], _) => Before
		(_, []) => After
	}

expect Text.sort(["b", "a/c", "a", "B"]) == ["B", "a", "a/c", "b"]
expect Text.compare("a", "a") == Same
expect Text.is_digits("0123") and !Text.is_digits("") and !Text.is_digits("1a")
expect Text.is_alphanumeric("Abc123") and !Text.is_alphanumeric("a.b")
expect Text.is_plain("tui-menu.roc", "-._") and !Text.is_plain("a/b", "-._") and !Text.is_plain("", "-")
expect Text.lines("a\r\n\nb\n") == ["a", "b"]
