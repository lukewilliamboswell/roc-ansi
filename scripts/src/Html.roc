import Text

## Pure rewriting of the pages that make up the documentation site.
##
## `roc docs` knows nothing about the site around it. These functions brand its
## pages, link them back to the landing page, add the vendored Roc highlighter,
## and fill the landing page's placeholders.
Html := [].{

	## Where GitHub Pages serves the site from.
	base_path : Str
	base_path = "/roc-ansi"

	## Map the path of a preview request to what answers it: a file inside the
	## site, given as path segments, or a redirect. A path that could leave the
	## site, or names a hidden file, is not found.
	route : Str -> [File(List(Str)), Redirect(Str), NotFound]
	route = |path|
		if path == "/" or path == Html.base_path {
			Redirect("${Html.base_path}/")
		} else if !path.starts_with("${Html.base_path}/") {
			NotFound
		} else {
			relative = path.drop_prefix("${Html.base_path}/")
			segments = Str.split_on(if relative == "" or relative.ends_with("/") "${relative}index.html" else relative, "/")
			if segments.all(|segment| segment != "" and !segment.starts_with(".") and !segment.contains("\\")) {
				File(segments)
			} else {
				NotFound
			}
		}

	## The examples shown on the landing page: file stem and title.
	examples : List((Str, Str))
	examples = [
		("animals", "Animals"),
		("colors", "Colors"),
		("styles", "Styles"),
		("menu", "Menu"),
		("piece-table", "Piece table"),
	]

	## The relative link from `page` to the site root, ending in a slash.
	## `page` is relative to the site root, such as `main/ANSI/index.html`.
	root_of : Str -> Str
	root_of = |page|
		match Str.split_on(page, "/").len() - 1 {
			0 => "./"
			depth => Str.repeat("../", depth)
		}

	## Rewrite one page of the site. Pages `roc docs` did not generate only
	## gain the highlighter, and a page that needs nothing is returned as is.
	enhance : Str, Str -> Try(Str, [IncompletePage])
	enhance = |document, page| {
		if !document.contains("</head>") or !document.contains("</body>") {
			return Err(IncompletePage)
		}
		root = Html.root_of(page)
		# Links to assets at the site root: `./` is not written for those.
		prefix = if root == "./" "" else root
		generated = document.contains("id=\"sidebar-nav\"")

		highlighted = add_script(add_stylesheet(document, "roc-highlight.css", prefix), prefix)
		if generated {
			Ok(add_intro(replace_footer(add_site_link(rename_package(retitle(add_stylesheet(highlighted, "docs-site.css", prefix))), root), root), root))
		} else {
			Ok(highlighted)
		}
	}

	## The landing page's grid of example screenshots, each linking to its source.
	example_grid : List((Str, Str)) -> Str
	example_grid = |shown| {
		cards = shown.map(
			|(slug, title)| {
				label = Html.escape(title)
				"<a class=\"example\" href=\"${source_url}/${slug}.roc\"><img src=\"./examples/${slug}.png\" alt=\"${label} rendered in a terminal\" loading=\"lazy\"><span>${label}</span></a>"
			},
		)
		"<div class=\"example-grid\">${Str.join_with(cards, "")}</div>"
	}

	## The landing page's links to archived documentation, newest release first.
	version_list : List(Str) -> Str
	version_list = |versions|
		match Html.newest_first(versions) {
			[] => "<p>No archived releases yet.</p>"
			sorted => "<ul class=\"version-list\">${Str.join_with(sorted.map(|version| "<li><a href=\"./${version}/\">${version}</a></li>"), "")}</ul>"
		}

	## Order `x.y.z` versions from newest to oldest, comparing numbers, not text.
	newest_first : List(Str) -> List(Str)
	newest_first = |versions|
		List.sort_with(versions.map(|version| (numbers(version), version)), |(left, _), (right, _)| compare_numbers(right, left))
			.map(|(_, version)| version)

	## Replace the single `placeholder` in `document` with `content`.
	fill : Str, Str, Str -> Try(Str, [MissingPlaceholder(Str)])
	fill = |document, placeholder, content|
		if document.contains(placeholder) {
			Ok(Str.replace_first(document, placeholder, content))
		} else {
			Err(MissingPlaceholder(placeholder))
		}

	## Escape text for use in HTML content and attribute values.
	escape : Str -> Str
	escape = |text|
		text
			.replace_each("&", "&amp;")
			.replace_each("<", "&lt;")
			.replace_each(">", "&gt;")
			.replace_each("\"", "&quot;")
			.replace_each("'", "&#x27;")
}

