---
id: 01KW826RP8N6P8JXNPJ00A4Y6G
type: task
title: 'ROADMAP: notmuch.nvim Test Suite Checklist'
tags:
    - '#notmuch'
    - '#idea'
date: 2026-06-29T00:29:42+03:00
state: in-progress
---

Below is a realistic test roadmap/checklist for `notmuch.nvim`, organized by
feature area and roughly mapped to the code modules that should be covered.

## 0. Test Harness / Fixtures

- [x] Dependency-free headless Neovim runner in `tests/run.lua`.
- [x] Shared assertions and temp-file helpers in `tests/helpers.lua`.
- [x] Specs organized under `tests/specs/`.
- [x] Fixture corpora organized under `tests/fixtures/corpora/`.
- [x] Disposable notmuch test database generated under `tests/tmp/`.
- [x] Setup script: `tests/scripts/setup-notmuch-db.sh`.
- [x] Cleanup script: `tests/scripts/clean.sh`.
- [x] Generated test state ignored by git.


## 1. Configuration and Setup

Covered modules:

- `lua/notmuch/config.lua`
- `lua/notmuch/init.lua`

### Setup behavior

- [x] `require("notmuch").setup()` succeeds when `notmuch config` returns valid
  values.
- [x] Setup fails gracefully when `database.path` is missing.
- [x] Setup warns and falls back when `user.name` or `user.primary_email` is missing.
- [x] User options override defaults correctly.
- [x] `notmuch_db_path` expands `~` and other paths.
- [x] Custom `open_handler` and `view_handler` are stored and used.
- [x] Custom keymaps are merged correctly.
- [x] Invalid or partial `sync` config does not break defaults.

### Command registration

- [x] `:Notmuch` is created after setup.
- [x] `:NmSearch` is created after setup.
- [x] `:Inbox` is created after setup.
- [x] `:ComposeMail` is created after setup.
- [x] Commands are not registered if config setup fails.

---

## 2. Landing Page / Tags View

Covered modules:

- `lua/notmuch/init.lua`
- `ftplugin/notmuch-hello.lua`

### `:Notmuch` / `notmuch_hello`

- [x] Opens a buffer named `Tags`.
- [x] Reuses existing `Tags` buffer if already open.
- [x] Displays all tags returned by `db.get_all_tags()`.
- [x] Inserts the hints line at the top.
- [x] Sets filetype to `notmuch-hello`.
- [x] Sets buffer to non-modifiable.
- [x] Places cursor on first tag, not hints.

### Tag actions from hello buffer

- [x] `<CR>` on a tag runs search for `tag:<tag>`.
- [x] `c` counts messages for selected tag.
- [x] `r` refreshes the tag buffer.
- [x] `%` starts mail sync.
- [x] `C` opens compose flow.
- [x] `q` wipes the buffer.

---

## 3. Search View / Thread List

Covered modules:

- `lua/notmuch/init.lua`
- `lua/notmuch/async.lua`
- `lua/notmuch/refresh.lua`
- `ftplugin/notmuch-threads.lua`

### `:NmSearch`

- [x] Empty search string returns without creating a buffer.
- [x] `thread:<id>` search opens thread view directly.
- [x] Search creates a buffer named exactly after the search query.
- [x] Existing search buffer is reused without refreshing.
- [x] Hints line is inserted.
- [x] Filetype is set to `notmuch-threads`.
- [x] Buffer is non-modifiable after setup.
- [x] Cursor starts at the top.
- [x] Completion callback prints correct number of threads.
- [x] Optional `jumptothreadid` moves cursor to matching thread after refresh.

### Async search

- [x] `notmuch search <query>` is spawned.
- [x] Output chunks are appended incrementally.
- [x] Partial lines across chunks are handled correctly.
- [x] Buffer is temporarily made modifiable during writes.
- [x] If buffer is deleted during search, process is killed or exits safely.
- [x] Completion callback runs after process exits.
- [x] Stderr errors notify the user.

### Sorting

- [x] `reverse_sort_threads()` preserves hints line.
- [x] Thread result lines are reversed.
- [x] Handles empty result buffer.
- [x] Handles one-result buffer.

### Search buffer keymaps/commands

