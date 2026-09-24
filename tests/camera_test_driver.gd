extends Node
## Headless harness for CameraController: checks the view rect never leaves the
## map at any zoom, from any pan. Scratchpad-only.

var LOG_PATH := HarnessLog.path_for("camera")

var _log: FileAccess = null
var _failures = 0


func log_line(t: String):
	if _log:
		_log.store_line(t)
		_log.flush()


func _ready():
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	get_tree().create_timer(60.0).timeout.connect(func():
		log_line("WATCHDOG - test did not finish")
		get_tree().quit(2)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	run_test()


## Duck-typed rather than "is CameraController": this runs against a copied
## project whose cached global class list predates the script.
func find_camera(node: Node):
	if node is Camera2D and node.has_method("get_map_rect"):
		return node
	for c in node.get_children():
		var f = find_camera(c)
		if f != null:
			return f
	return null


func view_rect(cam) -> Rect2:
	var size = cam.get_visible_world_size()
	return Rect2(cam.position - size * 0.5, size)


## The view must stay inside the map, except on an axis where the map is
## smaller than the view - there it must be centred instead.
func check(cam, label: String):
	var map = cam.get_map_rect()
	var view = view_rect(cam)
	var problems = []
	for axis in 2:
		var name = "x" if axis == 0 else "y"
		if map.size[axis] <= view.size[axis]:
			var map_centre = map.position[axis] + map.size[axis] * 0.5
			var view_centre = view.position[axis] + view.size[axis] * 0.5
			if absf(map_centre - view_centre) > 0.01:
				problems.append("%s not centred (map %.1f vs view %.1f)" % [name, map_centre, view_centre])
		else:
			if view.position[axis] < map.position[axis] - 0.01:
				problems.append("%s past left/top edge by %.2f" % [name, map.position[axis] - view.position[axis]])
			if view.position[axis] + view.size[axis] > map.position[axis] + map.size[axis] + 0.01:
				problems.append("%s past right/bottom edge by %.2f" % [name, view.position[axis] + view.size[axis] - (map.position[axis] + map.size[axis])])
	if problems.is_empty():
		log_line("  PASS  %-34s zoom=%.3f pos=(%.1f, %.1f) view=%s" % [label, cam.zoom.x, cam.position.x, cam.position.y, view])
	else:
		_failures += 1
		log_line("  FAIL  %-34s zoom=%.3f pos=(%.1f, %.1f) -> %s" % [label, cam.zoom.x, cam.position.x, cam.position.y, ", ".join(problems)])


func run_test():
	var cam = find_camera(get_tree().root)
	if cam == null:
		log_line("FAIL: no CameraController found")
		get_tree().quit(1)
		return

	var viewport_size = cam.get_viewport_rect().size
	var map_centre = cam.get_map_rect().position + cam.get_map_rect().size * 0.5
	log_line("viewport   : %s" % viewport_size)
	log_line("map rect   : %s" % cam.get_map_rect())
	log_line("start zoom : %.3f  pos: %s" % [cam.zoom.x, cam.position])
	log_line("zoom range : %.2f .. %.2f" % [cam.min_zoom, cam.max_zoom])
	log_line("")

	log_line("initial state (should match the old fixed camera at 576, 336):")
	check(cam, "as loaded")
	log_line("")

	# Shove the camera far outside the map at several zoom levels and confirm
	# the clamp always pulls it back to something legal.
	var far = 100000.0
	var shoves = {
		"far left": Vector2(-far, 0), "far right": Vector2(far, 0),
		"far up": Vector2(0, -far), "far down": Vector2(0, far),
		"far up-left": Vector2(-far, -far), "far down-right": Vector2(far, far),
	}
	for z in [cam.min_zoom, 0.3, 0.5, 0.7, cam.max_zoom]:
		log_line("zoom %.2f:" % z)
		cam.zoom = Vector2.ONE * z
		for label in shoves:
			cam.position = map_centre + shoves[label]
			cam.clamp_to_map()
			check(cam, label)
		log_line("")

	# Zoom limits.
	log_line("zoom clamping:")
	cam.zoom_at_screen_point(99.0, viewport_size * 0.5)
	log_line("  requested 99.0 -> %.3f (max %.2f) %s" % [cam.zoom.x, cam.max_zoom, "OK" if is_equal_approx(cam.zoom.x, cam.max_zoom) else "FAIL"])
	if not is_equal_approx(cam.zoom.x, cam.max_zoom):
		_failures += 1
	cam.zoom_at_screen_point(0.01, viewport_size * 0.5)
	log_line("  requested 0.01 -> %.3f (min %.2f) %s" % [cam.zoom.x, cam.min_zoom, "OK" if is_equal_approx(cam.zoom.x, cam.min_zoom) else "FAIL"])
	if not is_equal_approx(cam.zoom.x, cam.min_zoom):
		_failures += 1
	check(cam, "after zooming back out")
	log_line("")

	# Cursor-anchored zoom: the world point under the cursor must stay put.
	log_line("cursor-anchored zoom (world point under cursor must not drift):")
	cam.zoom = Vector2.ONE * ((cam.min_zoom + cam.max_zoom) * 0.5)
	cam.position = map_centre
	var cursor = Vector2(1000, 200) # well off-centre
	var offset = cursor - viewport_size * 0.5
	var world_before = cam.position + offset / cam.zoom.x
	cam.zoom_at_screen_point(cam.zoom.x * 1.1, cursor)
	var world_after = cam.position + offset / cam.zoom.x
	var drift = world_before.distance_to(world_after)
	log_line("  world under cursor before=%s after=%s drift=%.4f px  %s" % [world_before, world_after, drift, "OK" if drift < 0.01 else "FAIL"])
	if drift >= 0.01:
		_failures += 1
	log_line("")

	log_line("FAILURES: %d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
