extends Node

const LOG_INTERVAL: float = 5.0
const WARN_FPS: float = 30.0
const WARN_PHYSICS_BODIES: int = 150
const WARN_DRAW_CALLS: int = 500
const WARN_MEMORY_MB: float = 512.0

var _timer: float = 0.0
var _frame_times: Array[float] = []
var _log_file: FileAccess = null
var _session_start: float = 0.0
var _summary_written: bool = false


func _ready() -> void :
	if not OS.is_debug_build():
		queue_free()
		return
	_session_start = Time.get_ticks_msec() / 1000.0
	_open_log_file()
	print("[PERF] Logger started.")


func _open_log_file() -> void :
	var timestamp: String = Time.get_datetime_string_from_system()\
	.replace(":", "-").replace(" ", "_")
	var path: String = "user://perf_log_" + timestamp + ".txt"
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	if _log_file == null:
		push_warning("[PERF] Could not open log file: " + path)
		return
	_log_file.store_line("erdetspill performance log")
	_log_file.store_line("Session: " + timestamp)
	_log_file.store_line("Device: " + RenderingServer.get_video_adapter_name())
	_log_file.store_line("---")
	print("[PERF] Logging to: " + path)


func _process(delta: float) -> void :
	_frame_times.append(delta)
	if _frame_times.size() > 120:
		_frame_times.pop_front()
	_timer += delta
	if _timer >= LOG_INTERVAL:
		_timer = 0.0
		_log_snapshot()


func _log_snapshot() -> void :
	var session_time: float = Time.get_ticks_msec() / 1000.0 - _session_start

	var fps: float = Engine.get_frames_per_second()
	var avg_delta: float = _avg(_frame_times)
	var avg_fps: float = 1.0 / avg_delta if avg_delta > 0.0 else 0.0
	var max_delta: float = _max_arr(_frame_times)
	var min_fps: float = 1.0 / max_delta if max_delta > 0.0 else 0.0

	var physics_bodies: int = PhysicsServer3D.get_process_info(
		PhysicsServer3D.INFO_ACTIVE_OBJECTS
	)
	var physics_contacts: int = PhysicsServer3D.get_process_info(
		PhysicsServer3D.INFO_COLLISION_PAIRS
	)

	var draw_calls: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	var primitives: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
	)
	var objects_drawn: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
	)

	var static_mem: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	var peak_mem: float = float(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) / 1048576.0
	var video_mem: float = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0

	var node_count: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT) as int

	var line: String = (
		"[T+%05.1fs] " % session_time
		+ "FPS: %d (avg %d min %d) | " % [int(fps), int(avg_fps), int(min_fps)]
		+ "Bodies: %d Contacts: %d | " % [physics_bodies, physics_contacts]
		+ "DrawCalls: %d Prims: %d Obj: %d | " % [draw_calls, primitives, objects_drawn]
		+ "Mem: %.1fMB static %.1fMB peak %.1fMB video | " % [static_mem, peak_mem, video_mem]
		+ "Nodes: %d" % node_count
	)

	var warnings: Array[String] = []
	if fps < WARN_FPS:
		warnings.append("LOW FPS: %d" % int(fps))
	if physics_bodies > WARN_PHYSICS_BODIES:
		warnings.append("HIGH PHYSICS BODIES: %d" % physics_bodies)
	if draw_calls > WARN_DRAW_CALLS:
		warnings.append("HIGH DRAW CALLS: %d" % draw_calls)
	if static_mem > WARN_MEMORY_MB:
		warnings.append("HIGH MEMORY: %.1fMB" % static_mem)

	if not warnings.is_empty():
		line += " ⚠ " + " | ".join(warnings)
		print("[PERF] ⚠ " + line)
	else:
		print("[PERF] " + line)

	if _is_log_file_ready():
		_log_file.store_line(line)
		_log_file.flush()


func _is_log_file_ready() -> bool:
	return _log_file != null and is_instance_valid(_log_file)


func _close_log_file() -> void :
	if not _is_log_file_ready():
		_log_file = null
		return
	_log_file.close()
	_log_file = null


func _avg(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var sum: float = 0.0
	for v in arr:
		sum += v
	return sum / arr.size()


func _max_arr(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var m: float = arr[0]
	for v in arr:
		if v > m:
			m = v
	return m


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_write_summary()


func _write_summary() -> void :
	if _summary_written or not _is_log_file_ready():
		return
	_summary_written = true
	_log_file.store_line("")
	_log_file.store_line("=== SUMMARY ===")
	_log_file.store_line(
		"Session length: %.1fs" % (Time.get_ticks_msec() / 1000.0 - _session_start)
	)
	_log_file.flush()
	print("[PERF] Log saved to user://")
	print("[PERF] Open with: " + OS.get_user_data_dir())
	_close_log_file()