package_name = "roc-ansi"

source_url = "https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples"

add_stylesheet = |document, asset, prefix|
	if document.contains(asset) {
		document
	} else {
		Str.replace_first(document, "</head>", "    <link rel=\"stylesheet\" href=\"${prefix}${asset}\">\n</head>")
	}

add_script = |document, prefix|
	if document.contains("roc-highlight.js") {
		document
	} else {
		Str.replace_first(document, "</body>", "    <script type=\"module\" src=\"${prefix}roc-highlight.js\"></script>\n</body>")
	}

# `roc docs` names the package after its directory, which is `package`.
retitle = |document|
	if document.contains("<title>package Docs</title>") {
		Str.replace_first(document, "<title>package Docs</title>", "<title>${package_name} API documentation</title>")
	} else {
		match Str.split_first(document, "<title>") {
			Ok({ before, after }) =>
				match Str.split_first(after, " Docs</title>") {
					Ok({ before: module_name, after: rest }) if Text.is_plain(module_name, "_") => "${before}<title>${module_name} · ${package_name}</title>${rest}"
					_ => document
				}
			Err(_) => document
		}
	}

rename_package = |document| {
	opening = "<h1 class=\"pkg-full-name\"><a href=\""
	closing = "\">package</a></h1>"
	match Str.split_first(document, opening) {
		Ok({ before, after }) =>
			match Str.split_first(after, "\"") {
				Ok({ before: href, after: _ }) if after.drop_prefix(href).starts_with(closing) => {
					link = if href == "" "." else href
					"${before}${opening}${link}\">${package_name}</a></h1>${after.drop_prefix(href).drop_prefix(closing)}"
				}
				_ => document
			}
		Err(_) => document
	}
}

# The sidebar grid expects exactly two rows, so the link back to the site goes
# inside the module list.
add_site_link = |document, root|
	Str.replace_first(
		document,
		"<ul class=\"module-links\">",
		"<ul class=\"module-links\">\n                <li class=\"sidebar-entry sidebar-site-link\"><a href=\"${root}\">← ${package_name} site</a></li>",
	)

replace_footer = |document, root|
	Str.replace_first(
		document,
		"<footer><p>Made by people who like to make nice things.</p></footer>",
		"<footer><p><a href=\"${root}\">${package_name}</a> is open source under the UPL-1.0 license.</p></footer>",
	)

# The package has no doc comment, so the index of the generated docs is
# otherwise empty. `roc docs` opens the content with a short `<!--!…-->` marker.
add_intro = |document, root| {
	opening = "<div class=\"main-content\">"
	if !document.contains("class=\"docs-index\"") {
		return document
	}
	match Str.split_first(document, opening) {
		Ok({ before, after }) => {
			content = after.trim_start()
			space = after.drop_suffix(content)
			match Str.split_first(content.drop_prefix("<!--!"), "-->") {
				Ok({ before: marker, after: rest }) if content.starts_with("<!--!") and marker.count_utf8_bytes() <= 4 => "${before}${opening}${space}<!--!${marker}-->${intro(root)}${rest}"
				_ => document
			}
		}
		Err(_) => document
	}
}

intro = |root|
	Str.join_with(
		[
			"",
			"        <h1 class=\"pkg-full-name-heading\">${package_name}</h1>",
			"        <p>Typed helpers for ANSI terminal control sequences in Roc: colors, text",
			"        styles, cursor and screen control, input parsing, and simple layouts.</p>",
			"        <p>Pick a module from the sidebar, or head back to the",
			"        <a href=\"${root}\">${package_name} site</a> for examples.</p>",
			"",
		],
		"\n",
	)

numbers = |version| Str.split_on(version, ".").map(|part| U64.from_str(part).ok_or(0))

compare_numbers = |left, right|
	match (left, right) {
		([a, .. as left_rest], [b, .. as right_rest]) =>
			if a < b Before else if a > b After else compare_numbers(left_rest, right_rest)
		([], []) => Same
		([], _) => Before
		(_, []) => After
	}

landing = "<html><head>\n  <link rel=\"stylesheet\" href=\"./roc-highlight.css\">\n</head><body>\n<!--EXAMPLES-->\n  <script type=\"module\" src=\"./roc-highlight.js\"></script>\n</body></html>\n"