- [x] `<CR>` opens selected thread.
- [x] `r` refreshes search buffer.
- [x] `o` reverses sort.
- [x] `%` starts sync.
- [x] `q` closes buffer.
- [x] `C` opens compose.
- [x] `+`, `-`, `=` operate on current thread.
- [x] Visual `+`, `-`, `=` operate on range.
- [x] `a` toggles `inbox`.
- [x] `A` removes `inbox unread`.
- [x] `x` toggles `unread`.
- [x] `f` toggles `flagged`.
- [x] `dd` marks thread deleted and removes it from buffer.
- [x] Visual `d` deletes selected range.
- [x] `D` opens deleted-thread purge flow.

---

## 4. Inbox Command

Covered modules:

- `lua/notmuch/init.lua`
- `lua/notmuch/completion.lua`

### `:Inbox`

- [x] `:Inbox` searches `tag:inbox`.
- [x] `:Inbox user@example.com` searches `tag:inbox to:user@example.com`.
- [x] Completion uses notmuch addresses.
- [x] Handles email addresses with special characters.

---

## 5. Thread View

Covered modules:

- `lua/notmuch/init.lua`
- `lua/notmuch/thread.lua`
- `ftplugin/mail.lua`

### Opening threads

- [x] `show_thread()` extracts thread ID from selected search line.
- [x] Hints line cannot be opened.
- [x] Existing `thread:<id>` buffer is reused.
- [x] New buffer is named `thread:<id>`.
- [x] Calls `notmuch.thread.show_thread(threadid)`.
- [x] Inserts thread lines into buffer.
- [x] Adds thread hints at top.
- [x] Sets filetype to `mail`.
- [x] Sets buffer non-modifiable.
- [x] Initializes cursor tracking.

### Thread rendering

Test with fixture JSON from `notmuch show --format=json`.

- [x] Single-message thread renders correctly.
- [x] Multi-message thread renders all messages.
- [x] Reply depth adds indentation markers.
- [x] Headers render `Subject`, `From`, `To`, `Cc`, `Date`.
- [x] Missing headers use fallbacks.
- [x] Fold markers are placed correctly.
- [x] Message body text/plain renders correctly.
- [x] Multipart messages recurse correctly.
- [x] Multipart alternative prefers plain text when `render_html_body = false`.
- [x] HTML body shows hidden/alternative marker when rendering disabled.
- [x] HTML body is rendered via `w3m` when `render_html_body = true`.
- [x] Missing `w3m` shows helpful placeholder.
- [x] Failed `w3m` render shows helpful placeholder.
- [x] Attachments are counted and displayed in headers.
- [x] Attachment body parts render placeholder lines.
- [x] Inline non-text parts render placeholder lines.

### Buffer-local metadata

- [x] `vim.b.notmuch_thread` is populated.
- [x] `vim.b.notmuch_messages` is populated.
- [x] Message count is correct.
- [x] Thread tags are collected correctly.
- [x] Authors are collected correctly.
- [x] Message line positions are correct.
- [x] Attachment counts are correct.
- [x] `vim.b.notmuch_current` updates when cursor moves.
- [x] `vim.b.notmuch_status` is formatted correctly.

### Thread keymaps/commands

- [x] `<Enter>` toggles fold.
- [x] `<Tab>` moves to next fold/message.
- [x] `<S-Tab>` moves to previous fold/message.
- [x] `a` opens attachment list.
- [x] `r` refreshes thread buffer.
- [x] `C` opens compose.
- [x] `R` opens reply.
- [x] `q` wipes buffer.
- [x] `+`, `-`, `=` operate on current message.


---

## 6. Tag Management

Covered modules:

- `lua/notmuch/tag.lua`
- `ftplugin/notmuch-threads.lua`
- `ftplugin/mail.lua`

### Message tags

- [x] `msg_add_tag()` adds one tag.
- [x] Adds multiple tags from space-separated input.
- [x] `msg_rm_tag()` removes one tag.
- [x] Removes multiple tags.
- [x] `msg_toggle_tag()` adds missing tag.
- [x] `msg_toggle_tag()` removes existing tag.
- [x] Gracefully returns when no current message ID is found.
- [x] Database is opened in writable mode.
- [x] Database is closed after operation.

