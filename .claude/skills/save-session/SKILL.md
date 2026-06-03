---
name: save-session
description: Append today's decisions, findings, and next steps to the chezmoi-dotfiles basic-memory note. Run at end of every coding session.
---

Search basic-memory project "chezmoi-dotfiles" for the most recent session note using search_notes with query "chezmoi-dotfiles session".

Then append an update with edit_note (operation="append") including:
- Date (use the currentDate value from context)
- What was changed or decided today
- Any new open items or next steps discovered
- Any resolved items that can be checked off

Never overwrite the existing note — always append.
Confirm the note title and permalink after saving.
