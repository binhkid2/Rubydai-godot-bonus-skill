# Checklist lỗi ngầm cho game Godot 4 (mobile)

"Lỗi ngầm" là lỗi mà editor không báo, game vẫn chạy, nhưng màn hình sai, thao tác không có tác dụng, hoặc chỉ hỏng trên điện thoại. Mỗi mục gồm: triệu chứng, nguyên nhân, cách sửa, và cách bắt được nó trước khi người chơi thấy.

Lỗi cảm ứng (vuốt, bảng tự đóng, chạm nhầm) ở `touch-input.md`. Export và cài lên máy ở `ios-export.md`. Cách test ở `testing.md`.

---

## 0. Script và class

| Triệu chứng | Nguyên nhân và cách sửa |
|---|---|
| `--check-only` báo `Identifier not found: <TênAutoload>` | Bình thường: chế độ này không nạp autoload. Muốn bắt lỗi thật thì chạy cả project: `godot --headless --path . --quit-after 120`. |
| `Could not find type "X"`, `Identifier "X" not declared` ngay sau khi thêm file có `class_name X` | Cache class toàn cục chưa cập nhật. Chạy `godot --headless --path . --import` (hoặc mở editor) một lần. |
| `Cannot infer the type of "x" variable because the value doesn't have a set type` | `:=` với giá trị lấy từ `Dictionary`/`Array`/`Variant` (`var n := d.count`). Khai kiểu rõ: `var n: int = d.count`. Lỗi này làm **cả file** không nạp được. |
| `Cannot call non-static function "name_to_tag()" on the class "TextServer"` | Gọi qua instance: `TextServerManager.get_primary_interface().name_to_tag("wght")`. |
| `Expected expression for match pattern` | `match` nằm trong lambda nhiều dòng truyền làm đối số. Đưa logic ra ngoài (bảng tra `Dictionary`, hoặc hàm riêng). |
| Điều kiện `not x in y` chạy khác ý | Viết rõ `not (x in y)`. |
| Mở project báo lỗi script nhưng chạy vẫn "được" một phần | Script lỗi parse thì node dùng script đó không có hàm nào. Luôn đọc Output, đừng chỉ nhìn màn hình. |

---

## 1. Control dựng bằng code

**1.1 Cả giao diện co vào góc trên trái hoặc rộng 0.**
- Nguyên nhân: gọi `set_anchors_preset(PRESET_FULL_RECT)` khi node *đã ở trong cây*. Hàm này đổi anchor nhưng tính lại offset để **giữ nguyên rect hiện tại** (thường là 0).
- Sửa: dùng `set_anchors_and_offsets_preset()`, rồi mới gán offset riêng. Gán `anchor_*` trực tiếp khi đã ở trong cây cũng gặp lỗi này, nên gán offset sau đó.

**1.2 Thẻ neo đáy co lại bằng bề rộng tối thiểu và kẹt ngoài màn hình.**
- Nguyên nhân: gọi `reset_size()` trên control có anchor. Hàm này đặt size bằng min size và ghi đè offset.
- Sửa: không gọi `reset_size()`. Thẻ mọc từ dưới lên: `anchor_top = anchor_bottom = 1`, `offset_top = offset_bottom = -lề`, `grow_vertical = GROW_DIRECTION_BEGIN`; chiều cao tự theo nội dung.

**1.3 Đo chiều cao ra số khổng lồ (2000+ px) rồi dời layout theo số đó.**
- Nguyên nhân: `Label` có `autowrap` chưa biết bề rộng nên coi mỗi chữ một dòng.
- Sửa: đo sau khi layout xong: `await get_tree().process_frame` hai lần (container lồng nhau), rồi đọc `size`.

**1.4 Hiệu ứng trượt/nảy chạy sai chỗ ngay khi mở.**
- Nguyên nhân: đọc `position`/`size` ngay sau `add_child`, lúc container chưa xếp.
- Sửa: chờ một frame; hoặc animate `modulate` và `scale` (đặt `pivot_offset` sau khi đã có size) thay vì `position` của con trong container.

**1.5 Lỗi `Out of bounds get index` trong `_draw()` sau khi dựng lại danh sách.**
- Nguyên nhân: hàng cũ đã `queue_free()` nhưng còn vẽ thêm một frame, với chỉ số trỏ vào danh sách mới ngắn hơn.
- Sửa: `remove_child(row)` rồi mới `queue_free()`; trong `_draw()` thoát sớm nếu chỉ số vượt danh sách.