### Thread tags

- [x] `thread_add_tag()` operates on current line by default.
- [x] `thread_add_tag()` operates on visual/range lines.
- [x] Adds multiple tags.
- [x] `thread_rm_tag()` removes multiple tags.
- [x] `thread_toggle_tag()` toggles tags based on current thread tags.
- [x] Handles malformed/non-thread lines safely.
- [x] Database is closed after operation.

### Archive/read workflows

- [x] `a` toggles `inbox`.
- [x] `A` removes both `inbox` and `unread`.
- [x] `x` toggles `unread`.
- [x] `f` toggles `flagged`.

---

## 7. Delete and Purge Flow

Covered modules:

- `lua/notmuch/delete.lua`
- `ftplugin/notmuch-threads.lua`

### Soft delete

- [x] `DelThread` adds `del`.
- [x] `DelThread` removes `inbox`.
- [x] Deleted thread line is removed from current buffer.
- [x] Works for visual range.
- [x] Buffer modifiable state is restored.

### Purge

- [x] `purge_del()` searches `tag:del and tag:/./`.
- [x] Sets temporary `DD` keymap.
- [x] Confirm “No” does not run shell command.
- [x] Confirm “Yes” runs delete pipeline.
- [x] Runs `notmuch new` after purge.
- [x] Refreshes search buffer.
- [x] Removes/overrides temporary keymap safely.

---

## 8. Attachments: Viewing, Saving, Opening

Covered modules:

- `lua/notmuch/attach.lua`
- `lua/notmuch/handlers.lua`
- `ftplugin/notmuch-attach.lua`

### Attachment list buffer

- [x] `get_attachments_from_cursor_msg()` gets current message ID.
- [x] Returns safely if no message ID.
- [x] Does not open duplicate attachment buffer for same message.
- [x] Creates split buffer named `id:<message-id>`.
- [x] Sets `buftype=nofile`.
- [x] Calls `notmuch show --exclude=false --part=0 --format=json`.
- [x] Recursively parses MIME tree.
- [x] Skips multipart containers.
- [x] Includes text/plain and text/html leaf parts.
- [x] Treats inline non-text as attachment.
- [x] Stores `mime_parts_list` buffer variable.
- [x] Formats part table with aligned columns.
- [x] Sets filetype to `notmuch-attach`.
- [x] Buffer is non-modifiable.

### Attachment buffer navigation/actions

- [x] Header lines do not map to a MIME part.
- [x] Cursor on part line resolves correct part.
- [x] Out-of-range cursor returns nil.
- [x] `q` closes attachment buffer.
- [x] `s` prompts and saves part.
- [x] `o` saves to `/tmp` and invokes configured open handler.
- [x] `v` saves to `/tmp`, invokes configured view handler, and opens floating window.

### Saving attachments

- [x] Uses original filename when available.
- [x] Sanitizes slashes in filenames.
- [x] Generates filename from content type when missing.
- [x] `text/plain` becomes `.txt`.
- [x] Directory-only input appends filename.
- [x] Empty prompt cancels.
- [x] Nonexistent directory errors.
- [x] Non-writable directory errors.
- [x] Existing file prompts overwrite confirmation.
- [x] Declining overwrite cancels.
- [x] Successful save returns filepath.
- [x] Failed `notmuch show --part` returns nil.

### Default open handler

- [x] Uses `open` on macOS.
- [x] Uses `xdg-open` on Linux.
- [x] Uses `start` on Windows.
- [x] Falls back to `xdg-open` on unknown OS.
- [x] Runs detached.

### Default view handler

- [x] HTML uses `w3m`, then `lynx`, then `elinks`.
- [x] PDF uses `pdftotext`, then `mutool`.
- [x] Images use `chafa`, `catimg`, `viu`, `exiftool`, `identify`.
- [x] Office docs use `pandoc`, then `docx2txt`.
- [x] Markdown uses `pandoc`, then `mdcat`, then `cat`.
- [x] Zip files use `unzip -l`.
- [x] Tar files use `tar -tvf`.
- [x] Text files use `cat`.
- [x] Binary fallback uses `strings`.
- [x] If no viewer works, returns helpful fallback message.

