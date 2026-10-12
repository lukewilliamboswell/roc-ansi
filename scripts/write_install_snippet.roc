#!/usr/bin/env roc-stable
app [main!] {
	cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
	roc: "nightly-2026-10-09-258ab27",
}

import cli.Path
import src/Bundle
import src/Published
import src/Release
import src/Script

## Write the part of the manual that names a release: its bundle URL in a
## first program, and links to its API reference, examples and notes.
##
##     scripts/write_install_snippet.roc
##     RELEASE_VERSION=0.14.0 scripts/write_install_snippet.roc
##
## Writes `docs/generated/latest-release.adoc`, which the manual includes and
## Git ignores. It describes the latest published release, which needs `gh` to
## be authenticated. With `RELEASE_VERSION` it describes that release from the
## bundle in `dist`, or the one `BUNDLE_PATH` names: the release workflow does
## this so a release's manual names that release.
main! = |_args| {
	output : Path
	output = "docs/generated/latest-release.adoc"
	snippet = match Script.env_or!("RELEASE_VERSION", "")? {
		"" => {
			latest = Published.release!("")?
			bundle_file = match latest.assets.keep_if(Release.valid_bundle_file) {
				[only] => only
				_ => return Script.fail!("release ${latest.tag} does not have exactly one bundle attached")
			}
			examples = match Release.find_examples_archive(latest.tag, latest.assets) {
				Zip(name) => name
				LegacyTarball(name) => name
				Missing => return Script.fail!("release ${latest.tag} has no examples archive attached")
			}
			Release.install_snippet(latest.tag, bundle_url!(latest.tag, bundle_file)?, examples)
		}
		version => {
			bundle_file = Script.file_name(Bundle.selected!("dist")?)?
			Release.install_snippet(version, bundle_url!(version, bundle_file)?, Release.examples_archive(version))
		}
	}
	Path.create_all!("docs/generated")?
	Path.write_utf8!(output, snippet)?
	Script.info!("SNIPPET", Path.display(output))
}

bundle_url! = |version, bundle_file|
	match Release.bundle_url(version, bundle_file) {
		Ok(url) => Ok(url)
		Err(_) => Script.fail!("${version} and ${bundle_file} do not name a release bundle")
	}
