class_name TouchScroll
extends ScrollContainer
## ScrollContainer vuốt bằng ngón tay được cả khi chạm trúng nút con, có quán tính.
## Kéo gốc của Godot chỉ chạy khi cú chạm tới được ScrollContainer, mà nút con thì giữ cú chạm,
## nên ở đây tự xử lý vuốt trong _input (chạy trước khi nút nhận chạm) và tắt kéo gốc bằng deadzone rất lớn.
## Nút con gọi dragged() lúc nhả tay để bỏ qua cú chạm vừa dùng để vuốt.
##
## Dùng thay cho ScrollContainer:
##   var scroll := TouchScroll.new()
##   scroll.guard = func() -> bool: return popup_open          # tuỳ chọn: chặn vuốt khi có lớp phủ
##   button.pressed.connect(func() -> void:
##       if scroll.dragged(): return                            # nhả tay sau khi vuốt: không bấm
##       open_item())
## Hàng tự nhận chạm (ScreenTouch trong _gui_input) cũng hỏi scroll.dragged() lúc nhả tay.
## Con lăn chuột và thanh cuộn vẫn chạy như ScrollContainer thường.

const SLOP := 14.0
const FRICTION := 0.03

## Trả về true thì bỏ qua cú chạm (ví dụ đang có lớp phủ che lên).
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
				# Giữ cờ tới hết frame này để nút con (xử lý sau _input) biết đây là cú vuốt.
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
