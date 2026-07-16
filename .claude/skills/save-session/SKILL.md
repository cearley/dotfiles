---
name: save-session
description: Append today's decisions, findings, and next steps to the chezmoi basic-memory note. Run at end of every coding session.
---
<!-- setup-memory-workflow-version:1 -->

Search basic-memory project "chezmoi" for the most recent session note using search_notes with query "chezmoi session".

Append an update with edit_note (operation="append") including:
- Date (use the currentDate value from context)
- What was changed or decided today
- Any new open items or next steps discovered
- Any resolved items that can be checked off

Never overwrite the existing note — always append.
Confirm the note title and permalink after saving.