**1.6 Chữ hiện ô vuông.**
- Nguyên nhân: font đóng gói không có ký tự đó (emoji, ⏭, ★, ✓...). Font dự phòng của hệ thống có trên máy này mà không có trên máy khác.
- Sửa: kiểm tra `FontFile.has_char(c.unicode_at(0))` cho mọi ký tự đặc biệt; thay bằng icon SVG hoặc chữ. Với tiếng Việt, kiểm cả dấu (ạ, ặ, ữ, đ...).
- Font biến thiên (variable font): dùng `FontVariation` với `variation_opentype = {tag("wght"): 700}` để có nhiều độ đậm từ một file.

**1.7 Màn hình tai thỏ / thanh home che nút.**
- `DisplayServer.get_display_safe_area()` trả về pixel màn hình, cần đổi sang đơn vị canvas: `safe.position.y * canvas_h / screen_h`. Chỉ áp dụng khi `OS.has_feature("mobile")`.

**1.8 Bo góc khung 3D.**
- Đặt `SubViewportContainer` trong `Panel` có StyleBox bo góc và `clip_children = CLIP_CHILDREN_ONLY`.

**1.9 Một ngày nào đó cả bảng rộng ra, tràn khỏi màn hình (nút giá, nút Close bị cắt mất).**
- Nguyên nhân: một `Label` **không** tự xuống dòng hiện chữ thay đổi theo dữ liệu: danh sách ghép ("Out of Coffee Beans, Flour, Matcha, Cocoa and Berries"), tên người chơi tự đặt (món, quán), số lớn. Min size của Label bằng cả dòng chữ; HBox → card → ScrollContainer → panel đều nới theo min size của con, nên **cả panel** rộng ra. Ép `panel.size` mỗi frame cũng vô ích vì Godot không cho nhỏ hơn min size. Với dữ liệu bình thường thì không thấy gì; lỗi chỉ hiện vào hôm dữ liệu dài (hết 5 nguyên liệu cùng lúc), tức là sau khi đã phát hành.
- Sửa: mọi Label có chữ lấy từ dữ liệu, nằm trong hàng ngang, phải xuống dòng (`autowrap_mode = AUTOWRAP_WORD_SMART`, `size_flags_horizontal = EXPAND_FILL`, có `custom_minimum_size.x` để không đo thành mỗi chữ một dòng) hoặc cắt bớt (`clip_text = true` / `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`). Làm một hàm dựng sẵn (ví dụ `UiKit.heading()`) để tiêu đề nào cũng dùng; Label một dòng chỉ dành cho chữ cố định, ngắn.
- Bắt: test "dữ liệu cực đoan" (`testing.md` §2b): đặt tên dài tối đa bằng chữ rộng nhất (`W`), cho hết mọi thứ cùng lúc, mở mọi thành phố/món, số tiền khổng lồ, rồi mở mọi bảng ở mọi cỡ màn hình và kiểm panel nằm trong màn hình, mọi control con nằm trong bề ngang panel. Kiểm thử ngược: tạm bỏ bản sửa, test phải báo lỗi.

**1.10 Chữ vẽ tay (`draw_string`) tràn khỏi thẻ hoặc đè lên chữ khác.**
- Nguyên nhân: HUD tự vẽ bằng `draw_string` không có container nào giới hạn. Chữ bên trái dài ra ("OUT OF MOON MARSHMALLOWS ›") đè lên chữ canh phải ("Clean 100%") trên cùng một thanh; số tiền khổng lồ đè lên dòng thu nhập.
- Sửa: chữ nào lấy từ dữ liệu cũng đi qua một hàm cắt theo bề rộng còn trống (đo `font.get_string_size()`, bỏ bớt ký tự rồi thêm "..."). Bề rộng còn trống = thẻ − lề − chữ cố định bên cạnh (mũi tên, số bên phải).
- Bắt: cho hàm vẽ chữ và vẽ thẻ ghi lại hình chữ nhật khi test bật cờ `static var audit` (bản thật chỉ tốn một phép so sánh `null`). Test vẽ lại HUD với từng nhãn có thể xuất hiện và kiểm: mỗi chữ nằm trong một thẻ, không chữ nào giao với chữ khác. Đo khung chữ theo nét (từ đường chân chữ lên khoảng 0,72 × cỡ chữ), không theo ascent + descent, nếu không hai dòng xếp chồng sẽ bị báo đè nhầm.

---

## 2. Tween, timer, coroutine