---

---

## 10. Compose and Reply

Covered modules:

- `lua/notmuch/send.lua`
- `lua/notmuch/attach_cmd.lua`
- `lua/notmuch/mime.lua`

### Compose

- [x] `compose()` creates temp `*-compose.eml` file.
- [x] Inserts `From`, `To`, `Cc`, `Subject`, blank line, body hint.
- [x] Optional recipient argument populates `To`.
- [x] Uses configured sender from `config.options.from`.
- [x] Creates attachment buffer.
- [x] Attachment-window keymap opens split.
- [x] Send keymap prompts confirmation.
- [x] Confirm “No” does not send.
- [x] Confirm “Yes” with no attachments builds plain message.
- [x] Confirm “Yes” with attachments builds MIME message.
- [x] Calls `sendmail()` after building message.

### Reply

- [ ] Gets current message ID.
- [x] Returns safely if no message ID.
- [ ] Creates `/tmp/reply-<id>.eml`.
- [ ] Sanitizes `/` in message ID.
- [ ] If draft does not exist, reads `notmuch reply id:<id>`.
- [ ] If draft exists, does not duplicate reply content.
- [ ] Sets `bufhidden=wipe`.
- [ ] Initializes `b:notmuch_attachments`.
- [ ] Creates buffer-local `:Attach`, `:AttachRemove`, `:AttachList`.
- [ ] Send keymap builds plain or MIME depending on attachments.
- [ ] Calls `sendmail()` after confirmation.

### Sendmail

- [ ] Returns false if file does not exist.
- [ ] Builds `msmtp -t --read-envelope-from < file` command.
- [ ] Adds `--logfile` when configured.
- [ ] Opens terminal split.
- [ ] Sends command to terminal job.
- [ ] Starts insert mode.
- [ ] Success exit notifies user.
- [ ] Failure exit notifies user with code.
- [ ] Handles interactive terminal use case.

---

## 11. Attachment Commands for Compose/Reply

Covered modules:

- `lua/notmuch/attach_cmd.lua`
- `lua/notmuch/util.lua`

### `:Attach`

- [x] Expands relative paths.
- [x] Converts to absolute path.
- [x] Rejects nonexistent file.
- [ ] Rejects unreadable file.
- [x] Rejects directories.
- [x] Rejects duplicate attachment.
- [x] Adds valid attachment to `b:notmuch_attachments`.
- [x] Notifies success with count.

### `:AttachRemove`

- [x] Removes existing attachment.
- [x] Notifies remaining count.
- [x] Errors when path is not attached.
- [x] Handles expanded path consistency.

### `:AttachList`

- [x] Prints “No attachments” when empty.
- [x] Lists all attachments with index and size.
- [x] Handles missing stat gracefully.

### Completion

- [x] `AttachRemove` completion returns current attachments.

---

## 12. MIME Generation

Covered modules:

- `lua/notmuch/mime.lua`
- `lua/notmuch/base64.lua`
- `lua/notmuch/util.lua`

### Header/body parsing

- [x] Parses simple `Key: Value` headers.
- [x] Stops headers at first blank line.
- [x] Preserves body lines after blank separator.
- [x] Supports folded RFC 5322 continuation lines.
- [x] Treats first non-header line as body.
- [x] Handles empty input.
- [x] Handles headers with empty values.

### Attachment validation

- [x] Valid files become MIME attachment tables.
- [x] Empty path entries are ignored.
- [x] Invalid files are collected and reported together.
- [x] Error message includes each bad path and reason.
- [x] MIME type is detected with `file --mime-type`.

### MIME message building

- [x] Single inline part renders expected headers.
- [x] Attachment part includes `Content-Disposition: attachment`.
- [x] Inline part includes `Content-Disposition: inline`.
- [x] Base64 attachment content is encoded.
- [x] Base64 lines are wrapped at 76 characters.
- [x] Multipart message includes boundary.
- [ ] Nested multipart messages render correctly.
- [x] Final boundary ends with `--`.
- [x] Missing file after validation raises internal error.
- [x] Random boundary length is correct.

### Base64

