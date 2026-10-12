import cli.Path
import DocsArchive
import Files
import Html
import Release
import Script

## The API reference on the GitHub Pages site.
##
## The shared build-docs action renders the manual in `docs/` into a
## directory. This adds the generated API documentation beside it: fresh docs
## for the working tree under `main/`, and the archived docs of each release
## under its version, where they have always been published.
Site := [].{

	## Generate the API documentation of the working tree into `output`.
	docs! = |roc, output|
		roc.run!(["docs", "package/main.roc", "--output=${Path.display(output)}"])

	## Add the API documentation to the site in `output` with `roc`, creating
	## that directory when no manual has been rendered into it. `releases`
	## says whether to restore archived docs from release assets, which needs
	## network access: `FetchReleaseDocs` or `SkipReleaseDocs`.
	assemble! = |roc, output, releases| {
		Path.create_all!(output)?
		# build-docs copies this from docs/ too; a site without the manual needs it.
		stylesheet = Path.join(output, "docs-site.css")
		if !Path.exists!(stylesheet)? {
			Path.copy!("docs/docs-site.css", stylesheet)?
		}
		# Only what an earlier run of this script added is replaced.
		for earlier in Path.list!(output)? {
			if is_api_directory(Script.file_name(earlier)?) {
				Path.delete_all!(earlier)?
			}
		}
		match releases {
			FetchReleaseDocs => DocsArchive.fetch!(output)?
			SkipReleaseDocs => {}
		}

		main_docs = Path.join(output, "main")
		roc
			.cmd(["docs", "package/main.roc", "--output=${Path.display(main_docs)}"])
			.env_str("ROC_DOCS_URL_ROOT", "${Html.base_path}/main")
			.exec_cmd!()?

		enhanced = enhance_pages!(output)?
		Script.info!("SITE", "${Path.display(output)}, with ${enhanced.to_str()} pages of API reference rewritten")
	}
}

is_api_directory = |name| name == "main" or Release.valid_docs_version(name)

enhance_pages! : Path => Try(U64, _)
enhance_pages! = |output| {
	root_prefix = "${Path.display(output)}/"
	var $changed = 0
	for page in Files.all_files!(output)?.keep_if(|path| Files.has_ext(path, "html")) {
		relative = Path.display(page).drop_prefix(root_prefix)
		# The manual's pages are left exactly as they were rendered.
		if is_api_directory(Str.split_first(relative, "/").map_ok(|parts| parts.before) ?? "") {
			document = Path.read_utf8!(page)?
			match Html.enhance(document, relative) {
				Ok(enhanced) if enhanced != document => {
					Path.write_utf8!(page, enhanced)?
					$changed = $changed + 1
				}
				Ok(_) => {}
				Err(IncompletePage) => return Script.fail!("cannot rewrite ${Path.display(page)}: incomplete HTML document")
			}
		}
	}
	Ok($changed)
}
