# Chezmoi Encryption & Secret Management

## Age Encryption (Recommended)

### Setup

```bash
# Generate key
age-keygen -o ~/.config/chezmoi/key.txt

# Add to .chezmoi.toml
[encryption]
    type = "age"
    recipient = "age1..."  # Public key from key.txt
```

### Usage

```bash
# Add encrypted file
chezmoi add --encrypt ~/.secret-config

# File stored encrypted in source directory
# Decrypted automatically during chezmoi apply
```

### Key Management

- Back up `~/.config/chezmoi/key.txt` securely
- The key file should NOT be managed by chezmoi
- Each machine needs a copy of the key file

## GPG Encryption

```toml
# .chezmoi.toml
[encryption]
    type = "gpg"
    recipient = "your@email.com"
```

## 1Password Integration

Chezmoi can read secrets from 1Password using the `onepassword` template function:

```
# In a template
{{ (onepassword "item-name").fields.password.value }}

# Or using item UUID
{{ (onepasswordRead "op://vault/item/field") }}
```

Requires 1Password CLI (`op`) to be installed and authenticated.

## .chezmoiexternal

Pull external files (git repos, archives, single files) into chezmoi management:

```toml
# .chezmoiexternal.toml
[".oh-my-zsh"]
    type = "archive"
    url = "https://github.com/ohmyzsh/ohmyzsh/archive/master.tar.gz"
    exact = true
    stripComponents = 1
    refreshPeriod = "168h"

[".vim/pack/plugins/start/vim-airline"]
    type = "git-repo"
    url = "https://github.com/vim-airline/vim-airline.git"
    refreshPeriod = "168h"
```

## .chezmoiremove

List files that should be removed from the target when running `chezmoi apply`:

```
# .chezmoiremove
.old-config
.deprecated-tool/
```

Use with caution -- this permanently deletes files from the home directory.

## Best Practices

1. **Never commit encryption keys** to the dotfiles repo
2. **Use age over GPG** -- simpler, fewer moving parts
3. **Back up keys separately** from dotfiles
4. **Use 1Password integration** when available to avoid storing secrets in files
5. **Rotate keys periodically** and re-encrypt files
6. **Test decryption** on new machines before relying on encrypted configs
