class_name TouchScroll
extends ScrollContainer
## A ScrollContainer that swipes with a finger even when the touch lands on a child button, with inertia.
## Godot's built-in drag only works when the touch reaches the ScrollContainer, but child buttons keep the touch,
## so this handles the swipe itself in _input (which runs before buttons get the touch) and disables the
## built-in drag with a huge deadzone.
## Child buttons call dragged() on release to ignore the touch that was used for swiping.
##
## Use it instead of ScrollContainer:
##   var scroll := TouchScroll.new()
##   scroll.guard = func() -> bool: return popup_open          # optional: block swipes while an overlay is open
##   button.pressed.connect(func() -> void:
##       if scroll.dragged(): return                            # release after a swipe: don't press
##       open_item())
## Rows with their own touch handling (ScreenTouch in _gui_input) also ask scroll.dragged() on release.
## The mouse wheel and the scrollbar still work like a normal ScrollContainer.

const SLOP := 14.0
const FRICTION := 0.03

## Returns true to ignore the touch (e.g. an overlay is covering the list).
var guard := Callable()
var _touch := -1
var _start := Vector2.ZERO
var _dragging := false
var _released_drag := false
var _pos := 0.0
var _velocity := 0.0


func _init() -> void:
	scroll_deadzone = 1 << 20
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func dragged() -> bool:
	return _dragging or _released_drag


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch == -1 and get_global_rect().has_point(event.position) and not (guard.is_valid() and guard.call()):
				_touch = event.index
				_start = event.position
				_dragging = false
				_velocity = 0.0
				_pos = scroll_vertical
		elif event.index == _touch:
			_touch = -1
			if _dragging:
				_dragging = false
				# Keep the flag until the end of this frame so child buttons (handled after _input) know it was a swipe.
				_released_drag = true
				set_deferred("_released_drag", false)
	elif event is InputEventScreenDrag and event.index == _touch:
		if not _dragging and absf(event.position.y - _start.y) > SLOP:
			_dragging = true
		if _dragging:
			_scroll_to(_pos - event.relative.y)
			_velocity = lerpf(_velocity, -event.velocity.y, 0.6)


func _process(delta: float) -> void:
	if _touch != -1 or absf(_velocity) < 8.0:
		return
	_scroll_to(_pos + _velocity * delta)
	_velocity *= pow(FRICTION, delta)


func _scroll_to(value: float) -> void:
	var limit := maxf(0.0, get_v_scroll_bar().max_value - size.y)
	_pos = clampf(value, 0.0, limit)
	if _pos <= 0.0 or _pos >= limit:
		_velocity = 0.0
	scroll_vertical = int(_pos)
