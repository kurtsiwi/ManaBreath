# Changelog

## 1.3.0

### A third look

- **Bar mode.** `/mb style bar` swaps the flask for a horizontal bar that fills
  over the 5 seconds, with a spark riding its leading edge, the figure centred
  on it, and underneath the label on the left and the **mana per second** on
  the right. It is the minimalist one: no silhouette, no glass, just the line
  and the figures.
- It is a skin like the other two, on the **same engine**: the same states, the
  same timings, the same detection, and the same water drop when the rule is
  fulfilled. Only the drawing differs.
- **Mana per second** is new, and it is the engine's, not the bar's: it is
  measured in all three skins and the bar is simply the only one with room to
  print it. It is measured from the **first tick** of the green phase, not from
  the start of the phase: between the end of the rule and the first tick there
  can be any fraction of an interval, and dividing by it would print a wild
  figure at the very moment you are looking. The price is that the first figure
  arrives with the second tick. The average is cumulative, so it sharpens by
  itself, and it is cleared when a new rule starts — while the rule runs no
  mana is coming in, so leaving the last figure there would be a lie.
- No glow and no bubbles, for the reason text mode has none: the glow is the
  flask's silhouette and the bubbles rise inside the glass. But `/mb text off`
  **does** work here, unlike in text mode — the bar goes on counting without
  the figure, whereas the text block would be left empty.
- The width is yours through `/mb size`, but never less than about three times
  the height: below that it stops reading as a bar and starts reading as a
  square, and the default 58x58 frame was drawn for a flask.
- **~2 API calls per frame**, between the flask's ~5 and text mode's ~1. The
  spark hangs off the right edge of the fill, the way the wave strips hang off
  the surface of the liquid, so the only thing that moves per frame is the
  width of the fill — the spark is dragged along for free.
- Two new generated textures, `BarFill.tga` and `BarSpark.tga`, from the same
  `tools/make_art.py` as the flask. The empty track and the outline are flat
  colours set from Lua: two rectangles do not need art.

### Fixed

- Switching skin mid-cycle left pieces of the new one unpainted. The phase
  colour is carried by a different widget in each skin (the liquid, the figure,
  the bar) and the label is only written when it changes, so coming back to the
  flask from text mode mid-regeneration could leave a green counter over a blue
  flask, or an empty label. Changing skin now repaints the phase it is in.

## 1.2.0

### A second look

- **Text mode.** `/mb style text` swaps the flask for a sober, letters-only
  readout: the figure, and a small spaced label underneath (`5 S R` while the
  rule runs, `M A N A` while mana comes back). `/mb style flask` returns to the
  flask. It is also the first entry in the options panel.
- It is a **skin, not a second display**: both run the same engine, with the
  same states, the same timings and the same detection. Only the drawing
  differs, so a fix to the rule lands in both. The per-tick flash exists in
  both: on the flask it is carried by the liquid, in text mode by the figure.
- Text mode has no glow and no bubbles. The glow is the flask's silhouette and
  the bubbles rise inside the glass, so with no flask there is nothing to
  surround and nothing to rise through. `/mb text off` does nothing either,
  because the figure is the only thing on screen. The command says so when you
  switch, instead of leaving three controls that look broken.
- Turning those three off is also what leaves text mode with **nothing to
  animate**: it drops from about 5 API calls per frame to about 1.
- The frame sizes itself to the widest string it can ever show, measured once,
  so the block does not change size between `4.3` and `regen` and the drag area
  hugs what you see. `/mb size` still sets the height, which drives the font;
  the width comes from the text.
- The flask's figure uses `OUTLINE` because it sits over the glass and the
  liquid. Text mode sits over the game's own background, where an outline reads
  as a thick border, so it uses a short shadow instead.

### A sound of its own

- **A water drop when the rule is fulfilled**, which is the moment mana starts
  climbing again. It replaces the `SOUNDKIT.READY_CHECK` of 1.0, an interface
  cue borrowed from the game that had nothing to do with mana. It plays in both
  looks and is still governed by `/mb sound on/off`: one switch, one sound.
- The audio is adapted from *Waterdrop* by DRAGON-STUDIO, from Pixabay, under
  the Pixabay Content License: it allows commercial use and modification and
  does not require attribution, but the credit is given in the README anyway.
- The file lives in `Sound/ManaDrop.ogg`: 8.5 KB, mono, 44.1 kHz, 0.60 s. Ogg
  and not MP3 because both load, but MP3 support broke once and when it fails
  it gives no error, it simply stays silent. The silent tail of the original
  was trimmed (1.03 s to 0.60 s, with a fade so it does not end on a click) and
  the peak was normalised to -1.3 dBFS.
- If the file were missing, `PlaySoundFile` says so and the addon prints it
  under `/mb debug on`, once per session. A control that does nothing without
  explaining why is worse than one that is not there.

### Packaging and tests

- The tests cover the new skin end to end, including that switching back to the
  flask restores it whole and not half-way, and that the drop plays in both
  looks exactly once.
- New check that the `.toc` files cannot drift apart: they may differ only in
  the `## Interface` line, and their list of Lua files has to be the one the
  test suite loads. Near-identical files are not reviewed by eye.
