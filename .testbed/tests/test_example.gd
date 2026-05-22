extends GutTest

const README_PATH := "../README.md"
const PLUGIN_CFG_PATH := "../plugin.cfg"
const ADDONS_MANIFEST_PATH := "addons.jsonc"
const EXPECTED_PLUGIN_DESCRIPTION := "Reusable AeroBeat video playback contract shell with backend abstraction, deterministic fake backend coverage, and output-surface binding for replay-facing consumers."

func _read_repo_file(relative_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path("res://%s" % relative_path)
	assert_true(FileAccess.file_exists(absolute_path), "Expected repo file to exist: %s" % absolute_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	assert_true(file != null, "Expected repo file to open: %s" % absolute_path)
	return file.get_as_text()

func test_readme_describes_video_player_contract_shell_truth() -> void:
	var readme_text := _read_repo_file(README_PATH)
	assert_true(readme_text.contains("reusable **video playback contract**"), "README should state that this repo owns the reusable video playback contract")
	assert_true(readme_text.contains("PC community first"), "README should preserve PC-first release wording")
	assert_true(readme_text.contains("Boxing and Flow"), "README should preserve the locked v1 feature slice")
	assert_true(readme_text.contains("camera only"), "README should preserve camera-only official gameplay input wording")
	assert_true(readme_text.contains("camera tracking should consume this tool"), "README should preserve the replay ownership split with camera tracking")
	assert_true(readme_text.contains("contract shell"), "README should explicitly describe the current first slice as a contract shell")

func test_plugin_cfg_describes_video_player_contract_shell() -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path("res://%s" % PLUGIN_CFG_PATH))
	assert_eq(error, OK, "plugin.cfg should parse cleanly")
	assert_eq(config.get_value("plugin", "name", ""), "AeroBeat Tool Video Player", "plugin.cfg name should reflect the repo identity")
	assert_eq(
		config.get_value("plugin", "description", ""),
		EXPECTED_PLUGIN_DESCRIPTION,
		"plugin.cfg description should stay aligned with the contract-shell scope"
	)
	assert_eq(config.get_value("plugin", "version", ""), "0.1.0", "plugin version should reflect the first implementation slice")

func test_addons_manifest_keeps_expected_dependencies_only() -> void:
	var manifest_text := _read_repo_file(ADDONS_MANIFEST_PATH)
	assert_true(manifest_text.contains('"aerobeat-tool-core"'), "addons manifest should pin aerobeat-tool-core")
	assert_true(manifest_text.contains('"gut"'), "addons manifest should pin gut for repo-local tests")
	assert_false(manifest_text.contains('"aerobeat-core"'), "addons manifest should not reintroduce stale aerobeat-core drift")
