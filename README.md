# bitwarden.zsh

Zsh plugin for quickly accessing Bitwarden secrets with auto-completion, caching, and TOTP support — securely and efficiently.

## Features

- Secure access to passwords and TOTP codes
- Fast item lookup with tab-completion
- Encrypted local cache of items (auto-refreshed every 6 hours)
- Uses your existing Bitwarden CLI session if available
- Minimal dependencies: `bw`, `jq`, `oathtool` (for TOTP)

---

## Requirements

- [Bitwarden CLI (`bw`)](https://bitwarden.com/download/)
- [`jq`](https://stedolan.github.io/jq/)
- [`oathtool`] for TOTP functionality (installed by default on many systems)

---

## Installation

### Using Zinit

```zsh
zinit wait lucid for \
  casonadams/bitwarden.zsh
```

### Using Oh My Zsh

```zsh
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone https://github.com/casonadams/bitwarden.zsh.git "$ZSH_CUSTOM/plugins/bitwarden.zsh"
```

then add it to your `.zshrc`:

```zsh
plugins+=(bitwarden.zsh)
```

## Setup Tips

Having issues?

Try removing old cache files:

```sh
rm -f /tmp/.bw_items_cache* /tmp/.bw_session
```

## Usage

### Retrieve a password

```sh
bwpass github.com/john@example.com
```

Or use interactive auto-complete:

```sh
bwpass <TAB>
```

### Retrieve a TOTP code

```sh
bwtotp github.com/john@example.com
```

Or interactively auto-complete:

```sh
bwtotp <TAB>
```

## Examples

```sh
# Copy password for AWS
bwpass aws.amazon.com/user@example.com
```

```sh
# Copy TOTP for GitHub
bwtotp github.com/user@example.com
```

```sh
# View available entries
bwpass <TAB>
bwtotp <TAB>
```

## Troubleshooting

- Cache issues? Try: `rm -f /tmp/.bw_*`.
