import cli.Path
import Text

## Deterministic filesystem discovery for the scripts.
Files := [].{

	## The `.roc` files directly inside `directory`, sorted by path.
	direct_roc_files! : Path => Try(List(Path), _)
	direct_roc_files! = |directory| {
		entries = Path.list!(directory)?
		Ok(Files.sort_paths(entries.keep_if(|path| Files.has_ext(path, "roc"))))
	}

	## Every regular file beneath `directory`, sorted by path. A symbolic link
	## is an error, so nothing outside the tree is ever read or archived.
	all_files! : Path => Try(List(Path), _)
	all_files! = |directory| {
		found = walk!(Path.list!(directory)?, [])?
		Ok(Files.sort_paths(found))
	}

	## Every `.roc` file beneath `directory`, with its source, sorted by path.
	roc_sources! : Path => Try(List({ path : Path, source : Str }), _)
	roc_sources! = |directory| {
		paths = Files.all_files!(directory)?
		read_sources!(paths.keep_if(|path| Files.has_ext(path, "roc")), [])
	}

	## Whether the final component of `path` ends in `.extension`.
	has_ext : Path, Str -> Bool
	has_ext = |path, extension| Path.ext(path).map_ok(Path.display) == Ok(extension)

	## The part of a file name before its first dot.
	stem : Str -> Str
	stem = |file_name|
		match Str.split_first(file_name, ".") {
			Ok({ before, .. }) => before
			Err(_) => file_name
		}

	## Sort paths by the bytes of their displayed form.
	sort_paths : List(Path) -> List(Path)
	sort_paths = |paths| List.sort_with(paths, |left, right| Text.compare(Path.display(left), Path.display(right)))
}

walk! = |entries, found|
	match entries {
		[path, .. as rest] =>
			match Path.type!(path)? {
				IsDir => walk!(rest, walk!(Path.list!(path)?, found)?)
				IsFile => walk!(rest, found.append(path))
				_ => Err(NotARegularFile(Path.display(path)))
			}
		[] => Ok(found)
	}

read_sources! = |paths, sources|
	match paths {
		[path, .. as rest] => read_sources!(rest, sources.append({ path, source: Path.read_utf8!(path)? }))
		[] => Ok(sources)
	}
