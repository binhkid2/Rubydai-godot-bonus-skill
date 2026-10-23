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

### 2a. Fuzz logic: người chơi ngẫu nhiên + bất biến

Test thường chỉ đi theo đường người viết nghĩ ra. Fuzz cho một "người chơi" bấm ngẫu nhiên mọi hành động (mua, bán, đổi màn/thành phố, reset, mini-game) theo thứ tự bất kỳ, với tham số xấu (id không tồn tại, số âm, số rất lớn, tên rỗng/dài/emoji/`%d`), cho đồng hồ nhảy rất xa **và lùi lại**, lưu rồi tải lại giữa chừng. Sau **mỗi** bước, kiểm các điều luôn phải đúng:

- tiền, điểm, tốc độ hữu hạn (`is_finite`), không âm, nằm trong khoảng (danh tiếng 0..100, kho ≤ sức chứa, cấp ≤ trần);
- chỉ số đang chọn hợp lệ, không trùng (hai quán cùng một thành phố), menu không rỗng;
- save → JSON → load ra lại y nguyên (so từng khoá, số thực so với dung sai ~1e-12 vì JSON giữ khoảng 15 chữ số; in đường dẫn khoá khác đầu tiên, ví dụ `cafes/2/stock/milk: 25 -> 0`);
- thông báo không chứa số hỏng (regex ở `silent-bugs-checklist.md` §5).

Seed cố định cho từng lượt (`rng.seed = seed`) để lỗi tái hiện được; báo lỗi kèm seed, số bước và hành động vừa làm. Mẫu: `templates/fuzz_logic.gd`. Khoảng 10 seed × 2500 bước là vài phút; nếu dài hơn thì chạy nền.

### 2b. Dữ liệu cực đoan cho UI

Lỗi layout nguy hiểm nhất là lỗi không thấy với save bình thường mà chỉ thấy khi dữ liệu dài: hết mọi nguyên liệu cùng lúc, tên tự đặt dài tối đa, chuỗi đủ 12 thành phố, số tiền 1e18. Viết một tool dựng sẵn vài kịch bản (bình thường, **xấu nhất**: mọi chữ dài nhất, mọi danh sách đầy đủ, mọi thứ hết, số lớn và số âm; **max cấp**: mọi thứ ở cấp cao nhất), rồi ở từng cỡ màn hình (16:9, iPhone dài, iPhone SE, iPad dọc và ngang):

- mở **mọi** bảng/popup/thẻ giải thích (lấy danh sách từ bảng đăng ký trong code, không gõ tay, để bảng mới tự được kiểm), kiểm panel nằm trong màn hình và mọi control con hiện ra nằm trong bề ngang panel;
- vẽ lại HUD với cờ audit (`silent-bugs-checklist.md` §1.10) và với **từng** nhãn trạng thái có thể có (mỗi cảnh báo, mỗi tên nguyên liệu, mỗi sự kiện), kiểm chữ nằm trong thẻ và không đè nhau;
- chơi thử một màn mini-game có chữ lấy từ dữ liệu (món tên dài trong đơn hàng);
- quét chữ mọi Label/Button tìm `nan`, `inf`, `922337203`, `%d` chưa điền.

Viết xong thì **kiểm thử ngược**: tạm đưa lại lỗi vừa sửa và xác nhận test báo đỏ; in vài dòng debug để chắc kịch bản thật sự hiện ra (ví dụ đơn hàng đúng là món tên dài), tránh test xanh mà không kiểm gì. Mẫu: `templates/check_extremes.gd`.

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

## 5. Thử giao diện trên Mac, không dùng iOS Simulator; ảnh App Store

**Không dùng iOS Simulator cho game Godot.** Template iOS chính thức chỉ có thư viện Simulator x86_64, Simulator iOS mới trên Apple Silicon không chạy app x86_64, và plugin native (quảng cáo, mua hàng, thông báo) chỉ có bản máy thật. Tự build engine cho Simulator thì OpenGL ES ở đó chạy trên CPU: game 3D mất vài phút mỗi khung hình. Chủ dự án coi việc đó là làm quá.

Chia việc thử như sau:

| Thử gì | Ở đâu |
|---|---|
| Giao diện, bố cục từng cỡ máy, logic game, luồng UI, ảnh App Store | Mac: nút ▶ của Godot, tool headless, tool chụp ảnh |
| Hiệu năng, nhiệt, FPS, cảm giác chạm và vuốt, âm thanh, plugin native | iPhone/iPad thật (`ios-export.md`) |

**Cửa sổ ▶ hình điện thoại:** đặt `display/window/size/window_width_override` và `window_height_override` theo tỉ lệ iPhone, ví dụ 440×956 (điểm của iPhone 6,9"). Kích thước viewport gốc (ví dụ 720×1280, stretch `canvas_items` + `expand`) giữ nguyên.

**Vùng an toàn trên Mac:** `DisplayServer.get_display_safe_area()` trên Mac là cả màn hình, nên HUD dính sát mép trên. Cho HUD một biến tĩnh mà tool đặt được, ví dụ `static var simulated_safe := Vector2(-1, -1)` là phần trên và dưới, tính theo tỉ lệ chiều cao màn hình. Khi biến này ≥ 0 thì HUD dùng nó thay cho safe area thật.

**Ảnh App Store** (cỡ Apple đòi; ảnh nhỏ hơn App Store tự thu lại):

| Máy | Ảnh dọc | Safe area (điểm) |
|---|---|---|
| iPhone 6,9" | 1320×2868 | trên 62, dưới 34, trên tổng 956 |
| iPad 13" (chỉ khi app hỗ trợ iPad) | 2064×2752 | trên 24, dưới 20, trên tổng 1376 |

- Tool `extends SceneTree`, chạy **có cửa sổ**. Đặt `root.borderless = true` rồi `root.size = Vector2i(1320, 2868)`: cửa sổ có viền bị macOS cắt theo chiều cao màn hình (đo được 1924 thay vì 2868), cửa sổ không viền thì giữ đúng cỡ. Lưu `root.get_texture().get_image()`.
- Cho các tool chụp sẵn có nhận `--device iphone|ipad` (cỡ + safe area) thay vì viết tool mới, và một script shell chạy cả bộ vào `shots/appstore/<máy>/`. Mẫu: `templates/store_shots.gd`.
- **Trạng thái đẹp (`--showcase`)** dựng trên dữ liệu demo:
  - nhiều tiền, đầy kho, sàn sạch, mọi món đã mở có trên menu;
  - quán ở thành phố/màn nào thì ghi đúng tên đó;
  - không có cảnh báo đỏ trên HUD: nếu trạng thái đông khách thật vẫn báo thiếu ghế, cho tool một cờ tắt cảnh báo thay vì sửa luật chơi;
  - quán phụ trong chuỗi cũng phải khoẻ, kẻo hiện chấm đỏ.
- Mở ảnh ra xem trước khi đưa người dùng. Không dùng ảnh có mục chỉ dành cho bản debug.

---

## 6. Chạy hết nội dung qua UI thật (`--autoplay`)

Nạp lời giải mẫu của mọi màn × mọi nhân vật vào UI, chạy ở tốc độ cao, kiểm kết quả. Bắt được lỗi giữa luật và phần diễn hoạt (lệnh chạy đúng luật nhưng UI kẹt, tween trên node đã xoá...). Lọc output theo `ERROR|SCRIPT` chứ không chỉ theo "FAIL".

---

## 7. Hiệu năng

Chạy có cửa sổ, đọc `Performance.get_monitor()`:

```gdscript
print("draw calls %d, objects %d, triangles %d" % [
	Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
```

Theo dõi khi thêm đồ trang trí, nhân vật, hiệu ứng. Số trên Mac chỉ là chặn dưới; nhiệt và FPS phải đo trên máy thật.

---

## 8. Trên máy thật

Export và cài bằng lệnh ở `ios-export.md`. Những thứ chỉ máy thật trả lời được: cảm giác vuốt và quán tính, chạm nhầm, vùng an toàn, âm thanh qua loa và công tắc im lặng, nhiệt sau 10–15 phút, thời gian mở app.

Khi báo kết quả cho người dùng, tách rõ: đã kiểm bằng test/ảnh chụp, và những gì còn chờ họ thử trên máy.