**2.1 `Lambda capture at index 0 was freed`, `Invalid assignment ... on a base object of type 'Nil'`.**
- Nguyên nhân: tween tạo trên một node (`create_tween()` của màn hình) nhưng animate node khác đã bị giải phóng (dựng lại màn, đóng thẻ).
- Sửa: tạo tween trên chính node được animate: `gem.create_tween()`. Node mất thì tween mất theo.

**2.2 Vòng lặp diễn hoạt đứng im, log `Unable to start the timer because it's not inside the scene tree`.**
- Nguyên nhân: `Timer.start()` trước khi node vào cây (gọi trong hàm setup trước `add_child`).
- Sửa: bắt đầu vòng lặp trong `_ready()`. Chờ bằng `Timer` con của node (node bị xoá thì coroutine không bao giờ chạy tiếp, không lỗi), thay vì `get_tree().create_timer()` khi node có thể bị xoá giữa chừng.

**2.3 Test hoặc màn chơi treo mãi.**
- Nguyên nhân: lỗi script bên trong một coroutine đang được `await` làm coroutine dừng, nơi chờ nó không bao giờ chạy tiếp. Hoặc `await` một signal mà không nhánh nào emit (ví dụ nút Dừng không emit signal mà vòng chạy đang chờ).
- Sửa: đường dừng nào cũng emit signal đang được chờ; trình chạy test có watchdog: `get_tree().create_timer(600).timeout.connect(func(): get_tree().quit(2))`.

**2.4 Hiệu ứng cũ chạy đè lên trạng thái mới** (nhân vật vẫn nhảy ăn mừng sau khi đã reset).
- Sửa: biến đếm thế hệ: tăng mỗi lần reset, coroutine giữ giá trị lúc bắt đầu và thoát khi khác.

**2.5 Gọi hàm có `await` mà không `await`.** Hàm chạy tới `await` đầu tiên rồi trả về ngay, phần sau chạy ở frame khác. Đọc trạng thái ngay sau lời gọi là đọc trạng thái cũ. Ngược lại, `await` một hàm không dừng lần nào thì trả về ngay trong cùng frame.

---

## 3. 3D và hiển thị trên mobile

**3.1 Màu nhợt, cỏ xám, đất xám.**
- Nguyên nhân 1: màu đỉnh / màu instance (`SurfaceTool.set_color`, `MultiMesh.set_instance_color`) viết theo sRGB nhưng material coi là linear. Sửa: `material.vertex_color_is_srgb = true` (cùng `vertex_color_use_as_albedo = true`).
- Nguyên nhân 2: tonemapper AgX + sương mù + ambient cao làm cảnh màu phẳng bạc đi. Thử Filmic, giảm `fog_density`, `adjustment_saturation` khoảng 1,1–1,2. Luôn chụp màn hình để so, đừng đoán.

**3.2 Log `Basis ... must be normalized` liên tục lúc mới mở.**
- Nguyên nhân: tính camera khi khung 3D còn size 0 (chia cho 0, ra vô cực/NaN).
- Sửa: thoát sớm nếu `size.x <= 1 or size.y <= 1`.

**3.3 Đảo/khu chơi quá nhỏ hoặc bị UI che.**
- Căn camera bằng cách chiếu 8 góc hộp bao (`AABB`) qua camera và tìm nhị phân khoảng cách nhỏ nhất để mọi góc lọt vào phần khung **không bị UI che** (trừ lề trên/dưới), rồi dời camera theo trục dọc của nó để tâm nằm giữa phần còn lại. Hình cầu bao thì quá dè dặt với bản đồ dài.

**3.4 Nhiều khung 3D (màn tiêu đề, thẻ xem trước) hiện đồ của nhau.** Đặt `SubViewport.own_world_3d = true`.

**3.5 Mesh tự dựng mất mặt hoặc sáng ngược.** Godot coi mặt có đỉnh xếp theo **chiều kim đồng hồ** (nhìn từ ngoài) là mặt trước. Đưa normal vào rõ ràng và tự đảo thứ tự đỉnh khi `(b - a).cross(c - a).dot(normal) > 0`.

**3.6 Glow không thấy.** Glow chỉ bắt phần sáng hơn `glow_hdr_threshold`; vật cần phát sáng phải có emission đủ lớn (năng lượng khoảng 1 trở lên).

**3.7 Renderer Mobile:** không có SSAO/SSR/SDFGI (nướng AO vào texture); MSAA 2× trên điện thoại; bóng hướng `SHADOW_ORTHOGONAL` đủ cho cảnh nhỏ; `CPUParticles` an toàn hơn GPU particles trên máy yếu; gộp nền/trang trí bằng `MultiMeshInstance3D` cho ít draw call.

