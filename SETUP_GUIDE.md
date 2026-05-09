# 📦 SETUP GUIDE — Survivor Quest

## Struktur Folder di Godot Project Kamu
```
res://
├── autoload/
│   └── game_manager.gd          ← AUTOLOAD (wajib didaftarkan)
├── scripts/
│   ├── player.gd
│   ├── enemy_base.gd
│   ├── summon_unit.gd
│   ├── spawner.gd
│   ├── game_world.gd
│   ├── main_menu.gd
│   ├── skill_choice_ui.gd
│   └── hud.gd
├── systems/
│   ├── level_system.gd
│   ├── stat_system.gd
│   ├── skill_system.gd
│   ├── class_system.gd
│   ├── enemy_balance.gd
│   └── damage_system.gd
└── scenes/
	├── MainMenu.tscn
	├── GameWorld.tscn
	├── HUD.tscn
	├── SkillChoiceUI.tscn
	└── characters/
		├── Player.tscn
		├── EnemyBase.tscn
		├── SummonUnit.tscn
		├── Slime.tscn
		├── Goblin.tscn
		├── Skeleton.tscn
		├── DarkKnight.tscn
		└── Boss.tscn
```

---

## ✅ Langkah Setup di Godot

### 1. Daftarkan Autoload
**Project → Project Settings → Autoload**
- Path : `res://autoload/game_manager.gd`
- Name : `GameManager`
- Centang **Enable**

### 2. Daftarkan Input Actions
**Project → Project Settings → Input Map**
Tambahkan:
| Action   | Key |
|----------|-----|
| skill_1  | Q   |
| skill_2  | E   |
| skill_3  | R   |

`ui_left/right/up/down` biasanya sudah ada secara default (Arrow Keys + WASD jika sudah di-set).
Tambahkan WASD manual jika belum:
- `ui_left` → A
- `ui_right` → D
- `ui_up` → W
- `ui_down` → S

### 3. Set Main Scene
**Project → Project Settings → Application → Run → Main Scene**
Set ke: `res://scenes/MainMenu.tscn`

### 4. Tambahkan CollisionShape2D
Buka tiap scene karakter di editor Godot, pilih node **CollisionShape2D**,
lalu di Inspector klik **Shape → New CapsuleShape2D** (atau CircleShape2D untuk Slime).
Sesuaikan ukurannya.

### 5. AnimatedSprite2D (untuk testing)
Jika belum punya sprite, di editor Godot:
- Pilih node `AnimatedSprite2D`
- Inspector → `Sprite Frames` → klik **New SpriteFrames**
- Buat animasi minimal: `idle`, `walk`
- Untuk player Berserker tambah: `attack`, `spin`, `aura`, `ground_smash`
- Untuk player Necromancer tambah: `attack`, `dark_circle`

> **Tip:** Untuk testing cepat tanpa sprite, kamu bisa pakai `Polygon2D` atau `ColorRect`
> sebagai placeholder visual di dalam node player/enemy.

### 6. TileMap (opsional untuk MVP)
TileMap di GameWorld.tscn bisa dikosongkan dulu.
Tambahkan background warna solid aja dengan **ColorRect** di GameWorld.tscn
supaya area bermain kelihatan.

---

## ⚠️ Catatan Penting

- **EnemyBalance signal** `on_enemy_killed` dihubungkan ke `level_system.add_exp()` lewat `game_world.gd` — jangan di-connect dobel.
- **Semua musuh (Slime, Goblin, Skeleton, DarkKnight, Boss)** pakai script `enemy_base.gd` yang sama. Setup stat dilakukan oleh `spawner.gd` via `setup()`.
- **ClassSystem** harus `init_class()` dipanggil **setelah** semua `@onready` siap, artinya dipanggil dari `game_world._ready()`, bukan dari `class_system._ready()` sendiri.
- **SkillChoiceUI** punya `process_mode = 3` (Always) agar tombol tetap aktif saat tree di-pause.
