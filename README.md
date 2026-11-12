# QuickKeybinds

A standalone keybinding manager for **WoW Forever**, using the Blizzard action bars. Version **1.0.9**. No libraries or other addons required.

## Install and open

Extract `QuickKeybinds-1.0.9.zip` into the Forever client's `Interface/AddOns` directory. The result should be `Interface/AddOns/QuickKeybinds/QuickKeybinds.toc`, with no extra nested folder. Restart the client or enable the addon in character selection.

Open with **`/qkb`** or **`/quickkeybinds`**. **`/kb`** also works if another addon has not already claimed it.

The editor follows the Blizzard window style, with a native title bar and close control, gold selection accents, dark keycaps and grouped content panels. Active tabs and modifier layers stay readable; Save and Hover bind stand out from secondary actions. Keyboard names are kept within their keycaps, with full localized labels in tooltips.

The keyboard has staggered typing rows, grouped function keys, a wide Space/Enter/Shift layout, separate navigation and numpad blocks, and a mouse strip. Click either Shift/Ctrl/Alt keycap to toggle that modifier layer. Windows/menu keycaps are decorative. Numpad Enter mirrors the main Enter binding. The layout is a standard keyboard illustration; QWERTY/AZERTY/QWERTZ change the key arrangement without changing your bindings. UI separators and direction labels use font-safe characters so they render correctly with the Forever fonts.

## Keyboard layout detection

New settings start with a keyboard layout based on client language: **French (`frFR`): AZERTY; German (`deDE`): QWERTZ; every other language: QWERTY**. This is a default preference, not physical-keyboard detection. Manual selections and calibration results take precedence and remain saved across reloads or client-language changes. Existing saved choices are preserved. **Use client-language default** in Settings returns to the language-based default; while using that default, the next initialization follows the current client language.

In the keyboard view, click **Detect** (**Détecter** in French), or use **Detect keyboard layout** in Settings. Press the first six letter keys of the top letter row, from left to right, immediately after Tab. Use the physical positions without modifiers. The addon recognises `AZERTY`, `QWERTY` or `QWERTZ`, applies that display layout and remembers it. Upper/lower case is accepted. Cancel, partial input and unrecognised sequences preserve the current layout. The prompt closes in combat.

This is a short guided calibration, not silent OS-layout detection. Client language supplies the initial default; calibration or a manual choice can select a different layout. Only this prompt reads the six-key sample; it does not monitor ordinary typing. Calibration changes the display preference while preserving native bindings and pending binding edits. Use Detect again after switching your OS input layout, or keep using the manual layout selector.

## Gamepad view

Open **Keyboard & Gamepad**, then choose **Gamepad** (**Clavier et manette > Manette** on a French client). The label selector cycles **Auto, Xbox, PlayStation and Nintendo**. Auto is the default; previously saved manual choices are preserved. Choose Auto once to enable detection if you already selected a manual style. The controller diagram includes the D-pad, face buttons, triggers, shoulders, stick clicks, center buttons and rear buttons. Unsupported native buttons are dimmed. Xbox/Nintendo use an offset left-stick layout; PlayStation uses a symmetric layout. These are generic controller illustrations; optional buttons depend on your hardware.

Auto reads WoW's native controller label style, using the active physical controller when available and otherwise the first connected device. Recognized controller names provide a fallback when the style is generic or unavailable. The view updates on connection/configuration changes and checks for a different active controller while open. It shows the detected device name and effective style. With no controller or an unknown layout, an explicitly labelled Xbox preview is shown; manual styles remain available. Input wrappers that identify another controller as Xbox are treated according to the Xbox style WoW reports. Detection changes the illustration and labels while preserving the binding draft and native settings.

Select an action in Bindings, then click a controller button to assign it. Right-click to remove its binding, or use Shift/Ctrl/Alt above the diagram to edit modified bindings. Names, spell icons, conflicts, undo/redo, profiles and Save/Discard work the same way as for keyboard keys. Profiles store both keyboard and controller bindings.

You can also press a physical controller button during Add key or hover binding. If the button emulates a WoW modifier, hold it and press another button to capture that combination. The diagram still lets you inspect/edit the underlying modifier button's binding; its tap behavior follows WoW's configuration. A note above the controller shows native modifier-button assignments.

Controller input, analog movement, camera behavior and modifier emulation use WoW's native settings. If gamepad input is disabled, the view reports that state while allowing you to prepare bindings. Stick buttons in the diagram represent stick **clicks**; axis movement uses the native movement/camera configuration. Native gamepad APIs are required for editing controller buttons. Bindings supplied through another addon's temporary overrides can differ from the native bindings shown here.

## Binding workflow

1. Choose **Account** or **Character** at the top. Switching scope requires a clean draft.
2. Click **Hover bind**, hover a visible Blizzard button, and press a key, modified mouse button, or mouse wheel direction. Escape over that button clears its bindings. **Finish** returns to the editor.
3. Alternatively, search the **Bindings** page, select an action, and use **Add key**, individual **Replace / Remove**, or **Clear all**. The category selector and bound, unbound, pending and unavailable filters help audit bindings.
4. Review changes, use **Undo / Redo**, then **Save** or **Discard**.

**Edits remain in a draft until Save.** Closing the window never saves. A small pending-change button remains visible when a dirty editor is closed; click it to return. A closed draft stays available during the current session; reload/logout discards it. Profiles can preserve a draft across sessions.

Occupied keys show the existing and proposed actions before reassignment. Unmodified left and right mouse buttons remain reserved for the game. Modifier keys alone are ignored by capture.

## Pages

