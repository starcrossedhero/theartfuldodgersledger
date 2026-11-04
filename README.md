# The Artful Dodger's Ledger

The Artful Dodger's Ledger is a World of Warcraft addon for Rogues. It tracks pickpocketing and lockbox loot, then organizes the results into in-game reports and tables.

## Features

- Records pickpocket attempts, copper, and items, with creature, difficulty, and location statistics.
- Shows pickpocket status, estimated refresh timers, and optional loot summaries in unit tooltips.
- Adds optional badges to target frames and nameplates, with configurable placement and size.
- Displays pickpocket statistics on the world map.
- Tracks lockbox and junkbox openings and provides an optional movable opener button.
- Keeps persistent history and a separate summary for the current play session.

## Install

Download the ZIP from a release and extract it into the Retail AddOns directory:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

The extracted folder should be named `TheArtfulDodgersLedger` and contain `TheArtfulDodgersLedger.toc`. Restart the game or enable the addon from the character-select AddOns menu.

## Commands

| Command | Description |
| --- | --- |
| `/adl help` | Show available commands. |
| `/adl history` | Print lifetime totals and open the addon window. |
| `/adl session` | Print current-session totals. |
| `/adl toggle` | Open or close the addon window. |
| `/adl reset session` | Reset current-session statistics. |
| `/adl reset history` | Clear all recorded history and reset the session. |

The main window can also be opened or closed from **The Artful Dodger's Ledger** entry in the default AddOn Compartment drawer.

Display options are available under **Settings > AddOns > The Artful Dodger's Ledger**. The addon is intended for Retail and only activates for Rogue characters.

## License

The original addon code is licensed under the MIT License; see [LICENSE](LICENSE). Addon distribution must also comply with [Blizzard's UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534), including its requirement that addons be distributed free of charge. The license does not grant rights to Blizzard trademarks or game assets.