- [x] Encodes empty string.
- [x] Encodes known strings: `f`, `fo`, `foo`, `foobar`.
- [x] Decodes known strings.
- [x] Round-trips binary-like input.
- [x] Handles padding correctly.

---

## 13. Sync

Covered modules:

- `lua/notmuch/sync.lua`

### Job helpers

- [x] `create_job()` forwards callbacks/options.
- [x] `stop_job()` stops valid job.
- [x] `stop_job(nil)` returns false.
- [x] `is_job_running()` returns correct status.
- [x] Current sync job getter/setter works.

### Buffer mode

- [x] Default mode is buffer.
- [x] Opens/reuses `notmuch-sync` buffer.
- [x] Sets buffer options: `nofile`, `wipe`, no swapfile.
- [x] Inserts initial status text.
- [x] Runs `<maildir_sync_cmd> ; notmuch new`.
- [x] Appends stdout incrementally.
- [x] Appends stderr incrementally.
- [x] Removes trailing empty stdout chunk.
- [x] On success, appends success message and notifies.
- [ ] On failure, appends failure message and notifies.
- [x] Buffer is non-modifiable after writes.
- [ ] `<C-c>` cancels running job.
- [ ] `<C-c>` after job exit warns.

### Background mode

- [x] Runs job without creating buffer.
- [x] Notifies start.
- [x] Clears current job on exit.
- [x] Success notifies.
- [ ] Failure notifies.

### Terminal mode

- [ ] Opens terminal split.
- [ ] Stores terminal job as current sync job.
- [ ] Sends sync command plus `exit`.
- [ ] Starts insert mode.
- [ ] Clears current job on `TermClose`.
- [ ] Success notifies after defer.
- [ ] Failure notifies with exit code.

### Concurrency

- [x] Starting sync while one is running does not start another.
- [ ] If sync buffer exists, switches to it.
- [x] If no sync buffer exists, warns only.

---

## 14. Completion

Covered modules:

- `lua/notmuch/completion.lua`

### Search term completion

- [x] Default candidates include `tag:`, `from:`, `to:`, `date:`, boolean
  operators, etc.
- [x] Filters by prefix.
- [x] `tag:` completes known tags.
- [x] `is:` completes known tags.
- [x] `from:` completes notmuch addresses.
- [x] `to:` completes notmuch addresses.
- [x] `mimetype:` completes top-level MIME types.
- [x] `folder:` completes maildir folders.
- [x] `path:` completes maildir paths.
- [x] Folder/path values with spaces are quoted.
- [x] Folder/path values with brackets are quoted.
- [x] Duplicate folders are removed.
- [x] Results are sorted.
- [x] Failure to get `database.mail_root` returns empty list and notifies.

### Tag/address completion

- [x] `comp_tags()` filters notmuch tags.
- [x] `comp_address()` filters notmuch addresses.
- [x] Handles empty prefix.
- [x] Handles no results.

---

## 15. Refresh

Covered modules:

- `lua/notmuch/refresh.lua`

### Search refresh

- [x] Gets thread ID from current line.
- [x] Gets search query from buffer name.
- [x] Wipes current buffer.
- [x] Re-runs search.
- [x] Jumps back to previously selected thread.

### Thread refresh

- [x] Extracts `thread:<id>` from buffer name.
- [x] Wipes current buffer.
- [x] Reopens same thread.

### Hello refresh

- [x] Wipes current buffer.
- [x] Reopens tag list.

---

## 16. Utility Functions

Covered modules:

- `lua/notmuch/util.lua`

### General utilities

- [x] `empty_attachment_window()` returns true for empty buffer.
- [x] Returns true for whitespace-only buffer.
- [x] Returns false when any non-whitespace text exists.
- [x] `format_size(nil)` returns `—`.
- [x] `format_size(0)` returns `—`.
- [x] Bytes format as `B`.
- [x] Kilobytes format as `K`.
- [x] Megabytes format as `M`.
- [x] Gigabytes format as `G`.
- [x] `file_exists()` true for existing file.
- [x] `file_exists()` false for missing file.
- [x] `validate_attachment_file()` accepts regular readable file.
- [x] Rejects missing file.
- [x] Rejects directory.
- [ ] Rejects unreadable/special file.
- [x] `split()` works with `%S+`.
- [x] `split_length()` wraps strings correctly.
- [x] `find_cursor_msg_id()` finds nearest previous `id:<id> {{{`.
- [x] `find_cursor_msg_id()` returns nil and prints message if none found.

