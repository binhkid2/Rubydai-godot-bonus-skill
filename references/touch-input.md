# Cảm ứng trong Godot 4 trên điện thoại

Chuột trên Mac che gần hết lỗi cảm ứng. Tài liệu này giải thích điện thoại gửi chạm vào Godot thế nào, ba lỗi hay gặp nhất, cách sửa và cách test bằng chạm giả lập.

---

## 1. Điện thoại gửi một cú chạm thế nào

- Ngón tay sinh ra `InputEventScreenTouch` (nhấn/nhả) và `InputEventScreenDrag` (kéo), mỗi ngón có một `index`.
- `input_devices/pointing/emulate_mouse_from_touch` mặc định bật: Godot sinh thêm `InputEventMouseButton` / `InputEventMouseMotion` giả lập. **Click giả lập tới trước, sau đó mới tới chính sự kiện chạm.** Một cú chạm vì thế tới **hai lần**.
- `Button` (mọi `BaseButton`) phản ứng với phần chuột: nhấn rồi nhả chuột trong nút thì phát `pressed`.
- Thứ tự xử lý: `_input()` của mọi node → GUI (`_gui_input` theo control dưới ngón tay) → `_unhandled_input()`. Vì vậy `_input()` thấy cú nhả tay **trước** khi nút phát `pressed`.
- `mouse_filter` (mặc định đo trên Godot 4.7):
  - `STOP`: nhận sự kiện và **không** cho lan lên cha. Mặc định của `Control`, `Button`, `Panel`, **`PanelContainer`**, `ColorRect`, `RichTextLabel`. Thẻ làm bằng `PanelContainer` trong danh sách cũng chặn vuốt.
  - `PASS`: nhận rồi cho lan lên cha. Mặc định của `VBoxContainer`, `HBoxContainer`, `MarginContainer`, `ScrollContainer`, `TextureRect`, `SubViewportContainer`.
  - `IGNORE`: bỏ qua, sự kiện rơi xuống control bên dưới. Mặc định của `Label`.
  - Thứ tự `_input` đo được cho một cú chạm: `MouseButton(nhấn)`, `ScreenTouch(nhấn)`, `MouseButton(nhả)`, `ScreenTouch(nhả)`.
- `ScrollContainer` tự kéo bằng ngón tay chỉ khi `DisplayServer.is_touchscreen_available()`. Trên điện thoại là có; trên desktop chỉ có khi bật `input_devices/pointing/emulate_touch_from_mouse`. Lăn chuột luôn cuộn được, nên "trên Mac cuộn được" không nói lên gì.

---

## 2. Ba lỗi chỉ lộ ra trên máy thật

### 2.1 Danh sách không vuốt được

**Triệu chứng:** danh sách màn, cửa hàng, bảng cài đặt... không vuốt lên xuống được. Thanh cuộn vẫn kéo được, con lăn chuột trên Mac vẫn cuộn.

**Nguyên nhân:** nội dung là nút/thẻ có `mouse_filter = STOP`. Ngón tay đặt trúng nút, nút giữ cú chạm, `ScrollContainer` không bao giờ nhận được thao tác kéo. Chỉ vuốt ở khe hở giữa các nút mới cuộn được.

**Cách sửa A: cho chạm lan lên ScrollContainer** (giữ hành vi gốc của Godot, hợp với nội dung là Button thường):

```gdscript
scroll.scroll_deadzone = 14   # ngón tay đi quá 14 px mới thành cuộn; dưới mức đó vẫn là chạm

func pass_touches_to_scroll(node: Node) -> void:
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		pass_touches_to_scroll(child)

# Node thêm vào sau (dựng lại hàng) cũng phải PASS:
get_tree().node_added.connect(func(n: Node) -> void:
	if content.is_ancestor_of(n): pass_touches_to_scroll(n))
```

Khi ngón tay vượt deadzone, ScrollContainer bảo nút bỏ cú nhấn, nên vuốt không bấm nhầm nút.

**Cách sửa B: ScrollContainer tự xử lý vuốt** (`templates/touch_scroll.gd`). Dùng khi các hàng có cách nhận chạm riêng (dòng code tự vẽ, ô có vùng chạm đặc biệt), khi cần chặn vuốt lúc có lớp phủ (`guard`), hoặc khi muốn chắc chắn không phụ thuộc cách nút xử lý cú chạm. Nó:
- bắt vuốt trong `_input()` nếu cú chạm bắt đầu trong khung của nó, kể cả trúng nút;
- tắt kéo gốc bằng `scroll_deadzone` rất lớn để không cuộn hai lần;
- có quán tính khi thả tay;
- cho con hỏi `dragged()` lúc nhả tay để bỏ qua cú chạm vừa dùng để vuốt.

```gdscript
b.pressed.connect(func() -> void:
	if scroll.dragged():   # nhả tay sau khi vuốt: không mở màn
		return
	open_level(i))
```

### 2.2 Bảng vừa mở đã tự đóng

**Triệu chứng:** chạm nút mở bảng/thẻ, bảng hiện lên rồi biến mất ngay. Trên Mac bằng chuột thì bình thường.