module_page = "<html><head>\n<title>ANSI Docs</title>\n</head><body>\n<nav id=\"sidebar-nav\"><h1 class=\"pkg-full-name\"><a href=\"../\">package</a></h1>\n            <ul class=\"module-links\">\n</ul></nav>\n<div class=\"main-content\">\n<!--!x-->\n<h1>ANSI</h1></div>\n<footer><p>Made by people who like to make nice things.</p></footer>\n</body></html>\n"

index_page = "<html><head>\n<title>package Docs</title>\n</head><body class=\"docs-index\">\n<nav id=\"sidebar-nav\"><h1 class=\"pkg-full-name\"><a href=\"\">package</a></h1></nav>\n<div class=\"main-content\">\n<!--!x-->\n<p>index</p></div>\n</body></html>\n"

expect Html.root_of("index.html") == "./"
expect Html.root_of("main/index.html") == "../"
expect Html.root_of("0.13.0/ANSI/index.html") == "../../"
expect Html.enhance(landing, "index.html") == Ok(landing)
expect Html.enhance("<p>fragment</p>", "index.html") == Err(IncompletePage)
expect Html.enhance(module_page, "main/ANSI/index.html") == Ok("<html><head>\n<title>ANSI · roc-ansi</title>\n    <link rel=\"stylesheet\" href=\"../../roc-highlight.css\">\n    <link rel=\"stylesheet\" href=\"../../docs-site.css\">\n</head><body>\n<nav id=\"sidebar-nav\"><h1 class=\"pkg-full-name\"><a href=\"../\">roc-ansi</a></h1>\n            <ul class=\"module-links\">\n                <li class=\"sidebar-entry sidebar-site-link\"><a href=\"../../\">← roc-ansi site</a></li>\n</ul></nav>\n<div class=\"main-content\">\n<!--!x-->\n<h1>ANSI</h1></div>\n<footer><p><a href=\"../../\">roc-ansi</a> is open source under the UPL-1.0 license.</p></footer>\n    <script type=\"module\" src=\"../../roc-highlight.js\"></script>\n</body></html>\n")
expect {
	enhanced = Html.enhance(index_page, "main/index.html")?
	enhanced.contains("<title>roc-ansi API documentation</title>")
		and enhanced.contains("<a href=\".\">roc-ansi</a></h1>")
			and enhanced.contains("<!--!x-->\n        <h1 class=\"pkg-full-name-heading\">roc-ansi</h1>")
				and enhanced.contains("<a href=\"../\">roc-ansi site</a> for examples.</p>\n\n<p>index</p>")
}
expect Html.newest_first(["0.9.0", "0.13.1", "0.10.0", "0.13.0"]) == ["0.13.1", "0.13.0", "0.10.0", "0.9.0"]
expect Html.version_list([]) == "<p>No archived releases yet.</p>"
expect Html.version_list(["0.9.0", "0.10.0"]) == "<ul class=\"version-list\"><li><a href=\"./0.10.0/\">0.10.0</a></li><li><a href=\"./0.9.0/\">0.9.0</a></li></ul>"
expect Html.example_grid([("tui-menu", "TUI <menu>")]) == "<div class=\"example-grid\"><a class=\"example\" href=\"https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples/tui-menu.roc\"><img src=\"./examples/tui-menu.png\" alt=\"TUI &lt;menu&gt; rendered in a terminal\" loading=\"lazy\"><span>TUI &lt;menu&gt;</span></a></div>"
expect Html.fill("a <!--X--> b", "<!--X-->", "c") == Ok("a c b")
expect Html.fill("a b", "<!--X-->", "c") == Err(MissingPlaceholder("<!--X-->"))
expect Html.escape("<a href=\"x\">&'") == "&lt;a href=&quot;x&quot;&gt;&amp;&#x27;"
expect Html.route("/") == Redirect("/roc-ansi/") and Html.route("/roc-ansi") == Redirect("/roc-ansi/")
expect Html.route("/roc-ansi/") == File(["index.html"])
expect Html.route("/roc-ansi/main/ANSI/") == File(["main", "ANSI", "index.html"])
expect Html.route("/roc-ansi/site.css") == File(["site.css"])
expect Html.route("/roc-ansi/../secret") == NotFound and Html.route("/roc-ansi/main/../../secret") == NotFound
expect Html.route("/roc-ansi/.roc-ansi-site") == NotFound and Html.route("/roc-ansi//etc/passwd") == NotFound
expect Html.route("/other/") == NotFound and Html.route("/roc-ansi/a\\b") == NotFound
