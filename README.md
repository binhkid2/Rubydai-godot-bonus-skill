# binh-godot-bonus-skill

Skill cho [Claude Code](https://claude.com/claude-code), dùng cho mọi game Godot 4 chạy trên điện thoại. Skill gom lại các bài học kiểu "chạy trong editor được nhưng lên máy thật thì hỏng". Claude sẽ tự áp dụng chúng khi làm việc trong project Godot, không cần bạn nhắc.

## Nội dung

| File | Nội dung |
|---|---|
| `SKILL.md` | Phần Claude đọc: khi nào dùng skill, các quy tắc luôn áp dụng, khi nào mở file tham khảo nào |
| `references/touch-input.md` | Điện thoại gửi chạm vào Godot thế nào (click giả lập rồi mới tới chạm, `mouse_filter` mặc định của từng loại control). Ba lỗi chỉ thấy trên máy thật: danh sách không vuốt được, bảng vừa mở đã tự đóng, vuốt xong bấm nhầm. Cách sửa, cử chỉ xoay/zoom/chạm đúp, cách test bằng chạm giả lập |
| `references/silent-bugs-checklist.md` | Lỗi ngầm của Godot 4: script/class, dựng Control bằng code (anchor/offset, `reset_size`, label tự xuống dòng), tween/timer/coroutine (node đã xoá, `await` treo), 3D trên mobile (màu sRGB, tonemap, camera, glow, nhiệt), asset (GLB, SVG, WAV), nền tảng và lưu dữ liệu |
| `references/ios-export.md` | Export lên iPhone/iPad: "No presets found", tìm đúng Team ID, export và cài/mở app bằng dòng lệnh (`devicectl`), các lỗi hay gặp, danh sách thử trên máy |
| `references/testing.md` | Thứ tự kiểm tra: script nạp được, validator headless, `--selftest` qua cảnh chính, chụp và xem ảnh màn hình, chạy hết nội dung qua UI, đo hiệu năng, thử trên máy |
| `templates/touch_scroll.gd` | ScrollContainer vuốt được cả khi chạm trúng nút, có quán tính, không bấm nhầm sau khi vuốt |
| `templates/check_touch.gd` | Bộ hàm chạm/vuốt giả lập (`tap`, `drag`, đổi toạ độ canvas sang cửa sổ) kèm ví dụ test |

Các file trong `references/` viết bằng tiếng Việt và đọc được độc lập, không cần Claude. Thông tin đo trên Godot 4.7.2, Xcode 27, macOS Apple Silicon.

## Cài đặt trên máy mới

Skill cấp user nằm ở `~/.claude/skills/<tên-skill>/` và áp dụng cho mọi project.

**Cách 1: clone thẳng vào thư mục skills** (đơn giản nhất)

```sh
mkdir -p ~/.claude/skills
git clone <url-repo> ~/.claude/skills/binh-godot-bonus-skill
```

Cập nhật về sau: `git -C ~/.claude/skills/binh-godot-bonus-skill pull`.

**Cách 2: clone vào chỗ khác rồi tạo symlink** (nếu muốn sửa skill ngay trong thư mục project của mình)

```sh
git clone <url-repo> "<thư-mục-của-bạn>/binh-godot-bonus-skill"
mkdir -p ~/.claude/skills
ln -s "<thư-mục-của-bạn>/binh-godot-bonus-skill" ~/.claude/skills/binh-godot-bonus-skill
```

Mở một phiên Claude Code mới, gõ `/` và kiểm tra có `binh-godot-bonus-skill` trong danh sách skill.

### Muốn Claude luôn dùng skill trong project Godot

Claude tự dùng skill khi việc đang làm khớp với phần `description` trong `SKILL.md`, nhưng không chắc lần nào cũng dùng. Muốn chắc chắn thì thêm dòng này vào `~/.claude/CLAUDE.md`:

```md
- Trong mọi project Godot (có file project.godot), luôn dùng skill `binh-godot-bonus-skill`.
```

## Đưa lên GitHub

```sh
cd "<thư-mục>/binh-godot-bonus-skill"
git init
git add .
git commit -m "init"
git branch -M main
git remote add origin git@github.com:<tài-khoản>/binh-godot-bonus-skill.git
git push -u origin main
```

## Cập nhật nội dung

- Sửa trực tiếp các file trong repo này, rồi commit và push.
- Mỗi khi gặp một lỗi chỉ thấy trên máy thật: ghi triệu chứng, nguyên nhân, cách sửa và test bắt được nó vào file tham khảo tương ứng.
- Giữ nội dung **chung chung**: không đưa tên class, đường dẫn hay tính năng riêng của một game vào đây.
- Phần `description` trong `SKILL.md` quyết định khi nào Claude dùng skill. Giữ dưới 1024 ký tự và liệt kê rõ các tình huống cần dùng.
