# Export game Godot lên iPhone / iPad

Đo trên Godot 4.7.2, Xcode 27, macOS Apple Silicon. Các lệnh chạy từ thư mục project.

---

## 1. Cần có

- Xcode, và đã đăng nhập Apple ID trong **Xcode → Settings → Accounts** (tài khoản miễn phí cũng có team cá nhân).
- Export template đúng phiên bản Godot: `~/Library/Application Support/Godot/export_templates/<phiên bản>/ios.zip`. Thiếu thì **Editor → Manage Export Templates → Download**.
- Project Settings: `rendering/textures/vram_compression/import_etc2_astc=true` (iOS dùng ETC2/ASTC).
- Nên có: `application/run/max_fps=60` (màn 120 Hz làm máy nóng), `display/window/handheld/orientation`, icon app (`application/config/icon`).

---

## 2. "No presets found"

Hộp **Project → Export** báo "No presets found" nghĩa là project **chưa có `export_presets.cfg`**, không phải thiếu template.

- Cách 1: **Add… → iOS**, điền **App Store Team ID** và **Bundle Identifier** (ví dụ `com.<tên>.<game>`), Godot tự ghi `export_presets.cfg`.
- Cách 2: copy `export_presets.cfg` từ một project iOS khác đã chạy được, đổi `name`, `export_path`, `application/bundle_identifier`, `application/short_version`/`version`, và bỏ các dòng `plugins/...` của plugin project này không có.
- Nếu file được ghi trong lúc editor đang mở: **Project → Reload Current Project** để editor đọc lại.
- Thêm `/build/` vào `.gitignore`.

**Team ID không phải mã trong ngoặc của tên chứng chỉ.** `Apple Development: Tên (BR9J8U4PJX)` thì `BR9J8U4PJX` là mã của chứng chỉ. Team ID nằm ở trường `OU`:

```sh
security find-identity -v -p codesigning                       # có chứng chỉ "Apple Development" chưa
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject   # ... OU=<TEAM_ID> ...
```

---

## 3. Export và cài lên máy

**Trong editor:** cắm iPhone (đã bật **Settings → Privacy & Security → Developer Mode**), bấm biểu tượng iOS ở góc trên phải để chạy thẳng lên máy (one-click deploy), hoặc **Export Project** ra `.ipa`.

**Dòng lệnh** (để tự kiểm tra trước khi báo người dùng là build được):

```sh
mkdir -p build
godot --headless --path . --export-debug "iOS" build/<Game>.ipa > build/export.log 2>&1
grep -E "ARCHIVE SUCCEEDED|EXPORT SUCCEEDED|error:" build/export.log

xcrun devicectl list devices                                   # lấy UDID, xem trạng thái available/unavailable
xcrun devicectl device install app --device <UDID> build/<Game>.ipa
xcrun devicectl device process launch --device <UDID> --terminate-existing <bundle.id>
xcrun devicectl device info processes --device <UDID> | grep <Game>    # còn chạy sau vài giây = không crash lúc mở
```

Godot gọi `xcodebuild archive -allowProvisioningUpdates`, nên bundle ID mới được Xcode tự tạo provisioning profile (thường là "iOS Team Provisioning Profile: *").

---

## 4. Lỗi hay gặp

| Lỗi | Cách xử lý |
|---|---|
| `The device is not able to fulfill the requested usage assertion requirements` (CoreDeviceError 4016) | Máy đang khoá, đã rút cáp, hoặc khác mạng: `devicectl list devices` báo `unavailable`. Mở khoá, cắm lại, chọn Trust. |
| App cài xong không mở được, báo nhà phát triển chưa tin cậy | Trên máy: **Settings → General → VPN & Device Management**, tin cậy chứng chỉ developer. |
| Không thấy máy trong Godot/Xcode | Bật Developer Mode (cần khởi động lại máy), cắm cáp, Trust máy Mac. |
| Muốn chạy trên iOS Simulator | Template chính thức 4.7.2 chỉ có thư viện Simulator x86_64; Simulator iOS 27 trên Apple Silicon không chạy app x86_64. Dùng máy thật, hoặc tự build template arm64-simulator từ mã nguồn Godot. |
| Export xong nhưng code mới không có trên máy | Export lại rồi cài lại; bản trên máy là bản tại lúc export. |

---

## 5. Thử trên máy thật: danh sách tối thiểu

- [ ] Mở app không crash; màn đầu không bị tai thỏ / Dynamic Island / thanh home che.
- [ ] Mọi danh sách vuốt được, kể cả khi bắt đầu trên nút (`touch-input.md`).
- [ ] Chạm nút mở bảng: bảng không tự đóng; chạm nền mờ thì đóng.
- [ ] Nút đủ to (khoảng 44 pt trở lên); không chạm nhầm khi vuốt.
- [ ] Âm thanh, nhạc, nút tắt tiếng; thử gạt công tắc im lặng.
- [ ] Vuốt về màn hình chính rồi mở lại: tiến độ còn. Tắt hẳn app rồi mở lại: tiến độ còn.
- [ ] Chơi 10–15 phút: máy không nóng bất thường (Xcode → Debug Navigator: CPU, GPU, Energy).
