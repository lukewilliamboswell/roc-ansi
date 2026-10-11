import cli.Env
import cli.OsStr
import cli.Path
import Examples
import Files
import Headers
import Loopback
import Release
import Script

## Building the package bundle, and testing the examples against one.
Bundle := [].{

	## Bundle the working-tree package into `output_dir` with `roc_nightly`,
	## returning the path of the archive it created.
	build! = |roc_nightly, output_dir| {
		modules = Files.direct_roc_files!("package")?.map_try(Script.file_name)?
		if !modules.contains("main.roc") {
			return Script.fail!("package/main.roc does not exist")
		}
		Path.create_all!(output_dir)?
		output = Path.absolute!(output_dir)?

		# `roc bundle` takes the package entry point first, then every other module.
		args = ["bundle", "main.roc"]
			.concat(modules.keep_if(|name| name != "main.roc").map(OsStr.from_str))
			.concat(["--output-dir", Path.to_os_str(output)])
		report = roc_nightly.capture_utf8!(args, "package")?
		match Str.split_on(report, "\n").keep_oks(|line| if line.starts_with("Created: ") Ok(line.drop_prefix("Created: ").trim()) else Err(NotCreated)) {
			[created] => {
				bundle = Path.utf8(created)
				Script.require_file!(bundle)?
				Script.info!("BUNDLE", created)?
				Ok(bundle)
			}
			_ => Script.fail!("could not find the bundle path in the output of roc bundle:\n${report}")
		}
	}

	## The bundle named by `BUNDLE_PATH`, or the only one in `directory` when
	## that is unset: what the release steps after `build!` work on.
	selected! = |directory| {
		match Script.env_or!("BUNDLE_PATH", "")? {
			"" => {}
			named => return Ok(Path.utf8(named))
		}
		entries = if Path.is_dir!(directory)? Path.list!(directory)? else []
		match entries.keep_if(|path| Path.display(path).ends_with(".tar.zst")) {
			[bundle] => Ok(bundle)
			[] => Script.fail!("no bundle in ${Path.display(directory)}: build one first, or set BUNDLE_PATH")
			_ => Script.fail!("several bundles in ${Path.display(directory)}: set BUNDLE_PATH to choose one")
		}
	}

	## Run the examples against `bundle`, served from a loopback address. Only
	## temporary copies of the examples are pointed at it.
	test! = |roc_nightly, bundle| {
		Script.require_file!(bundle)?
		server = Loopback.start!(bundle)?
		Script.info!("SERVE", server.url)?
		result = Env.with_temp_dir!(
			|temporary| {
				examples = Path.join(temporary, "examples")
				Path.copy_dir!("examples", examples)?
				for example in Files.direct_roc_files!(examples)? {
					source = Path.read_utf8!(example)?
					Path.write_utf8!(example, Headers.with_dependency(source, Release.shorthand, server.url)?)?
				}
				# An empty package cache makes Roc fetch the bundle from the server.
				fetching = roc_nightly.with_empty_package_cache(Path.join(temporary, "cache"))
				Examples.exercise!(fetching, examples, Served(server))
			},
		)
		Loopback.stop!(server)?
		result
	}
}
