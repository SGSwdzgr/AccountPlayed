# AccountPlayed 
Simple WoW addon to track and display /played time. sorting by class across all realms.

[![CurseForge Downloads](https://img.shields.io/curseforge/dt/1426046?style=for-the-badge&color=green)](https://www.curseforge.com/wow/addons/account-played)

<img width="534" height="389" alt="image" src="https://github.com/user-attachments/assets/8bb04d03-74ae-418f-9950-527791d880e0" />

Features:
- View your accounts top played time by class
- sorted by (class/total account /played) as a percentage
- small popup ui (resize, drag, move, and scroll as you please!)
- minimap button to toggle ui.
- (NEW) Hover over classes to get a popup of all the characters making up the playtime.
- (NEW) Button to Toggle between Years/Days or Hours/Min
- (NEW) press escape to close window
- (Planned/Incomplete) Document and publish helper functions so other addons can access AccountPlayedDB safley.
- (Planned/Incomplete) Localized strings to support other languages. 
- (Planned/Incomplete) Right click on minimap icon to hide any playtime info and only display the class differences. 
- (Future Plans) Small patches, bug fixes, and maintainece.

Usage:
- `/apclasswin` - open/close account played window (OR use minimap button)
- `/apdebug` - prints a list of all stored characters to chat in the following format: `Realm-Name: TimePlayed (CLASS)`

### Quick-start:
- Download the latest release here on github. extract the zip to your games addon folder.
- (Recommended) Download with your favorite addon manager via [Curse](https://www.curseforge.com/wow/addons/account-played)

### Contributing:
- install `just` to run the repos `justfile` 
- set PATHs to match local at the top of `justfile`

Examples:
```bash
just --list # print all commands
just ls retail # list all files in retail addon dir
just sync retail # sync local repo changes to retail addon dir 
just rm retail # remove addon from retail dir. (keeps local repo unchanged)
just debug # print os, set PATHs, shasum of all files.
```

Generate a Tagged Release to trigger ./.github/workflows/build.yml (packager action)
```bash
# just build <tag> <commit>
just build 1.0.0 "Commit Message for Tagged release"
```

### Honorable Mentions:
HUGE Thank you to everyone in [Seems Good](https://seemsgood.org) for testing and motivating to publish and share with others.
Pip - Original idea to share time played and compare with other guildies.
Whare - WoW api help and debugging
[WOWHEAD](https://www.wowhead.com/news/find-your-favorite-class-with-account-played-380300) - Huge thanks for promoting the addon!! seeing all the screenshots shared online is surreal to say the least.
[r/wow](https://www.reddit.com/r/wow/comments/1quo3h0/account_played_track_and_display_your_characters/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button) - All the great feedback like missing documentation on slashcommands, bugs with missing minimap, and screenshots shared (:
