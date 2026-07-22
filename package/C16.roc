import C256

## [Ansi 16 colors](https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit)
## These colors can be customized, leading to variations across different terminals.
## Therefore, if your use case requires a consistent color palette, it's recommended to avoid using them.
C16 := [Standard(Name), Bright(Name)].{
	is_eq : _
	to_hash : _

	Name := [Black, Red, Green, Yellow, Blue, Magenta, Cyan, White].{
		is_eq : _
		to_hash : _
	}

	name_to_code : Name -> U8
	name_to_code = |name|
		match name {
			Black => 0
			Red => 1
			Green => 2
			Yellow => 3
			Blue => 4
			Magenta => 5
			Cyan => 6
			White => 7
		}

	to_c256 : C16 -> U8
	to_c256 = |intensity|
		match intensity {
			Standard(name) => 0 + C16.name_to_code(name)
			Bright(name) => 8 + C16.name_to_code(name)
		}
}
