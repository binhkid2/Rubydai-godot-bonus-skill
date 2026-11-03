extends SceneTree
## App Store screenshots on the desktop (macOS, Windows or Linux), without the iOS Simulator: renders a scene at the size App Store Connect asks
## for, with the device's notch and home bar kept clear, and saves a PNG. See references/testing.md §5.
##
##   godot --path . --script res://tools/store_shots.gd -- --device iphone --out res://shots/appstore
##   godot --path . --script res://tools/store_shots.gd -- --device ipad --scene res://scenes/level_3.tscn
##
## Needs a window (not --headless). Point SAFE_AREA_SCRIPT at the script whose static var the HUD reads instead of
## DisplayServer.get_display_safe_area() (top and bottom insets as shares of the screen height; negative = none).
## For a nicer picture than a new game (money, a full room, no warnings), give the scene a demo or showcase flag and
## set it before add_child(), the way the project's own capture tools do.

const DEVICES := {
	"iphone": {"size": Vector2i(1320, 2868), "safe": Vector2(62.0 / 956.0, 34.0 / 956.0)},
	"ipad": {"size": Vector2i(2064, 2752), "safe": Vector2(24.0 / 1376.0, 20.0 / 1376.0)},
}
## The script holding the HUD's simulated safe area, and the static var's name. "" to skip.
const SAFE_AREA_SCRIPT := "res://scripts/hud.gd"
const SAFE_AREA_VAR := "simulated_safe"
## Real time, not frames: a 120 Hz display runs frames twice as fast.
const WAIT_SECONDS := 2.0

func _initialize() -> void:
	call_deferred("run")

func arg(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback

func run() -> void:
	var device := arg("--device", "iphone")
	var phone: Dictionary = DEVICES[device]
	if SAFE_AREA_SCRIPT != "" and ResourceLoader.exists(SAFE_AREA_SCRIPT):
		load(SAFE_AREA_SCRIPT).set(SAFE_AREA_VAR, phone.safe)
	# A bordered window taller than the screen gets cut to the screen's height (measured on macOS); a borderless one keeps its size.
	root.borderless = true
	root.size = phone.size
	var scene_path := arg("--scene", str(ProjectSettings.get_setting("application/run/main_scene")))
	root.add_child(load(scene_path).instantiate())
	await create_timer(WAIT_SECONDS).timeout
	await RenderingServer.frame_post_draw
	var folder := arg("--out", "res://shots/appstore")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := "%s/%s-%s.png" % [folder, scene_path.get_file().get_basename(), device]
	var image := root.get_texture().get_image()
	print("%s %s: %s" % [path, image.get_size(), error_string(image.save_png(path))])
	quit()
