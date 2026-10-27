# ManaBreath

**English** · [Español](README.es.md)

An addon for **World of Warcraft: Forever** that shows when the mana
regeneration **5-second rule** (5SR) is active: an animated flask fills over
the 5 seconds after you spend mana, counts down inside the bulb, and then stays
lit tracking the mana coming back in, tick by tick, until it is full or you
leave combat.

Lightweight and focused on one thing — no potions, gems or runes.

## Installation

1. Copy the addon folder into `Interface\AddOns\` in your Forever client.
   **The folder must be named exactly `ManaBreath`.**
2. Restart the game (or `/reload`) and enable the addon in the addon list.

## Usage

The flask shows up on its own when you spend mana and hides once there is
nothing left to count. To position it:

```
/mb unlock     drag the flask with the left mouse button
/mb lock       pin it in place
```

### What the flask shows

The flask goes through two phases, and the colour tells them apart.

**Blue — the rule is running.** Your mana is not regenerating.

| | |
| --- | --- |
| Liquid level | How much of the 5 seconds has elapsed — full means the rule is over |
| Number in the bulb | Seconds left, to one decimal |
| Waves and bubbles | The rule is running |

**Green — you are regenerating.** It starts the moment the rule ends.

| | |
| --- | --- |
| Liquid level | Your real mana, 0 to 100% |
| Number in the bulb | Mana percentage |
| Liquid flash | A regeneration tick just landed |
| **Glow around the flask** | You are regenerating mana |

The green phase ends in four ways: mana fills up, you leave combat, you spend
mana again (which starts the blue rule over) or 4 seconds pass without a single
tick. That last one is a safety net: if this client does not report every mana
tick, the flask goes out instead of staying lit forever. With `/mb regen off`
the flask goes out as soon as the rule ends.

The glow lights exactly one phase, whichever you pick — lighting both would say
nothing. By default (`/mb glow regen`) it lights the green one, the only phase
where you are actually getting mana back; `/mb glow rule` moves it to the
5 seconds of the rule, and `/mb glow off` turns it off.

### Commands

| Command | What it does |
| --- | --- |
| `/mb lock` / `/mb unlock` | Pin or release the flask |
| `/mb test` | 5-second demo |
| `/mb scale <0.5 - 3>` | Flask scale — the right way to resize it |
| `/mb size <width> <height>` | Frame size; the art assumes a square frame |
| `/mb sound on/off` | Sound cue when the rule ends |
| `/mb glow regen/rule/off` | When the flask glows |
| `/mb regen on/off` | Track the mana coming back after the rule |
| `/mb text on/off` | Countdown inside the bulb |
| `/mb always on/off` | Keep the flask always visible |
| `/mb fallback on/off` | Also detect via mana drops |
| `/mb channel on/off` | Restart the countdown when a channel is cut |
| `/mb verify` | Measure against the client whether the 5 s rule really exists |
| `/mb debug on/off` | Print the cost read for every cast |
| `/mb status` | Current state, restricted context and where costs are read from |
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
3. **Conditional costs** — an entry carrying `hasRequiredAura` only applies
   while a given aura is up (usually a spec or shapeshift form aura), so it
   does not count as a certain cost and is confirmed against mana instead. And
   if the API returns `nil` or an empty table, the spell costs no resources:
   that is a "no", not an "unreadable".
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

The **flask never touches protected data**. It is drawn from `GetTime()` and
the 5-second constant, both ordinary values, so it needs no `Curve`,
`ColorCurve` or `Duration` to render.

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
→ same state, no randomness, frame-rate independent (the flask uses `GetTime()`
deltas, it does not count frames) and free of accumulated drift. And it fails
closed: an unreadable cost never produces a false countdown.

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

Measured outside the game with `lua tests/bench.lua`, **with the collector
stopped for each measurement**. That matters: with the collector running, what
you read is not what the addon allocates but what it failed to free in time,
which shifts with the size of the heap. The bench measured that way up to
1.1.0, which is why it reported 3-12 bytes per cast when the real figure is 320.

| | |
| --- | --- |
| Static footprint (loaded and initialized) | ~82 KB |
| Idle, flask hidden | **0 bytes/frame, no `OnUpdate` installed** |
| Flask visible but idle (`/mb always on`) | **0 bytes/frame, no `OnUpdate` installed** |
| 600 frames of the blue phase | **0 bytes** |
| 600 frames of the green phase | **0 bytes/frame** · ~24 bytes per percentage change |
| `UNIT_POWER_UPDATE` | **0 bytes** |
| Per cast | ~320 bytes, all of it the table `C_Spell.GetSpellPowerCost` returns |
| One full 5 s cycle | ~370 bytes, the cast included |
| API calls per frame while animating | ~5 |
| Drift after 200 cycles + 400 casts + 2000 `UNIT_POWER_UPDATE` | **-0.04 KB (no leak)** |

Four decisions account for those numbers:

- **`OnUpdate` is only installed while there is something to animate.** It goes
  on when the countdown starts and comes off when the fade ends. Idle, the
  addon runs nothing per frame — not even with the flask visible.
- **The animation runs at 30 Hz, not per frame.** At 58 px the liquid is 36 px
  tall and the fastest bubble crosses it in 2 seconds: 0.6 px per 30 Hz step.
  Asking for 60 Hz meant paying twice the API calls to move half a pixel. The
  liquid level and the counter do run per frame, since those are what you look
  at closely. It is `ANIM_STEP` in `Display.lua`.
- **The counter builds no strings.** The window is fixed (0.0-5.0), so all 51
  possible strings are precomputed at load; the counter changes ten times a
  second. The green phase percentage is **not** precomputed: it changes a few
  times a second, and Lua reuses short strings, so formatting it on the spot is
  free in steady state and saves ~4 KB resident. Precomputing it was paying
  permanent memory for nothing.
- **The animation allocates nothing.** The bubbles are a fixed table — no
  `math.random` per frame — the waves scroll with `SetTexCoord`, and the wave
  strips hang off the top edge of the liquid, so raising the level moves them
  without a single `SetPoint`. The counter only redraws when the tenth changes,
  and the percentage only when the integer does. The per-tick flash colour is
  computed into a table that gets reused.

Of those ~82 KB, about 8 KB is `Verify.lua`, which is only used once to check
the rule in game. That is a conscious call: it costs resident memory in return
for being able to measure instead of assume.

The one unavoidable allocation is `C_Spell.GetSpellPowerCost`, which returns a
fresh table on every call. That is ~320 bytes per cast and is **deliberately
not cached**: the API reflects resource discounts applied by auras, so the value
changes over time. A Clearcasting-style aura makes the spell free and the API
reports it; a cached cost would start the rule on a cast that spent no mana.

## The artwork

The flask is generated, not drawn by hand:

```
python tools/make_art.py
```

That script writes the seven TGAs in `Art/` from signed distance fields — glass,
interior mask, liquid, wave band, bubble, glow and the addon-list icon — plus
`tools/preview.png` to look at them outside the game. It needs no third-party
library. `tools/` is not packaged.

The liquid, the waves and the bubbles are all clipped by a `MaskTexture` shaped
like the inside of the glass, so nothing spills outside the flask no matter how
the frame is resized. If a client does not expose `CreateMaskTexture`, the addon
degrades instead of breaking: the liquid is narrowed to fit inside the bulb.

The geometry constants live in two places — `tools/make_art.py` and the
`FILL_*` / `GLOW_SCALE` constants in `Display.lua`. Moving the drawing means
moving both.

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
- [ ] Confirm the TGAs load. If the flask shows up as a green-and-black
      checkerboard, the client rejected the texture format; if it is invisible,
      check that the folder is named exactly `ManaBreath`, since the art path
      is built from the addon name.
- [ ] Confirm the `MaskTexture` clips the liquid. If the liquid shows up as a
      rectangle sticking out of the glass, the mask did not load.
- [ ] Confirm the green phase really tracks mana: that the percentage climbs
      with every tick, that the flask goes out when mana fills up, and that
      `PLAYER_REGEN_ENABLED` ends it when you leave combat. If the client does
      not fire `UNIT_POWER_UPDATE` per tick, the phase will close itself after
      4 seconds — raise `REGEN_TIMEOUT` in `Display.lua` if so.

## Development

The repo ships a `.luarc.json` declaring the WoW API globals and pinning the
runtime to Lua 5.1. Without it the language server flags all 44 API references
as undefined and warns about `unpack` being deprecated — noise that buries any
real warning. It is not packaged.


The tests run outside the game, against a fake WoW API:

```
lua tests/run.lua
```

They cover starting and restarting the countdown, channels, `castGUID`
deduplication, Secret Values, restricted context (with and without
`C_RestrictedActions`), classes and forms without mana, and every command. The
mock makes touching a secret value raise an error, just like WoW, so a missing
`issecretvalue()` guard shows up as a failure instead of slipping through.

The memory benchmark is separate, and measures with the collector stopped:

```
lua tests/bench.lua
```

And the profiler counts API calls per frame in each phase, which is the other
half of the question: an animation can allocate not one byte and still be
calling into the client forty times a frame.

```
lua tests/profile.lua
```

## License

MIT — see [LICENSE](LICENSE).