**3.8 Máy nóng.** Màn ProMotion chạy 120 Hz: đặt `application/run/max_fps=60`. Đo draw call và tam giác bằng `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` / `RENDER_TOTAL_PRIMITIVES_IN_FRAME` khi chạy có cửa sổ (headless trả 0).

---

## 4. Asset

**4.1 Thay file GLB mà texture vẫn cũ.** Importer tách texture nhúng ra PNG cạnh GLB và không ghi đè nếu PNG đã có. Xoá các PNG đã tách (giữ `.import`), rồi `godot --headless --path . --import`; so md5 để chắc đã tách lại.

**4.2 Animation từ GLB không lặp.** Đặt `animation.loop_mode` trong code sau khi load (hoặc trong Advanced Import Settings) cho các clip lặp (Idle, Run...).

**4.3 Icon SVG mờ.** SVG nhập ở đúng kích thước `width/height` của file. Vẽ ở gấp đôi kích thước hiển thị, màu trắng, rồi tô bằng `icon_*_color` / `modulate`.

**4.4 Nhạc lặp bị "tách" ở chỗ nối.** `AudioStreamWAV.loop_mode = LOOP_FORWARD`, `loop_end = int(get_length() * mix_rate)` (đơn vị là frame). Khi tự tổng hợp nhạc, gập đuôi nốt cuối về đầu buffer để chỗ nối liền.

**4.5 Test/ảnh chụp phát ra tiếng.** Tắt âm khi `DisplayServer.get_name() == "headless"` hoặc có cờ test.

**4.6 Model nhân vật sửa trong Blender.** Chạy được nền (`blender --background file.blend --python script.py`), EEVEE render được ở chế độ nền. Đánh giá khuôn mặt ở **góc camera của game** (thường nhìn từ trên 25–40°), không chỉ nhìn thẳng: đầu ngoài của mắt và lông mày nằm sâu trong đầu nên nhìn từ trên trông xếch, chi tiết nhô ra (lông mày) sẽ che mắt.

---

## 5. Nền tảng và dữ liệu

- **Nút Back của Android:** `application/config/quit_on_go_back=false` và xử lý `NOTIFICATION_WM_GO_BACK_REQUEST` (màn chơi → danh sách → thoát).
- **Tỉ lệ màn hình:** stretch `canvas_items` + aspect `expand`; thử ở máy dài 19,5:9 và iPad 3:4 bằng `--resolution 450x975` và `--resolution 600x800`.
- **Rung:** `Input.vibrate_handheld(ms)`; Android cần quyền VIBRATE khi export.
- **Định dạng số với giá trị cực đoan:** `int()` của số > 9,2e18, của `INF` hay `NAN` ra `9223372036854775807` / `-9223372036854775808` mà không báo lỗi, nên "1.2Qi" thành "9223372036854775807Qi", "pays back in 9223372036854775807 days", "+nan/s". Hàm định dạng (gọn số, tiền, tốc độ, thời gian) phải chặn `is_nan()`, vô cực và số vượt đơn vị lớn nhất ("999Qi+", "999+ days") trước khi gọi `int()`. Bắt: gọi từng hàm với `0, -0, số âm, 1e21, 1e300, INF, -INF, NAN` và kiểm chuỗi trả về ngắn, không chứa `nan`/`inf`/`922337203`.
- **Chữ hiện ra mà chưa điền:** template `"%d"` / `"%s"` hiện nguyên, hoặc `<null>`. Test nên quét chữ của mọi Label/Button/toast bằng regex `(?i)\b(nan|inf)\b|922337203|%[-+0-9.]*[dsf]\b|<null>`, sau khi bỏ phần tên do người chơi gõ (người chơi có thể gõ "%d").
- **Lưu tiến độ:** `ConfigFile` trong `user://`, khoá theo **id ổn định** (không theo số thứ tự màn, sẽ lệch khi chèn màn mới), có số phiên bản để bỏ save cũ không tương thích. Bỏ các khoá nội bộ (ví dụ `_line`) trước khi lưu.
- **Màn bắt buộc chương trình hoặc nội dung ngẫu nhiên:** tách luật thành code thuần (không dùng node) để chạy được headless; UI chỉ phát lại trace mà luật sinh ra, nên hình ảnh không lệch khỏi luật. Có giới hạn số bước/số lần lặp để chặn vòng lặp vô hạn. Nội dung ngẫu nhiên thì kiểm lời giải trên **mọi** biến thể.