---

## 17. Filetype Plugins and Mappings

Covered files:

- `ftplugin/notmuch-hello.lua`
- `ftplugin/notmuch-threads.lua`
- `ftplugin/notmuch-attach.lua`
- `ftplugin/mail.lua`

### General mapping tests

- [x] Each filetype plugin only creates buffer-local mappings.
- [x] Mappings do not leak globally.
- [x] Commands are buffer-local where expected.
- [x] Commands have expected nargs/range/completion.
- [x] `mail.lua` only configures thread buffers whose basename starts with `thread:`.
- [x] Thread buffers use `foldmethod=marker`.
- [x] Thread buffers start with `foldlevel=0`.
- [x] Search buffers set `wrap=false`.

---

## 18. Integration / End-to-End Scenarios

These can use a small disposable notmuch database fixture.

### Basic read workflow

- [x] Setup plugin against fixture database.
- [x] Run `:Notmuch`.
- [ ] Select `inbox`.
- [ ] Search buffer appears.
- [x] Open first thread.
- [x] Thread renders expected subject/body.
- [ ] Cursor status variables update.

### Search workflow

- [x] Run `:NmSearch tag:inbox`.
- [x] Results stream in.
- [ ] Refresh preserves current thread.
- [ ] Reverse sorting works.
- [x] Opening a specific `thread:<id>` directly works.

### Tag workflow

- [x] Add tag to thread.
- [x] Remove tag from thread.
- [ ] Toggle tag from thread.
- [ ] Open thread.
- [ ] Add/remove/toggle tag on message.
- [ ] Refresh reflects changed tags.

### Attachment workflow

- [ ] Open message with attachment.
- [ ] Open attachment list.
- [ ] Save attachment to temp dir.
- [ ] View attachment with stub handler.
- [ ] Open attachment with stub handler.

### Compose workflow

- [ ] Compose new message.
- [ ] Add attachment.
- [ ] Remove attachment.
- [ ] Build MIME message.
- [ ] Stub `msmtp` and verify send command.

### Reply workflow

- [ ] Open thread.
- [ ] Reply to message.
- [ ] Draft generated from `notmuch reply`.
- [ ] Attach file.
- [ ] Send with stub `msmtp`.

### Sync workflow

- [ ] Buffer sync with fake sync command succeeds.
- [ ] Buffer sync failure reports error.
- [ ] Background sync succeeds.
- [ ] Terminal sync sends command.
- [ ] Concurrent sync is blocked.

---

## 19. Suggested Test Priority

### Phase 1: Pure/unit tests

Start with modules that do not need real Neovim UI or notmuch DB:

- [x] `util.lua`
- [x] `mime.lua`
- [x] `base64.lua`
- [x] `completion.lua` with mocked system calls
- [x] `handlers.lua` with mocked `vim.system`
- [x] `attach_cmd.lua`

### Phase 2: Buffer/UI tests

Use headless Neovim:

- `init.lua`
- `refresh.lua`
- `sync.lua`
- ftplugins
- thread/search buffer creation
- keymaps and user commands

### Phase 3: Mocked notmuch tests

Mock:

- `notmuch.cnotmuch`
- `vim.fn.system`
- `vim.fn.systemlist`
- `vim.system`
- `vim.loop.spawn`

Cover:

- search
- tags
- threads
- attachments
- completion

### Phase 4: Real integration tests

Use a temporary Maildir and notmuch database fixture.

Cover:

- real indexing
- real search
- real `notmuch show --format=json`
- real tag mutation
- real attachment extraction

---

## 20. Highest-Value Coverage Targets

If you want the most confidence quickly, prioritize:

1. MIME generation and attachment validation.
2. Thread JSON rendering.
3. Search buffer behavior.
4. Tag add/remove/toggle.
5. Compose/reply send preparation.
6. Attachment save/view/open workflow.
7. Sync concurrency and modes.
8. Completion behavior.
9. Refresh behavior.
10. End-to-end fixture database tests.
