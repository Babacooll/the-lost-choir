extends Control
## Draws the last tell window (including its §3.3 pre-window buffer) against
## the actual Answer press, so the fairness rule is visually verifiable — not
## just asserted in tests — per §11.2/§11.3's instrumentation requirement.

const WINDOW_SPAN_MS: float = 2000.0  # how much history the timeline shows

var onset_ms: float = -INF
var close_ms: float = -INF
var buffer_ms: float = 0.0
var press_ms: float = -INF
var result: String = ""
var transient_ms: float = -INF


func set_data(p_onset_ms: float, p_close_ms: float, p_buffer_ms: float, p_press_ms: float, p_result: String, p_transient_ms: float = -INF) -> void:
	onset_ms = p_onset_ms
	close_ms = p_close_ms
	buffer_ms = p_buffer_ms
	press_ms = p_press_ms
	result = p_result
	transient_ms = p_transient_ms
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.1, 1.0))

	if onset_ms == -INF:
		return

	var now := Time.get_ticks_msec()
	var span_start := now - WINDOW_SPAN_MS

	var buffer_start_x := _to_x(onset_ms - buffer_ms, span_start)
	var onset_x := _to_x(onset_ms, span_start)
	var close_x := _to_x(close_ms, span_start)
	var mid_y := size.y * 0.5
	var band_h := size.y * 0.4

	# Pre-window buffer segment (dim) leading into the real tell window (bright).
	draw_rect(Rect2(Vector2(buffer_start_x, mid_y - band_h * 0.5), Vector2(onset_x - buffer_start_x, band_h)),
		Color(0.45, 0.4, 0.15, 1.0))
	draw_rect(Rect2(Vector2(onset_x, mid_y - band_h * 0.5), Vector2(close_x - onset_x, band_h)),
		Color(0.85, 0.72, 0.2, 1.0))

	# §5 shared rule 2: the identifying transient, marked as a thin tick so
	# its timing is inspectable rather than just asserted in tests.
	if transient_ms != -INF and transient_ms >= span_start:
		var transient_x := _to_x(transient_ms, span_start)
		draw_line(Vector2(transient_x, mid_y - band_h * 0.5 - 4.0), Vector2(transient_x, mid_y + band_h * 0.5 + 4.0),
			Color(1.0, 1.0, 1.0, 1.0), 1.5)

	if press_ms != -INF and press_ms >= span_start:
		var press_x := _to_x(press_ms, span_start)
		var color := Color(0.6, 0.6, 0.6, 1.0)
		if result == "success":
			color = Color(0.25, 0.9, 0.35, 1.0)
		elif result == "whiff":
			color = Color(0.9, 0.25, 0.25, 1.0)
		draw_line(Vector2(press_x, 0.0), Vector2(press_x, size.y), color, 2.0)


func _to_x(t_ms: float, span_start: float) -> float:
	return clampf((t_ms - span_start) / WINDOW_SPAN_MS, 0.0, 1.0) * size.x


func _process(_delta: float) -> void:
	# Redraw continuously so the timeline scrolls even between data updates.
	queue_redraw()