- **Bindings:** native actions, current spell/item/macro labels, key search, categories and audit filters. Hover targets cover main/additional Blizzard bars, pet actions, stances/forms, extra action and the native vehicle-exit button when available.
- **Keyboard & Gamepad:** switch between keyboard/mouse and controller layouts, with shared Shift/Ctrl/Alt layers. Each assigned key/button shows a compact action/spell name and its icon when available. Hover for the full key and action name in the tooltip and the line above the layout. These follow the draft, selected modifier layer, current bar page and Blizzard vehicle overrides; items, macros, pet actions and stances also show their current names/icons. Macros show the macro's name, without evaluating its script. Bound labels are blue; pending changes are gold. Select an action in Bindings first; right-click a key/button to remove it. QWERTY, AZERTY and QWERTZ are visual arrangements of the client's key tokens, not automatic physical keyboard detection. Full localized labels appear in tooltips.
- **Profiles:** create a snapshot of the draft, duplicate, rename, delete, export or import. Applying a profile shows a complete replacement preview and changes only the draft. Profiles contain bindings, not spells, macros or bar layouts.
- **History:** automatic snapshots before saves and snapshots of successful saves, including scope, character and date. Restore previews changes to the **currently selected scope**. Up to 50 history records are retained.
- **Settings:** conflict confirmation, keyboard arrangement and guided detection, UI scale, overlay opacity and labels. The addon UI supports English, French and German; action and key names come from the client.

## UI languages

QuickKeybinds follows the client's UI language: English, French (`frFR`) and German (`deDE`) have complete catalogs covering menus, dialogs, tooltips, key/controller captions, profile/import validation, save/recovery messages and history labels. Other client languages use English addon text. Dates and percentage spacing follow the selected UI locale. Long button labels expose their full text on hover.

WoW supplies localized native action, spell, item and key names. Player-entered profile/macro names, controller device names and binding identifiers retain their original spelling. Labels from other addons follow the text those addons provide. Native/API diagnostics are kept as technical details inside localized error messages.

Translation files live in `Locales/enUS.lua`, `Locales/frFR.lua` and `Locales/deDE.lua`. `tests/check_locales.py` checks catalog completeness, format placeholders, UTF-8 text and untranslated literals; the Lua tests exercise all three UI languages.

Bindings are saved as native Blizzard commands, so they continue to work when QuickKeybinds is disabled. Editing does not install override bindings or replace action buttons.

## Combat, conflicts and recovery

Capture and binding edits pause in combat. The draft is preserved; hover overlays return after combat. Keys remain unchanged until an explicit Save outside combat.

If another addon or Blizzard's binding panel changes the live bindings, saving is blocked. **Reload bindings** discards the draft and reads the live bindings. **Rebase draft** previews and reapplies just the draft's edits over the latest selected scope; edited keys take precedence after confirmation.

Before saving, QuickKeybinds records a backup, applies the draft, checks what the client accepted, and calls the client's save API. Reported failures trigger rollback and preserve the draft. If rollback itself fails, an error directs you to History. Backups and profiles use `QuickKeybindsDB` and are written to disk through WoW's normal SavedVariables lifecycle.

Imports use a bounded, versioned text format (`QKB1`) with escaped entries. Imported text is parsed as data and is never executed. Duplicate keys, invalid entries and unsupported versions are rejected. Unknown commands appear in the preview and block applying that import/profile.

## Compatibility and limits

- This build targets Forever's **16001** interface family only.
- Hover mode targets Blizzard buttons. Bartender, ElvUI and other replacement-bar adapters are outside this version's scope. Do not run two hover-binding modes at once.
- Native action commands address buttons, not a particular spell or action-bar page. Paging, stance and vehicle overrides remain under Blizzard's control.
- Context buttons without a stable native binding command, including the zone-ability button, are not given addon-specific click bindings.
- The editor can list unavailable bar targets for auditing. Hidden bars must be made visible to use hover mode.
- All bindings exposed by the client are retained; the addon does not impose a two-key display limit. The client ultimately determines which commands and keys can be saved.
- This release has automated Lua 5.1 tests with mocked Forever APIs. It still needs native client testing; see [TESTING.md](TESTING.md).

## Development

Runtime modules: `Locale.lua` and `Locales/*.lua` provide translations and text formatting; `Engine.lua` owns drafts, transactions, profiles and text exchange; `Targets.lua` adapts the native client; `Theme.lua` provides Blizzard-style window and control styling; `Keyboard.lua` defines physical key positions and guided layout detection; `Gamepad.lua` defines controller layouts and native input support; `UI.lua` builds the editor; `Capture.lua` handles key input; `Main.lua` handles startup and events.

Run tests with Python and `lupa==2.8`:

```text
python -m pip install -r tests/requirements.txt
python tests/run_tests.py
python build.py
```

The ZIP contains only QuickKeybinds runtime files and documentation. The supplied `Bartender4-4.18.4` folder is a reference and is never bundled. QuickKeybinds is an independent implementation; no Bartender core or bundled library code is included.

Run packaging checks with `python -m unittest discover -s tests -p 'test_*.py'`. To write the ZIP to a separate directory, use `python build.py --output-dir dist`.

## Automated releases

Once this repository is hosted on GitHub, every push to `main` runs the addon, locale and packaging tests and builds `QuickKeybinds-<version>.zip`. The version comes from `## Version` in `QuickKeybinds.toc`.

If that version has no GitHub release yet, the workflow creates tag `v<version>` and publishes a release with the installable ZIP and generated release notes. Existing releases stay unchanged; bump the TOC version to publish another release. The workflow can also be run manually on `main`. It uses GitHub's built-in token, with no custom release secret required.
