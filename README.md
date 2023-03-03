# rustvm

A version manager for rust. Updated, re-aliased

## Installation

```console
curl -L https://raw.github.com/coldestheart/rustvm/master/install.sh | sh
```

or

```console
wget -qO- https://raw.github.com/coldestheart/rustvm/master/install.sh | sh
```

### for fish-shell users

```console
ln -s ~/.rustvm/rustvm.fish ~/.config/fish/functions
```

or

```console
echo "source ~/.rustvm/rustvm.fish" >> ~/.config/fish/config.fish
```

## Usage

Show the help messages. Choose the one that you like most.

```console
rustvm help
rustvm --help
rustvm -h
```

Download and install a &lt;version&gt;. &lt;version&gt; could be for example "0.12.0".

```console
rustvm install <version>
e.g.: rustvm install 0.12.0
```

Activate &lt;version&gt; for now and the future.

```console
rustvm use <version>
e.g. rustvm use 0.12.0
```

List all installed versions of rust. Choose the one that you like most.

```console
rustvm ls
rustvm list
```

List all versions of rust that are available for installation.

```console
rustvm ls-remote
```

Print a channel version of rust that is available for installation.

```console
rustvm ls-channel stable
```

## Example: Install 0.12.0

```console
curl https://raw.github.com/sdepold/rustvm/master/install.sh | sh
source ~/.rustvm/rustvm.sh
rustvm install 0.12.0
rustvm use 0.12.0

# you will now be able to access the rust binaries:
~ ∴ rustc -v
rustc 0.12.0
host: x86_64-apple-darwin

~ ∴ cargo -h
Usage: cargo <cmd> [options] [args..]

~ ∴ rustdoc -h
Usage: rustdoc [options] <cratefile>
```

