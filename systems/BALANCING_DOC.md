# 📋 BALANCING DOCUMENTATION
## Game: Vampire Survivor Style (Manual Attack)
### Tugas: Sistem Balancing & Progression

---

## 🗂️ Struktur File

```
systems/
├── level_system.gd      ← EXP, level up, trigger boss
├── stat_system.gd       ← Auto stat growth per level
├── skill_system.gd      ← Unlock & pilih skill
├── class_system.gd      ← Koordinator utama
├── enemy_balance.gd     ← Scaling musuh & spawn
└── damage_system.gd     ← Kalkulasi damage & lifesteal
```

---

## 🧪 EXP TABLE (Target 15-20 menit)

| Level | EXP Dibutuhkan | Total EXP Kumulatif |
|-------|----------------|----------------------|
| 1→2   | 120            | 120                  |
| 2→3   | 150            | 270                  |
| 3→4   | 180            | 450                  |
| 4→5   | 220            | 670                  |
| 5→6   | 260            | 930                  |
| 6→7   | 300            | 1.230                |
| 7→8   | 340            | 1.570                |
| 8→9   | 380            | 1.950                |
| 9→10  | 420            | 2.370                |
| 10→11 | 460            | 2.830                |
| 11→12 | 500            | 3.330                |
| 12→13 | 540            | 3.870                |
| 13→14 | 580            | 4.450                |
| 14→15 | 620            | 5.070                |

**Total EXP untuk Level 15 = ~5.070**

---

## ⚔️ Berserker — Stat Progression

| Level | HP  | Damage | Crit  | Defense |
|-------|-----|--------|-------|---------|
| 1     | 220 | 25     | 5%    | 8       |
| 5     | 300 | 41     | 7%    | 12      |
| 10    | 400 | 61     | 9.5%  | 17      |
| 15    | 500 | 81     | 12%   | 22      |

### Skill Berserker
| Level | Skill             | CD  | Efek                                     |
|-------|-------------------|-----|------------------------------------------|
| 1     | Whirlwind Slash   | 5s  | AOE radius 100, DMG ×1.2                 |
| 5     | Blood Aura        | 18s | ATK +35%, Lifesteal 20%, durasi 6 detik  |
| 10    | Ground Smash      | 12s | AOE radius 130, DMG ×2.8, Stun 1.5 detik|

> **Anti-abuse:** Lifesteal hard-cap 25%. Blood Aura tidak bisa di-stack.

---

## 🧟 Necromancer — Stat Progression

| Level | HP  | Damage | Summon Limit | Summon DMG% |
|-------|-----|--------|--------------|-------------|
| 1     | 160 | 18     | 2            | 100%        |
| 5     | 208 | 30     | 2            | 108%        |
| 10    | 268 | 45     | 2            | 118%        |
| 15    | 328 | 60     | 2            | 128%        |

### Skill Necromancer
| Level | Skill              | CD  | Efek                                         |
|-------|--------------------|-----|----------------------------------------------|
| 1     | Soul Mark          | 3s  | Tandai musuh; jika mati → jadi summon        |
| 1*    | Undead Ritual (P)  | 30s | Auto summon skeleton berkala (pasif)         |
| 5     | Dark Empowerment   | 20s | Summon DMG & HP +40% selama 8 detik          |
| 10    | Dark Circle        | 8s  | AOE lingkaran radius 90, DMG ×1.6            |

> **Anti-abuse:** Summon limit hard-cap 6. Passive hanya spawn bila slot masih ada.

---

## 👹 Enemy Scaling

### Slime (early game)
| Player Lv | HP    | Damage | EXP |
|-----------|-------|--------|-----|
| 1         | 30    | 4      | 22  |
| 4         | 39    | 5      | 22  |

### Goblin (mid game)
| Player Lv | HP    | Damage | EXP |
|-----------|-------|--------|-----|
| 5         | 60    | 8      | 36  |
| 7         | 68    | 9      | 36  |

### Dark Knight (late game)
| Player Lv | HP    | Damage | EXP |
|-----------|-------|--------|-----|
| 10        | 225   | 23     | 80  |
| 14        | 333   | 34     | 80  |

### Boss (level 15)
| Stat     | Nilai              |
|----------|--------------------|
| HP       | 2.400              |
| Damage   | 38 per hit         |
| Target   | Mati dalam 2-4 menit |

---

## ⏱️ Target Pacing

| Menit | Level Target | Fase         |
|-------|--------------|--------------|
| 0–3   | 1–4          | Early game   |
| 3–7   | 5            | Skill ke-2   |
| 7–12  | 10           | Skill ke-3   |
| 12–15 | 13–14        | Late game    |
| 15+   | 15           | Boss muncul  |

---

## 🔗 Cara Integrasi (Singkat)

```gdscript
# Di scene utama / GameManager.gd

func _ready():
    # 1. Pilih class
    class_system.init_class(CharacterClass.BERSERKER)

    # 2. Sambungkan sinyal level_system ke enemy_balance
    level_system.on_level_up.connect(_on_level_changed)

    # 3. Sambungkan sinyal skill_system ke UI
    skill_system.on_skill_choices_ready.connect(show_skill_choice_ui)

    # 4. Sambungkan boss trigger
    level_system.on_boss_trigger.connect(spawn_boss)

func _on_level_changed(new_level):
    # Update spawn rate & enemy table otomatis melalui enemy_balance
    spawner.update_level(new_level)
```

---

## ⚠️ Catatan Balancing Penting

1. **Berserker lifesteal** – Jangan naikkan melebihi 25%, karena dengan HP 500 dan lifesteal 20%, heal per hit bisa mencapai ~16HP yang sudah cukup sustain.
2. **Necromancer summon** – Jika summon_limit terlalu tinggi, player bisa farming passif. Cap di 6 sudah cukup aman.
3. **Boss** – HP 2400 dirancang untuk Berserker level 15 (~80 base damage, ~30 hit dalam 3 menit dengan cooldown skill). Untuk Necromancer yang punya summon, bisa lebih cepat.
4. **EXP terlalu cepat/lambat** – Jika game terasa terlalu cepat, naikkan EXP_TABLE nilai tiap level sebesar 10-15%. Sebaliknya jika terlalu lambat, turunkan.