**Nguyên nhân:** nút mở bảng khi nhận *click giả lập* (nửa đầu của cú chạm). Ngay sau đó *sự kiện chạm* (nửa sau) tới và rơi vào nền mờ của bảng vừa mở. Nền mờ nghe "nhả tay" là đóng.

**Cách sửa:** nền mờ chỉ nghe một loại sự kiện (chuột), và chỉ đóng khi chính nó nhận cả nhấn lẫn nhả; bỏ qua chạm trong khoảng 300 ms đầu sau khi mở.

```gdscript
const IGNORE_TAPS_FOR_MS := 300
var opened_at := Time.get_ticks_msec()
var armed := false

func _on_backdrop_input(event: InputEvent) -> void:
	# Chạm tới hai lần (click giả lập rồi tới chạm); nghe click là đủ.
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		armed = Time.get_ticks_msec() - opened_at >= IGNORE_TAPS_FOR_MS
	elif armed:
		armed = false
		close()
```

Quy tắc chung: một thao tác chỉ xử lý qua **một** trong hai đường (chuột *hoặc* chạm), không cả hai, nếu không sẽ chạy hai lần.

### 2.3 Vuốt xong lại "chạm" trúng nút hoặc dòng

**Triệu chứng:** vuốt danh sách rồi nhả tay thì mở luôn màn dưới ngón tay, hoặc chọn nhầm một dòng.

**Nguyên nhân:** cách nhận chạm tự viết so sánh vị trí *cục bộ* lúc nhấn và lúc nhả. Nội dung cuộn theo ngón tay nên vị trí cục bộ gần như không đổi, cú vuốt bị coi là cú chạm. Nút phát `pressed` nếu lúc nhả ngón tay vẫn nằm trong nút, mà nút thì đã trôi theo ngón tay.

**Cách sửa:** hỏi ScrollContainer đã vuốt chưa (`dragged()` của `touch_scroll.gd`); hoặc so vị trí *toàn cục* (`get_global_transform() * event.position`); hoặc dùng cách A ở 2.1 (ScrollContainer bảo nút bỏ cú nhấn).

---

## 3. Cử chỉ khác

- **Xoay camera bằng vuốt, zoom bằng hai ngón:** trong `_gui_input` của `SubViewportContainer`, lưu các ngón theo `index`. Một ngón: `ScreenDrag.relative` đổi góc. Hai ngón: tỉ lệ khoảng cách giữa hai ngón đổi zoom. Thêm `InputEventMagnifyGesture` (trackpad Mac) và con lăn chuột cho desktop. Gọi `accept_event()`.
- **Chạm đúp:** hai lần nhả cách nhau dưới khoảng 0,32 giây và quãng kéo dưới 12 px.
- **Chạm một vật 3D hoặc chỉ vào nó:** `camera.unproject_position(p)` trả về toạ độ trong SubViewport; cộng vị trí toàn cục của `SubViewportContainer` (khi `stretch = true`). Kiểm tra `camera.is_position_behind(p)` trước.
- **Lớp phủ đang mở:** cử chỉ trên khung 3D và vuốt danh sách bên dưới phải bị chặn. Lớp phủ có nền nhận chạm (`STOP`), còn bộ xử lý trong `_input()` thì cần một `guard`.
- **Đa chạm:** chỉ theo dõi đúng `index` đã bắt đầu thao tác, bỏ qua các ngón khác.

---

## 4. Test bằng chạm giả lập

`Input.parse_input_event()` đi qua đúng đường của điện thoại (sinh click giả lập rồi tới chạm), nên bắt được cả ba lỗi ở mục 2. Xem `templates/check_touch.gd`.

- **Toạ độ:** sự kiện đưa vào là toạ độ *cửa sổ*. Rect của control là toạ độ *canvas*. Đổi bằng `get_viewport().get_final_transform() * canvas_point` (khi stretch mode là `canvas_items`). `relative` của ScreenDrag đổi bằng `basis_xform`.
- **ScrollContainer gốc khi chạy headless:** đặt `Input.emulate_touch_from_mouse = true` (hoặc bật trong Project Settings) để nó kéo như trên điện thoại.
- **Chờ theo thời gian thật** (`create_timer`) sau khi chạm mở bảng, vì hiệu ứng mở và khoảng bỏ qua chạm tính bằng mili giây.

Danh sách nên test cho mỗi màn hình có nút và danh sách:

- [ ] Chạm từng nút mở bảng/thẻ: sau 0,5 giây bảng vẫn mở.
- [ ] Chạm nền mờ: bảng đóng. Chạm nút trong bảng: đúng hành động, đúng một lần.
- [ ] Vuốt mỗi danh sách, bắt đầu **trên một nút**: danh sách cuộn (`scroll_vertical` tăng), nút không bị bấm.
- [ ] Sau khi quán tính dừng, chạm một nút trong danh sách đã cuộn: vẫn bấm được.
- [ ] Chạm một hàng/dòng: chọn đúng một lần (không bật rồi tắt vì sự kiện tới hai lần).
- [ ] Kéo khung 3D: camera xoay. Có lớp phủ đang mở thì không xoay.

Những gì test giả lập không thay được, phải thử trên máy: cảm giác cuộn và quán tính, chạm nhầm khi ngón tay to, vùng an toàn (tai thỏ, thanh home), độ trễ.
