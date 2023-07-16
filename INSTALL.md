# Install transcrypt

The requirements to run transcrypt are minimal:

- Bash
- Git
- OpenSSL
- `column` command (on Ubuntu/Debian install `bsdmainutils`)
- `xxd` command if using OpenSSL version 3
  (on Ubuntu/Debian is included with `vim`)

...and optionally:

- GnuPG - for secure configuration import/export

You also need access to the _transcrypt_ script itself...

## Manual Installation

You can add transcrypt directly to your repository, or just put it somewhere in
your $PATH:

    $ git clone https://github.com/elasticdog/transcrypt.git
    $ cd transcrypt/
    $ sudo ln -s ${PWD}/transcrypt /usr/local/bin/transcrypt

## Installation via Packages

A number of packages are available for installing transcrypt directly on your
system via its native package manager. Some of these packages also include man
page documentation as well as shell auto-completion scripts.

### Arch Linux

If you're on Arch Linux, you can build/install transcrypt using the
[provided PKGBUILD](https://github.com/elasticdog/transcrypt/blob/main/contrib/packaging/pacman/PKGBUILD):

    $ git clone https://github.com/elasticdog/transcrypt.git
    $ cd transcrypt/contrib/packaging/pacman/
    $ makepkg -sic

### Heroku

If you're running software on Heroku, you can integrate transcrypt into your
slug compilation phase by using the
[transcrypt buildpack](https://github.com/perplexes/heroku-buildpack-transcrypt),
developed by [Colin Curtin](https://github.com/perplexes).

### NixOS

If you're on NixOS, you can install transcrypt directly via
[Nix](https://nixos.org/nix/):

    $ nix-env -iA nixos.gitAndTools.transcrypt

> _**Note:**
> The [transcrypt derivation](https://github.com/NixOS/nixpkgs/blob/main/pkgs/applications/version-management/git-and-tools/transcrypt/default.nix)
> was added in Oct 2015, so it is not available on the 15.09 channel._

### OS X

If you're on OS X, you can install transcrypt directly via
[Homebrew](http://brew.sh/):

    $ brew install transcrypt

### FreeBSD

If you're on FreeBSD, you can install transcrypt directly via the Ports
collection:

    # `cd /usr/ports/security/transcrypt && make install clean distclean`

or via the packages system:

    # `pkg install -y security/transcrypt`

