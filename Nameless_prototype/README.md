# Nameless (Roblox)

Game sinh tồn đọc mã: mỗi người đeo một mã 5 số trên ngực, đọc được mã của ai thì ghi vào sổ để loại người đó. Người cuối cùng sống sót sẽ thắng.

Thư mục này chứa **toàn bộ code** (18 script), sắp xếp theo cấu trúc **Rojo**.

## Cấu trúc

```
default.project.json        Cấu hình Rojo (kèm 7 Remote)
src/
  ServerScriptService/Nameless/
    Main.server.lua         Vòng lặp trận đấu, cổng vào chơi
    CodeStore.lua           Lưu mã bí mật (chỉ trên server)
    Systems/
      Audio.lua  Identity.lua  Vision.lua  Notebook.lua
      Combat.lua Zone.lua      Lifecycle.lua StudioBots.lua
  ReplicatedStorage/Nameless/
    Config.lua              Mọi thông số chỉnh được của game
  StarterPlayerScripts/     7 script phía người chơi
place/                      Bỏ file Nameless.rbxlx (bản đồ) vào đây
```

Quy ước tên file: `.server.lua` là Script, `.client.lua` là LocalScript, còn `.lua` là ModuleScript.

## Rojo KHÔNG quản lý những thứ này

Các phần sau vẫn nằm trong file place của Roblox, nên hãy xuất `Nameless.rbxlx` bỏ vào thư mục `place/`:

- `Workspace.Map`: bản đồ, phòng chờ, cổng, công viên.
- `ServerStorage.Nameless.Notebook`: cuốn sổ (Tool).
- `SoundService.NamelessSounds`: âm thanh.
- Lighting, cùng các cài đặt StarterPlayer và TextChatService.

## Cách dùng

1. **Sao lưu trước:** trong Studio chọn File → Save to File As… và lưu thành `.rbxlx`.
2. Mở thư mục này trong VS Code, rồi chạy `default.project.json` từ menu Rojo.
3. Trong Studio, vào Plugins → Rojo → Connect.

⚠️ Rojo sẽ ghi đè những thư mục nó quản lý (ServerScriptService.Nameless, ReplicatedStorage.Nameless, StarterPlayerScripts) cho giống hệt thư mục này. Hãy thử trên một bản sao của place trước.

## Ghi chú

- `StudioBots` và `NamelessDevHarness` chỉ chạy trong Studio, server thật sẽ tự bỏ qua.
- Muốn chống người hack đọc trộm mã, đặt `Config.AlwaysShowPlates = false`.
