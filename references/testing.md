# Kiểm tra game Godot trước khi đưa người dùng thử

"Chạy trong editor được" chưa phải là xong. Thứ tự kiểm tra dưới đây đi từ rẻ tới đắt; làm hết các bước hợp với thay đổi, rồi nói rõ đã kiểm gì, bằng cách nào, và còn gì phải thử trên máy thật.

---

## 1. Script nạp được

```sh
godot --headless --path . --import                      # sau khi thêm/đổi class_name, asset mới
godot --headless --path . --quit-after 120              # chạy cảnh chính 120 frame, có autoload: bắt lỗi parse và lỗi lúc chạy
godot --headless --path . --check-only --script res://scripts/x.gd   # soát một file; báo thiếu autoload là bình thường
```

Đọc kỹ dòng `SCRIPT ERROR` / `Parse Error`: một lỗi parse làm cả file không nạp, và mọi node dùng file đó mất hết hàm.

---

## 2. Luật thuần chạy headless

Tách luật chơi (di chuyển, chấm điểm, màn chơi, lời giải) ra script không dùng node, rồi viết validator dạng `extends SceneTree`:

```sh
godot --headless --path . --script tools/validate_levels.gd
```

Validator nên: kiểm mọi màn qua được, lời giải mẫu đúng, dữ liệu không trùng id, nội dung ngẫu nhiên đúng ở mọi biến thể; in số liệu (số bước tối thiểu, lời giải BFS) để phát hiện đường tắt ngoài ý muốn. Trả mã thoát khác 0 khi lỗi.

Chế độ `--script` **không** có autoload, nên validator không được đụng tới script dùng autoload.

---

## 3. Test UI qua cảnh chính (`--selftest`)

Test thao tác UI cần autoload (âm thanh, lưu...) và cảnh thật, nên cho script chính nhận cờ debug sau `--` và gọi file test:

```gdscript
# scripts/main.gd
func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if "--selftest" in args:
		# Lỗi script trong coroutine đang được await làm nó dừng luôn và nơi chờ treo mãi: đặt giờ thoát.
		get_tree().create_timer(600.0).timeout.connect(func() -> void: get_tree().quit(2))
		var failures: int = await load("res://tools/editor_test.gd").run(self)
		failures += await load("res://tools/check_touch.gd").run(self)
		get_tree().quit(1 if failures else 0)
		return
```

```sh
godot --path . -- --selftest        # in "ok"/"FAIL" từng mục, mã thoát 0 khi qua hết
```

- File test là `extends RefCounted` với `static func run(app: Node) -> int`, gọi đúng các hàm mà nút bấm gọi, rồi kiểm trạng thái (dữ liệu, node đang mở, dòng đang chọn).
- Ở chế độ test: không ghi save thật, tắt âm thanh, tăng tốc diễn hoạt.
- Mỗi lỗi tìm được trên máy thật phải có một mục test bắt được nó (chạy code cũ thì FAIL).
- Test cảm ứng: `templates/check_touch.gd` và `touch-input.md`.

---

## 4. Chụp màn hình và nhìn ảnh

Cho script chính nhận cờ chụp: dựng đúng trạng thái cần xem, chờ, lưu ảnh, thoát.

```gdscript
if shot_path != "":
	await get_tree().create_timer(wait_seconds).timeout     # chờ theo giây, không theo số frame
	get_viewport().get_texture().get_image().save_png(shot_path)
	get_tree().quit()
```

```sh
godot --path . -- --shot=/tmp/a.png --screen=game --level=3 --wait=1.2
godot --path . --resolution 450x975 -- --shot=/tmp/tall.png     # máy dài 19,5:9
godot --path . --resolution 600x800 -- --shot=/tmp/ipad.png     # iPad 3:4
```

- Chạy **có cửa sổ** (không `--headless`): headless không vẽ gì.
- **Chờ theo thời gian thật.** Máy Mac 120 Hz chạy frame nhanh gấp đôi, nên "chờ 100 frame" chỉ còn 0,8 giây và ảnh chụp sớm (sao chưa bật, thẻ chưa hiện).
- Nên có cờ để dựng từng trạng thái: màn nào, nhân vật nào, nạp lời giải mẫu, chạy xong mới chụp, chụp giữa lúc chạy, mở bảng gợi ý/thẻ...
- Mở ảnh ra nhìn sau mỗi thay đổi giao diện. Nhiều lỗi (màu nhợt, chữ ô vuông, thẻ kẹt ngoài màn hình, khu chơi quá nhỏ) chỉ thấy qua ảnh.

---

## 5. Chạy hết nội dung qua UI thật (`--autoplay`)

Nạp lời giải mẫu của mọi màn × mọi nhân vật vào UI, chạy ở tốc độ cao, kiểm kết quả. Bắt được lỗi giữa luật và phần diễn hoạt (lệnh chạy đúng luật nhưng UI kẹt, tween trên node đã xoá...). Lọc output theo `ERROR|SCRIPT` chứ không chỉ theo "FAIL".

---

## 6. Hiệu năng

Chạy có cửa sổ, đọc `Performance.get_monitor()`:

```gdscript
print("draw calls %d, objects %d, triangles %d" % [
	Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
```

Theo dõi khi thêm đồ trang trí, nhân vật, hiệu ứng. Số trên Mac chỉ là chặn dưới; nhiệt và FPS phải đo trên máy thật.

---

## 7. Trên máy thật

Export và cài bằng lệnh ở `ios-export.md`. Những thứ chỉ máy thật trả lời được: cảm giác vuốt và quán tính, chạm nhầm, vùng an toàn, âm thanh qua loa và công tắc im lặng, nhiệt sau 10–15 phút, thời gian mở app.

Khi báo kết quả cho người dùng, tách rõ: đã kiểm bằng test/ảnh chụp, và những gì còn chờ họ thử trên máy.
