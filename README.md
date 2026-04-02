# GTax (WoW Anniversary)

GTax is a World of Warcraft Anniversary addon for tracking personal guild-tax activity and sharing contribution stats with guildmates who also run GTax.

It focuses on three things:

1. Tracking how much gold you have earned since your last guild bank contribution.
2. Tracking your contribution history (today, this week, total, and time since last contribution).
3. Showing a guild leaderboard that syncs over the addon guild channel.

## Features

### Main tracker window
- Movable compact tracker window.
- Shows earned gold since last contribution.
- Optional earned today and earned this week sections.
- Shows suggested contribution based on configurable tax percent.
- Shows contributed today, this week, and total.
- Shows time since last contribution with age-based color.

### Options and leaderboard window
- Movable options window that stays on top of normal UI windows.
- Toggle visibility for tracker sections.
- Adjustable tax slider (1% to 20%).
- Guild leaderboard table with:
	- Sortable columns
	- Header highlight for active sort column
	- Zebra striping
	- Scroll support for larger guild rosters
	- Dynamic title: `<Guild Name> Guild Leaderboard`

### Guild sync
- Uses addon prefix `GTax` on the `GUILD` addon channel.
- On login/reload, the addon sends a sync request to guildmates.
- Clients respond with current leaderboard data.
- On detected contribution, your updated data is broadcast.
- Sync payload shares: player, total, today, week, last contribution timestamp, and unpaid loans.

## Contribution detection behavior

- GTax watches guild bank interactions and money changes to detect real contributions.
- Contribution detection uses pending contribution/withdrawal flags and confirms on guild bank money update events.
- Contribution amount handling prefers the exact amount passed to `DepositGuildBankMoney`.

## Slash commands

- `/gtax` or `/gtax toggle`: Toggle main tracker window.
- `/gtax options`: Open/close options and leaderboard window.
- `/gtax reset`: Manual reset of earned tracking.
- `/gtax audit`: Send your contribution summary to guild addon chat.
- `/gtax help`: Show command help.

## Notes

- Leaderboard visibility depends on guildmates also having GTax installed and online.
- Sync data is addon-channel data, not Blizzard guild roster contribution data.
- This addon is intended for personal/guild coordination workflows and does not enforce any mandatory tax system.
