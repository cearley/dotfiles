## 1. Mock binary

- [x] 1.1 Filter `_`-prefixed keys from `ls|list` output in `tests/bin/keepassxc-cli`

## 2. Test runner

- [x] 2.1 Add template file existence guard to `tests/run-template` after arg parsing

## 3. Verification

- [x] 3.1 Confirm `keepassxc-cli ls` no longer lists `_comment`
- [x] 3.2 Confirm `tests/run-template nonexistent.tmpl` prints a clear runner error