- **The flavour-suffixed `.toc` is gone.** Forever's suffix was never
  confirmed, and it turned out not to matter: the generic file already carries
  interface `16001` and is the one that loads when no suffix matches, so the
  suffixed copy could only ever duplicate what the generic already did. A
  single `ManaBreath.toc` is published.
- Test copies `ManaBreath_Mainline.toc` (Retail, `120001`) and
  `ManaBreath_Vanilla.toc` (Classic Era, `11507`), so loading, drawing and the
  commands can be checked on live clients before Forever launches. They are
  kept out of the published package: they would advertise compatibility that
  has not been verified.
- The static footprint rises to about 106 KB plus about 12 KB for the panel.
  The text skin's ~12 KB are paid whether you use it or not, because both skins
  are built at load: switching between them should not have to construct
  widgets in the middle of a rule.

## 1.1.0

- The bar becomes a **flask**: the liquid rises through the 5 seconds and the
  counter sits inside the bulb.
- An animated surface (two wave layers at different speeds) and bubbles rising
  while the rule runs.
- **Regeneration phase**: when the rule ends the flask does not go out, it
  turns green and starts marking the mana coming in. The liquid follows your
  real mana, the number becomes a percentage, and every mana tick lands as a
  flash. The phase closes when mana fills up, when you leave combat, when you
  spend mana again (which restarts the rule), or after 4 seconds without a
  single tick, which is the safety net if the client does not report each one.
  `/mb regen off` returns to the short cue of 1.0.
- **A glow around the flask** while you are regenerating, which is the green
  phase. `/mb glow rule` moves it to the 5 seconds of the rule and
  `/mb glow off` turns it off.
- Its own artwork, generated by `tools/make_art.py`: the liquid is clipped by a
  `MaskTexture` shaped like the inside of the glass, so nothing spills outside
  the flask. Without the mask the addon still works, with the liquid narrowed.
- Its own icon in the addon list.
- Default size 58x58. The drawing assumes a square frame: to make it bigger
  without distorting it, use `/mb scale`.
- The `OnUpdate` still allocates nothing per frame, the green phase included,
  and is still uninstalled at rest.
- The waves, the bubbles and the glow's pulse move to 30 Hz (`ANIM_STEP`). At
  58 px nothing advances more than half a pixel per step, so 60 Hz was twice
  the API calls for the same drawing: from about 16 to about 5 calls per frame.
  The liquid level and the counter still run per frame.
- `Show()` and `SetAlpha()` on the bubbles are only called when they actually
  change. Before, both were called every frame, and a bubble spends 70% of its
  life at a constant opacity.
- The memory bench measures with the collector stopped. With it running, what
  was measured was not what the addon allocates but what the collector had not
  freed in time, which shifts with the size of the heap: that is where 1.0's
  "3-12 bytes per cast" came from, when the real figure is about 320, all of it
  the table `C_Spell.GetSpellPowerCost` returns. The frames, by contrast, are
  genuinely zero.
- New `tests/profile.lua`: counts API calls per frame in each phase.
- **Options panel** under Options -> AddOns, with `/mb config` and a button in
  the addon compartment. The game draws it from the options the addon declares,
  and the value lives in `ManaBreathDB`, so the panel and the commands cannot
  fall out of step. If a client does not expose the settings API, no panel is
  registered and everything still works through `/mb`.
- The glow mode applies live (`RefreshGlow`): before, changing it mid-cycle was
  not visible until the next one.
- `debug` is now declared in the defaults. The panel needs a default of the
  right type for every option it shows.

## 1.0.0

First release.

- A bar that fills through the 5 seconds of the mana regeneration rule.
- Detection via `UNIT_SPELLCAST_SUCCEEDED` + `C_Spell.GetSpellPowerCost`, with
  no dependency on the combat log.
- Channel support (channel start and stop).
- Secret Values handling: confirmation by mana drop when the cost cannot be
  read.
- Cast deduplication by `castGUID`.
- Optional fallback via `UNIT_POWER_UPDATE` (`/mb fallback on`).
- `/mb status` reports the restricted context via `C_RestrictedActions`.
- Visible only on classes and forms that use mana.
- Draggable bar, with position and options saved in SavedVariables.
- `OnUpdate` installed only while there is something to animate: 0 bytes per
  frame at rest, even with the bar visible.
- An allocation-free counter: the 51 strings of the 5 s window are precomputed
  at load.
- Text and spark update only when they change.
- Symmetric confirmation window: the order in which `UNIT_POWER_UPDATE` and
  `UNIT_SPELLCAST_SUCCEEDED` arrive does not affect detection.
- Costs with `hasRequiredAura` do not count as a safe cost, so a spell an aura
  made free does not start the rule.
- `/mb channel off` disables the restart when a channel is cut.
- `/mb verify` measures against the client whether the 5 s rule exists and how
  long it lasts, using `GetPowerRegen()` as the reference.
- A `nil` cost is read as "no resource cost" and not as "unreadable", so a free
  instant does not claim somebody else's mana drop.
- `/mb status` reports which cost API was found, so that the absence of both
  does not degrade the addon silently.
- `/mb` commands (lock, unlock, test, scale, size, sound, text, always,
  fallback, reset, status).
