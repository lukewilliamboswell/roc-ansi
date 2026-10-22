# Development environment and tasks for roc-ansi, realised by roc-blueprint without Nix.
#
#     blueprint run check    # everything CI checks
#     blueprint run serve    # build the documentation site and preview it
#     blueprint shell        # the environment, to run scripts/*.roc directly
#     blueprint update       # refresh Blueprint.lock
#
# `roc-stable` runs repository scripts; `roc` on PATH tests the package and
# examples on the latest nightly, so nothing here provides a bare `roc`.
# The released SBOM app has its own matching `roc-sbom` compiler. Blueprint
# embeds its configuration compiler independently of these environment inputs.
app [config] { pf: platform "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.7.0/2zwBq8cAkEPfRNMaWgtwCsVwxSJ3z9FncazjNofBXspG.tar.zst" }

import pf.Recipes
import pf.Config
import pf.System

docs_renderer : System -> Config.Download
docs_renderer = |system| match system {
	"x86_64-linux" | "aarch64-linux" | "aarch64-darwin" => File("https://github.com/lukewilliamboswell/roc-automation/releases/download/tools-0.3.0/roc-docs-${system.to_str()}")
	_ => Unavailable
}

sbom_app = "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.7.0/roc-blueprint-sbom-2pLqc6Kr6KE3fw5JE4z17TMnhKYP3npqDMBTVm9K2oKP.tar.zst"

config = [
	Name("roc-ansi"),
	Environment(
		"dev",
		[
			Programs([Fetch("roc-stable", Recipes.roc_nightly("nightly-2026-10-09-258ab27"))]),
			# Every bundle the scripts depend on, including dependencies of
			# dependencies: `roc-stable deps scripts/check_all.roc` lists them.
			RocPackages([
				"https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
				"https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
			]),
			# Programs the scripts start.
			Expect(["chmod", "gh", "git", "gzip", "roc", "shasum", "tar", "test", "touch", "unzip", "zip"]),
		],
	),
	Environment("docs", [Programs([Fetch("roc-docs", docs_renderer)]), Expect(["realpath", "sh"])]),
	Environment("sbom", [
		Extend("dev"),
		Programs([
			Fetch("roc-sbom", Recipes.roc_nightly("nightly-2026-10-21-5349569")),
		]),
		RocPackages([
			"https://github.com/roc-lang/basic-cli/releases/download/0.26.0-rc2/Gj3zVDr3qrQa6aTh7Z1zgUfe9NeBE6R76T5ho3xrc8af.tar.zst",
			"https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
			"https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
		]),
		Expect(["blueprint", "env", "git", "realpath", "roc", "sh", "shasum", "tar"]),
	]),
	Shell("default", [Use("dev")]),
	Task("sbom", [Use("sbom"), Run(["scripts/release_sbom.roc"])]),
	Task("sbom-tool", [Use("sbom"), Run(["roc-sbom", "run", sbom_app])]),
	Task("docs", [Use("docs"), Run(["roc-docs", "build", "--workspace", ".", "--docs-directory", "docs", "--entrypoint", "index.adoc", "--pdf-filename", "roc-ansi.pdf", "--site-url", "https://lukewilliamboswell.github.io/roc-ansi/"])]),
	Task("docs-path", [Use("docs"), Run(["sh", "-c", "realpath \"$(command -v roc-docs)\""])]),
	# Everything CI checks.
	Task("check", [Use("dev"), Run(["scripts/check_all.roc"])]),
	# The examples alone, compared with tests/spec.json. To record new output:
	# blueprint shell, then scripts/test_examples.roc -- --update
	Task("examples", [Use("dev"), Run(["scripts/test_examples.roc"])]),
	# The steps of a release, which .github/workflows/release.yml runs in order.
	Task("bundle", [Use("dev"), Run(["scripts/build_bundle.roc"])]),
	Task("test-bundle", [Use("dev"), Run(["scripts/test_bundle.roc"])]),
	Task("package-examples", [Use("dev"), Run(["scripts/package_examples.roc"])]),
	Task("package-docs", [Use("dev"), Run(["scripts/package_docs.roc"])]),
	Task("check-version", [Use("dev"), Run(["scripts/check_version.roc"])]),
	Task("release-notes", [Use("dev"), Run(["scripts/render_release_notes.roc"])]),
	# The latest release's examples, as published, on the current compiler.
	Task("fetch-published", [Use("dev"), Run(["scripts/fetch_published.roc"])]),
	Task("test-published", [Use("dev"), Run(["scripts/test_published.roc"])]),
	# The parts of the manual that depend on what is released; see docs/contributing.adoc.
	Task("install-snippet", [Use("dev"), Run(["scripts/write_install_snippet.roc"])]),
	# The API reference of the GitHub Pages site: add it to the rendered manual,
	# or add it and preview the site locally.
	Task("site", [Use("dev"), Run(["scripts/build_site.roc"])]),
	Task("serve", [Use("dev"), Run(["scripts/serve_site.roc"])]),
]
