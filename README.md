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
| `/mb channel on/off` | Restart the countdown when a channel is cut |
| `/mb verify` | Measure against the client whether the 5 s rule really exists |
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
3. **Conditional costs** — a cost entry carrying `hasRequiredAura` only applies
   while a given aura is up, so it does not count as a certain cost and is
   confirmed against mana instead. Without this, a spell an aura made free
   would start the rule even though nothing was spent.
4. **Secret Values** — if the cost arrives protected, the addon confirms the
   expense only if mana drops within ~0.35 s. The window is **symmetric**: the
   order in which the client delivers `UNIT_POWER_UPDATE` and
   `UNIT_SPELLCAST_SUCCEEDED` is not guaranteed, so it holds whether the
   deduction arrives before or after the cast. Every value coming from the game
   goes through `issecretvalue()` before use.
5. **Optional fallback** (`/mb fallback on`, off by default) — any mana drop in
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

### What is deterministic and what isn't

The WoW API **does not report the state of the 5-second rule**. There is no
event, flag or query: it is a server-side mechanic the client is never told
about. The closest thing is `GetPowerRegen()`, which returns your two
regeneration rates but not which one is in effect or when the window started.
Every 5SR addon ever written reconstructs the rule by inference.

What the API **does** give deterministically are three facts: that you
completed a cast, what that spell costs, and that your mana changed and by how
much. What it does not give is **attribution**: why mana dropped. Combining
cast + cost resolves attribution for the normal case, and that is not guesswork.

On that basis the addon is deterministic in its own right: same event sequence
→ same state, no randomness, frame-rate independent (the bar uses `GetTime()`
deltas, it does not count frames) and free of accumulated drift. And it fails
closed: an unreadable cost never produces a false bar.

What stays outside our control:

- **Latency.** The window starts when the client receives the server's
  confirmation, not when the server charged the mana. A limit of any addon.
- **The 5.0 is hardcoded** and is an assumption about Forever. `/mb verify`
  exists to check it.
- **Restarting on channel stop is an inference** from vanilla mechanics, not a
  verified fact. If it turns out wrong, `/mb channel off`.
- **Enemy mana drains** inside the confirmation window can cause a false
  positive. Bounded to ~0.35 s, or unbounded if you enable `/mb fallback on`.

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
| Static footprint (loaded and initialized) | ~56 KB |
| Idle, bar hidden | **0 bytes/frame, no `OnUpdate` installed** |
| Bar visible but idle (`/mb always on`) | **0 bytes/frame, no `OnUpdate` installed** |
| Bar active at 60 fps | ~1 byte/frame |
| One full 5 s cycle | ~0.18 KB |
| `UNIT_POWER_UPDATE` | no measurable garbage |
| Per cast | 3-12 bytes |
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

Of those ~56 KB, about 8 KB is `Verify.lua`, which is only used once to check
the rule in game. That is a conscious call: it costs resident memory in return
for being able to measure instead of assume.

The one unavoidable allocation is `C_Spell.GetSpellPowerCost`, which returns a
fresh table on every call. That is a few bytes per cast and is **deliberately
not cached**: a Clearcasting-style aura can make a spell free, and a cached cost
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
- [ ] Confirm Forever keeps the 5-second rule the same as vanilla, using
      `/mb verify`: arm it, cast one mana-spending spell and do nothing else.
      It samples mana inside and outside the window and compares against
      `GetPowerRegen()`. Do it out of combat, outside an instance and with mana
      below maximum, or there is no regeneration to measure.
- [ ] Confirm whether a channel charges mana per tick or all at the start. If
      it is all at the start, `/mb channel off`.
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
