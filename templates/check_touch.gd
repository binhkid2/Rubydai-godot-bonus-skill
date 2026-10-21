extends RefCounted
## Chạm và vuốt giả lập đi đúng đường của điện thoại: Input.parse_input_event() sinh click giả lập
## rồi mới tới sự kiện chạm, như iOS/Android. Bắt được "không vuốt được", "bảng vừa mở đã tự đóng",
## "vuốt xong bấm nhầm" mà chuột trên Mac không thấy.
##
## Cách dùng: copy vào tools/check_touch.gd, viết lại phần run() cho màn hình của game, rồi gọi từ
## cảnh chính khi có cờ --selftest (để có autoload):
##   var failures: int = await load("res://tools/check_touch.gd").run(self)
## Chạy: godot --path . -- --selftest

static var failures := 0


static func check(name: String, ok: bool, detail := "") -> void:
	print("%s %s %s" % ["ok  " if ok else "FAIL", name, detail])
	failures += int(not ok)


static func run(app: Node) -> int:
	failures = 0
	# ScrollContainer gốc chỉ kéo bằng ngón khi có màn cảm ứng; bật cái này để desktop/headless giống điện thoại.
	Input.emulate_touch_from_mouse = true

	# --- Ví dụ 1: nút mở bảng; bảng không được tự đóng, chạm nền mờ thì đóng ---
	# var screen: Control = preload("res://scenes/shop.tscn").instantiate()
	# app.add_child(screen)
	# await wait(app, 0.3)
	# await tap(app, find_button(screen, "Cửa hàng").get_global_rect().get_center())
	# await wait(app, 0.5)
	# check("chạm nút mở bảng: bảng còn mở", screen.sheet != null)
	# await tap(app, Vector2(360, 120))            # một điểm trên nền mờ, toạ độ canvas
	# await wait(app, 0.4)
	# check("chạm nền mờ: bảng đóng", screen.sheet == null)

	# --- Ví dụ 2: vuốt bắt đầu trên một nút thì danh sách cuộn, nút không bị bấm ---
	# var scroll: ScrollContainer = screen.find_child("List", true, false)
	# var button := find_button(scroll, "Mua")
	# var presses := [0]
	# button.pressed.connect(func() -> void: presses[0] += 1)
	# var at := button.get_global_rect().get_center()
	# await drag(app, at, at - Vector2(0, 400))
	# check("vuốt trên nút thì cuộn", scroll.scroll_vertical > 100, str(scroll.scroll_vertical))
	# check("vuốt không bấm nút", presses[0] == 0)
	# await settle(app, scroll)
	# await tap(app, find_button(scroll, "Mua").get_global_rect().get_center())
	# check("hết trôi thì chạm vẫn bấm được", presses[0] == 1)

	print("touch test: %d lỗi" % failures)
	return failures


# --- Sự kiện cảm ứng ---

## Toạ độ canvas (như get_global_rect) sang toạ độ cửa sổ, qua phép co giãn màn hình (stretch canvas_items).
static func to_window(app: Node, canvas_point: Vector2) -> Vector2:
	return app.get_viewport().get_final_transform() * canvas_point


static func touch(app: Node, at: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = to_window(app, at)
	e.pressed = pressed
	Input.parse_input_event(e)
	await app.get_tree().process_frame


static func tap(app: Node, at: Vector2) -> void:
	await touch(app, at, true)
	await touch(app, at, false)


## Vuốt từ from tới to qua nhiều bước, mỗi bước một frame (có velocity để thử quán tính).
static func drag(app: Node, from: Vector2, to: Vector2, steps := 12, index := 0) -> void:
	await touch(app, from, true, index)
	var t := app.get_viewport().get_final_transform()
	var last := from
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		var e := InputEventScreenDrag.new()
		e.index = index
		e.position = t * point
		e.relative = t.basis_xform(point - last)
		e.velocity = e.relative * 60.0
		Input.parse_input_event(e)
		last = point
		await app.get_tree().process_frame
	await touch(app, to, false, index)


static func wait(app: Node, seconds: float) -> void:
	await app.get_tree().create_timer(seconds).timeout


## Chờ danh sách hết trôi quán tính.
static func settle(app: Node, scroll: ScrollContainer) -> void:
	var last := -1
	while scroll.scroll_vertical != last:
		last = scroll.scroll_vertical
		await wait(app, 0.1)


static func find_button(root: Node, text: String) -> Button:
	for b: Button in root.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	return null
