# transcrypt

A script to configure transparent encryption of sensitive files stored in a Git
repository. Files that you choose will be automatically encrypted when you
commit them, and automatically decrypted when you check them out. The process
will degrade gracefully, so even people without your encryption password can
safely commit changes to the repository's non-encrypted files.

transcrypt protects your data when it's pushed to remotes that you may not
directly control (e.g., GitHub, Dropbox clones, etc.), while still allowing you
to work normally on your local working copy. You can conveniently store things
like passwords and private keys within your repository and not have to share
them with your entire team or complicate your workflow.

![Tests](https://github.com/elasticdog/transcrypt/workflows/Tests/badge.svg)

## Overview

transcrypt is in the same vein as existing projects like
[git-crypt](https://github.com/AGWA/git-crypt) and
[git-encrypt](https://github.com/shadowhand/git-encrypt), which follow Git's
documentation regarding the use of clean/smudge filters for encryption. In
comparison to those other projects, transcrypt makes substantial improvements in
the areas of usability and safety.

- transcrypt is just a Bash script and does not require compilation
- transcrypt uses OpenSSL's symmetric cipher routines rather than implementing
  its own crypto
- transcrypt does not have to remain installed after the initial repository
  configuration
- transcrypt generates a unique salt for each encrypted file
- transcrypt uses safety checks to avoid clobbering or duplicating configuration
  data
- transcrypt facilitates setting up additional clones as well as rekeying
- transcrypt adds an alias `git ls-crypt` to list all encrypted files

### Salt Generation

The _decryption -> encryption_ process on an unchanged file must be
deterministic for everything to work transparently. To do that, the same salt
must be used each time we encrypt the same file. Rather than use a static salt
common to all files, transcrypt first has OpenSSL generate an HMAC-SHA256
cryptographic hash-based message authentication code for each decrypted file
(keyed with a combination of the filename and transcrypt password), and then
uses the last 16 bytes of that HMAC for the file's unique salt. When the content
of the file changes, so does the salt. Since an
[HMAC has been proven to be a PRF](http://cseweb.ucsd.edu/~mihir/papers/hmac-new.html),
this method of salt selection does not leak information about the original
contents, but is still deterministic.

## Usage

The requirements to run transcrypt are minimal:

- Bash
- Git
- OpenSSL
- `column` and `hexdump` commands (on Ubuntu/Debian install `bsdmainutils`)
- if using OpenSSL version 3, one of `xxd` (on Ubuntu/Debian is included with `vim`)
  or `perl` or `printf` (with %b directive) command

...and optionally:

- GnuPG - for secure configuration import/export

You also need access to the _transcrypt_ script itself. You can add it directly
to your repository, or just put it somewhere in your \$PATH:

    $ git clone https://github.com/elasticdog/transcrypt.git
    $ cd transcrypt/
    $ sudo ln -s ${PWD}/transcrypt /usr/local/bin/transcrypt

#### Installation via Packages

A number of packages are available for installing transcrypt directly on your
system via its native package manager. Some of these packages also include man
page documentation as well as shell auto-completion scripts.

- Arch Linux
- Heroku (via [Buildpacks](https://devcenter.heroku.com/articles/buildpacks))
- NixOS
- OS X (via [Homebrew](http://brew.sh/))

...see the [INSTALL document](INSTALL.md) for more details.

### Initialize an Unconfigured Repository

transcrypt will interactively prompt you for the required information, all you
have to do run the script within a Git repository:

    $ cd <path-to-your-repo>/
    $ transcrypt

If you already know the values you want to use, you can specify them directly
using the command line options. Run `transcrypt --help` for more details.

### Designate a File to be Encrypted

Once a repository has been configured with transcrypt, you can designate for
files to be encrypted by applying the "crypt" filter, diff, and merge to a
[pattern](https://www.kernel.org/pub/software/scm/git/docs/gitignore.html#_pattern_format)
in the top-level _[.gitattributes](http://git-scm.com/docs/gitattributes)_
config. If that pattern matches a file in your repository, the file will be
transparently encrypted once you stage and commit it:

    $ cd <path-to-your-repo>/
    $ echo 'sensitive_file  filter=crypt diff=crypt merge=crypt' >> .gitattributes
    $ git add .gitattributes sensitive_file
    $ git commit -m 'Add encrypted version of a sensitive file'

The _.gitattributes_ file should be committed and tracked along with everything
else in your repository so clones will be aware of what is encrypted. Make sure
you don't accidentally add a pattern that would encrypt this file :-)

> For your reference, if you find the above description confusing, you'll find
> that this repository has been configured following these exact steps.

### Listing the Currently Encrypted Files

For convenience, transcrypt also adds a Git alias to allow you to list all of
the currently encrypted files in a repository:

    $ git ls-crypt
    sensitive_file

Alternatively, you can use the `--list` command line option:

    $ transcrypt --list
    sensitive_file

You can also use this to verify your _.gitattributes_ patterns when designating
new files to be encrypted, as the alias will list pattern matches as long as
everything has been staged (via `git add`).

After committing things, but before you push to a remote repository, you can
validate that files are encrypted as expected by viewing them in their raw form:

    $ git show HEAD:<path-to-file> --no-textconv

The `<path-to-file>` in the above command must be relative to the _top-level_ of
the repository. Alternatively, you can use the `--show-raw` command line option
and provide a path relative to your current directory:

    $ transcrypt --show-raw sensitive_file

### Initialize a Clone of a Configured Repository

If you have just cloned a repository containing files that are encrypted, you'll
want to configure transcrypt with the same cipher and password as the origin
repository. The owner of the origin repository can dump the credentials for you
by running the `--display` command line option:

    $ transcrypt --display
    The current repository was configured using transcrypt v0.2.0
    and has the following configuration:

      CONTEXT:  default
      CIPHER:   aes-256-cbc
      PASSWORD: correct horse battery staple

    Copy and paste the following command to initialize a cloned repository:

      transcrypt -c aes-256-cbc -p 'correct horse battery staple'

Once transcrypt has stored the matching credentials, it will force a checkout of
any exising encrypted files in order to decrypt them.

### Rekeying

Periodically, you may want to change the encryption cipher or password used to
encrypt the files in your repository. You can do that easily with transcrypt's
rekey option:

    $ transcrypt --rekey

> As a warning, rekeying will remove your ability to see historical diffs of the
> encrypted files in plain text. Changes made with the new key will still be
> visible, and you can always see the historical diffs in encrypted form by
> disabling the text conversion filters:
>
>     $ git log --patch --no-textconv

After rekeying, all clones of your repository should flush their transcrypt
credentials, fetch and merge the new encrypted files via Git, and then
re-configure transcrypt with the new credentials.

    $ transcrypt --flush-credentials
    $ git fetch origin
    $ git merge origin/main
    $ transcrypt -c aes-256-cbc -p 'the-new-password'

### Command Line Options

Completion scripts for both Bash and Zsh are included in the _contrib/_
directory.

    transcrypt [option...]

      -c, --cipher=CIPHER
             the symmetric cipher to utilize for encryption;
             defaults to aes-256-cbc

      -p, --password=PASSWORD
             the password to derive the key from;
             defaults to 30 random base64 characters

      --set-openssl-path=PATH_TO_OPENSSL
             use OpenSSL at this path; defaults to 'openssl' in $PATH

      -y, --yes
             assume yes and accept defaults for non-specified options

      -d, --display
             display the current repository's cipher and password

      -r, --rekey
             re-encrypt all encrypted files using new credentials

      -f, --flush-credentials
             remove the locally cached encryption credentials and  re-encrypt
             any files that had been previously decrypted

      -F, --force
             ignore whether the git directory is clean, proceed with the
             possibility that uncommitted changes are overwritten

      -u, --uninstall
             remove  all  transcrypt  configuration  from  the repository and
             leave files in the current working copy decrypted

       --upgrade
             uninstall and re-install transcrypt configuration in the repository
             to apply the newest scripts and .gitattributes configuration

      -l, --list
             list all of the transparently encrypted files in the repository,
             relative to the top-level directory

      -s, --show-raw=FILE
             show  the  raw file as stored in the git commit object; use this
             to check if files are encrypted as expected

      -e, --export-gpg=RECIPIENT
             export  the  repository's cipher and password to a file encrypted
             for a gpg recipient

      -i, --import-gpg=FILE
             import the password and cipher from a gpg encrypted file

      -C, --context=CONTEXT_NAME
             name for a context  with a different passphrase  and cipher from
             the  'default' context;   use this  advanced option  to  encrypt
             different files with different passphrases

      --list-contexts
             list all contexts configured in the  repository,  and warn about
             incompletely configured contexts

      -v, --version
             print the version information

      -h, --help
             view this help message

## Caveats

### Overhead

The method of using filters to selectively encrypt/decrypt files does add some
overhead to Git by regularly forking OpenSSL processes and removing Git's
ability to efficiently cache file changes. That said, it's not too different
from tracking binary files, and when used as intended, transcrypt should not
noticeably impact performance. There are much better options if your goal is to
encrypt the entire repository.

### Localhost

Note that the configuration and encryption information is stored in plain text
within the repository's _.git/config_ file. This prevents them from being
transferred to remote clones, but they are not protected from inquisitive users
on your local machine.

For safety, you may prefer to only have the credentials stored when actually
updating encrypted files, and then flush them with `--flush-credentials` once
you're done (make sure you have the credentials backed up elsewhere!). This will
also revert any decrypted files back to their encrypted form in your local
working copy.

### Cipher Selection

Last up, regarding the default cipher choice of `aes-256-cbc`...there aren't any
fantastic alternatives without pulling in outside dependencies. Ideally, we
would use an authenticated cipher mode like `id-aes256-GCM` by default, but
there are a couple of issues:

1. I'd like to support OS X out of the box, and unfortunately they are the
   lowest common denominator when it comes to OpenSSL. For whatever reason, they
   still include OpenSSL 0.9.8y rather than a newer release. Unfortunately,
   GCM-based ciphers weren't added until OpenSSL 1.0.1 (back in early 2012).

2. Even with newer versions of OpenSSL, the authenticated cipher modes
   [don't work exactly right](http://openssl.6102.n7.nabble.com/id-aes256-GCM-command-line-encrypt-decrypt-fail-td27187.html)
   when utilizing the command line `openssl enc`.

I'm contemplating if transcrypt should append an HMAC to the `aes-256-cbc`
ciphertext to provide authentication, or if we should live with the
[malleability issues](http://www.jakoblell.com/blog/2013/12/22/practical-malleability-attack-against-cbc-encrypted-luks-partitions/)
as a known limitation. Essentially, malicious comitters without the transcrypt
password could potentially manipulate the plaintext in limited ways (given that
the attacker knows the original plaintext). Honestly, I'm not sure if the added
complexity here would be worth it given transcrypt's use case.

## Advanced

### Contexts

Context names let you encrypt some files with different passwords for a
different audience, such as super-users. The 'default' context applies unless
you set a context name.

Add a context by reinitialising transcrypt with a context name then add a
pattern with crypt-<CONTEXT*NAME> attributes to *.gitattributes*. For example,
to encrypt a file \_top-secret* in a "super" context:

    # Initialise a new "super" context, and set a different password
    $ transcrypt --context=super

    # Add a pattern to .gitattributes with "crypt-super" values
    $ echo >> .gitattributes \\
      'top-secret filter=crypt-super diff=crypt-super merge=crypt-super'

    # Add and commit your top-secret and .gitattribute files
    $ git add .gitattributes top-secret
    $ git commit -m "Add top secret file for super-users only"

    # List all contexts
    $ transcrypt --list-contexts

    # Display the cipher and password for the "super" context
    $ transcrypt --context=super --display

## License

transcrypt is provided under the terms of the
[MIT License](https://en.wikipedia.org/wiki/MIT_License).

Copyright &copy; 2014-2020, [Aaron Bull Schaefer](mailto:aaron@elasticdog.com).

## Contributing

### Linting and formatting

Please use:

- the [shellcheck](https://www.shellcheck.net) tool to check for subtle bash
  scripting errors in the _transcrypt_ file, and apply the recommendations when
  possible. E.g: `shellcheck transcrypt`
- the [shfmt](https://github.com/mvdan/sh) tool to apply consistent formatting
  to the _transcrypt_ file, e.g: `shfmt -w transcrypt`
- the [Prettier](https://prettier.io) tool to apply consistent formatting to the
  _README.md_ file, e.g: `prettier --write README.md`

### Tests

Tests are written using [bats-core](https://github.com/bats-core/bats-core)
version of "Bash Automated Testing System" and stored in the _tests/_ directory.

To run the tests:

- [install bats-core](https://github.com/bats-core/bats-core#installation)
- run all tests with: `bats tests/`
- run an individual test with e.g: `bats tests/test_crypt.bats`
