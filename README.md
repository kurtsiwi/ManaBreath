# ManaBreath

**English** · [Español](README.es.md)

An addon for **World of Warcraft: Forever** that shows when the mana
regeneration **5-second rule** (5SR) is active: a bar fills over the 5 seconds
after you spend mana, and signals when regeneration comes back.

Lightweight and focused on one thing — no potions, gems or runes.

## Installation

1. Copy the addon folder into `Interface\AddOns\` in your Forever client.
   **The folder must be named exactly `ManaBreath`.**
2. Restart the game (or `/reload`) and enable the addon in the addon list.

## Usage

The bar shows up on its own when you spend mana and hides when the rule ends.
To position it:

```
/mb unlock     drag the bar with the left mouse button
/mb lock       pin it in place
```

### Commands

| Command | What it does |
| --- | --- |
| `/mb lock` / `/mb unlock` | Pin or release the bar |
| `/mb test` | 5-second demo |
| `/mb scale <0.5 - 3>` | Bar scale |
| `/mb size <width> <height>` | Bar size |
| `/mb sound on/off` | Sound cue when the rule ends |
| `/mb text on/off` | Text on the bar |
| `/mb always on/off` | Keep the bar always visible |
| `/mb fallback on/off` | Also detect via mana drops |
| `/mb debug on/off` | Print the cost read for every cast |
| `/mb status` | Current state, including restricted context |
| `/mb reset` | Restore defaults |

`/manabreath` works as an alias for `/mb`.

## How it detects mana spending

Forever runs on the **Midnight retail** client, where
`COMBAT_LOG_EVENT_UNFILTERED` is no longer usable by addons. Detection does not
rely on the combat log:

1. **Primary** — `UNIT_SPELLCAST_SUCCEEDED` filtered to `player`; the cost is
   read with `C_Spell.GetSpellPowerCost(spellID)`, the 12.0 replacement for the
   old global `GetSpellPowerCost` (the addon falls back to the global). Static
   spell data in the `C_Spell` namespace is not secret, which makes this the
   reliable path.
2. **Channels** — `UNIT_SPELLCAST_CHANNEL_START` starts the countdown and
   `UNIT_SPELLCAST_CHANNEL_STOP` restarts it, because mana is consumed for as
   long as the channel lasts. Since a channel fires both `SUCCEEDED` and
   `CHANNEL_START` at once, the addon discards the duplicate by comparing
   `castGUID`, which is never secret.
3. **Secret Values** — if the cost arrives protected, the addon waits ~0.35 s
   and confirms the expense only if mana actually drops within that window.
   Every value coming from the game goes through `issecretvalue()` before use.
4. **Optional fallback** (`/mb fallback on`, off by default) — any mana drop in
   `UNIT_POWER_UPDATE` starts the countdown. This produces false positives: an
   enemy burning your mana does not trigger the rule.

Failed or interrupted casts do not fire `UNIT_SPELLCAST_SUCCEEDED`, so they
never start the countdown.

### Secret Values: what it touches and what it doesn't

The **bar never touches protected data**. It is drawn from `GetTime()` and the
5-second constant, both ordinary values, so it needs no `Curve`, `ColorCurve`
or `Duration` to render.

The only part that looks at combat data is **detection**, and only in two
places: the cast's `spellID` and `UnitPower("player", MANA)` for the fallback.
Both are wrapped in `issecretvalue()`; if they arrive protected, the addon does
not guess and does no arithmetic — it stays on the mana-confirmation path.

`/mb status` reports `C_RestrictedActions.IsRestricted()`. That is the first
thing to check if the addon works in the open world but fails inside a dungeon:
it tells you that you are in a context where more values arrive protected.

### About `## Interface: 16001`

The interface version is encoded as `MMmmpp`. Standard Midnight uses `120001`
(= 12.0.1), but Forever reports its own version band: `16001` decodes as
**1.60.1**, matching the client's documented build. That is why `120001` is not
used here even though the engine is Midnight's.

`## AllowLoadGameType:` is deliberately left out. That field restricts loading
to one specific client type (`Mainline`, `Classic`, …) and it is not confirmed
which one Forever reports — with the wrong value the addon would simply fail to
load.

## Efficiency and memory

Measured outside the game with `lua tests/bench.lua`:

| | |
| --- | --- |
| Static footprint (loaded and initialized) | ~47 KB |
| Idle, bar hidden | **0 bytes/frame, no `OnUpdate` installed** |
| Bar visible but idle (`/mb always on`) | **0 bytes/frame, no `OnUpdate` installed** |
| Bar active at 60 fps | ~1 byte/frame |
| One full 5 s cycle | ~0.5 KB |
| `UNIT_POWER_UPDATE` | no measurable garbage |
| Per cast | ~13 bytes |
| Drift after 200 cycles + 400 casts + 2000 `UNIT_POWER_UPDATE` | **-0.04 KB (no leak)** |

Three decisions account for those numbers:

- **`OnUpdate` is only installed while there is something to animate.** It goes
  on when the countdown starts and comes off when the fade ends. Idle, the
  addon runs nothing per frame — not even with the bar visible.
- **The counter builds no strings.** The window is fixed (0.0-5.0), so all 51
  possible strings are precomputed at load. One `string.format` per frame would
  generate garbage 60 times a second.
- **Text and spark only update when they change.** At 60 fps the counter
  changes 10 times a second and the spark moves one pixel every few frames; the
  remaining `SetText` and `SetPoint` calls would be invisible work.

The one unavoidable allocation is `C_Spell.GetSpellPowerCost`, which returns a
fresh table on every call. That is ~13 bytes per cast and is **deliberately not
cached**: a Clearcasting-style aura can make a spell free, and a cached cost
would start the rule on a cast that spent no mana.

## To verify in game (pending until launch)

- [ ] `/dump select(4, GetBuildInfo())` — confirm the interface is `16001`.
- [ ] Confirm the `.toc` suffix Forever uses. The repo ships both
      `ManaBreath.toc` and `ManaBreath_Camelot.toc`: the client loads the
      flavor-specific one if it exists and falls back to the generic one. If
      the real suffix is different, rename the copy.
- [ ] Confirm that the `spellID` from the player's own
      `UNIT_SPELLCAST_SUCCEEDED` does not arrive as a Secret Value in combat
      (`/mb debug on` prints `yes` / `no` / `unknown` for every cast).
- [ ] Confirm Forever keeps the 5-second rule the same as vanilla.
- [ ] Confirm the client's final addon path (during beta it was
      `_classic_beta_\Interface\AddOns\`).

## Development

The tests run outside the game, against a fake WoW API:

```
lua tests/run.lua
```

They cover starting and restarting the countdown, channels, `castGUID`
deduplication, Secret Values, restricted context (with and without
`C_RestrictedActions`), classes and forms without mana, and every command. The
mock makes touching a secret value raise an error, just like WoW, so a missing
`issecretvalue()` guard shows up as a failure instead of slipping through.

The memory benchmark is separate:

```
lua tests/bench.lua
```

## License

MIT — see [LICENSE](LICENSE).
