transcrypt
==========

A script to configure transparent encryption of sensitive files stored in
a Git repository. Files that you choose will be automatically encrypted when
you commit them, and automatically decrypted when you check them out. The
process will degrade gracefully, so even people without your encryption
password can safely commit changes to the repository's non-encrypted files.

transcrypt protects your data when it's pushed to remotes that you may not
directly control (e.g., GitHub, Dropbox clones, etc.), while still allowing
you to work normally on your local working copy. You can conveniently store
things like passwords and private keys within your repository and not have to
share them with your entire team or complicate your workflow.

Overview
--------

transcrypt is in the same vein as existing projects like
[git-crypt](https://github.com/AGWA/git-crypt) and
[git-encrypt](https://github.com/shadowhand/git-encrypt), which follow Git's
documentation regarding the use of clean/smudge filters for encryption.
In comparison to those other projects, transcrypt makes substantial
improvements in the areas of usability and safety.

* transcrypt is just a Bash script and does not require compilation
* transcrypt uses OpenSSL's symmetric cipher routines rather then implementing its own crypto
* transcrypt does not have to remain installed after the initial repository configuration
* transcrypt generates a unique salt for each encrypted file
* transcrypt uses safety checks to avoid clobbering or duplicating configuration data
* transcrypt facilitates setting up additional clones as well as rekeying
* transcrypt adds an alias `git ls-crypt` to list all encrypted files

### Salt Generation

The _decryption -> encryption_ process on an unchanged file must be
deterministic for everything to work transparently. To do that, the same salt
must be used each time we encrypt the same file. Rather than use a static salt
common to all files, transcrypt takes a SHA-256 cryptographic hash of each
file when it's decrypted, and then uses the last 16 bytes of that hash for the
file's unique salt. When the content of the file changes, so does the salt.

Usage
-----

The requirements to run transcrypt are minimal:

* Bash
* Git
* OpenSSL

You also need access to the _transcrypt_ script itself. You can add it
directly to your repository, or just put it somewhere in your $PATH:

    $ git clone https://github.com/elasticdog/transcrypt.git
    $ cd transcrypt/
    $ sudo ln -s ${PWD}/transcrypt /usr/local/bin/transcrypt

### Initialize an Unconfigured Repository

transcrypt will interactively prompt you for the required information, all you
have to do run the script within a Git repository:

    $ cd <path-to-your-repo>/
    $ transcrypt

If you already know the values you want to use, you can specify them directly
using the command line options. Run `transcrypt --help` for more details.

### Designate a File to be Encrypted

Once a repository has been configured with transcrypt, you can designate
for files to be encrypted by applying the "crypt" filter and diff to a
[pattern](https://www.kernel.org/pub/software/scm/git/docs/gitignore.html#_pattern_format)
in the top-level _[.gitattributes](http://git-scm.com/docs/gitattributes)_
config. If that pattern matches a file in your repository, the file will
be transparently encrypted once you stage and commit it:

    $ cd <path-to-your-repo>/
    $ echo 'sensitive_file  filter=crypt diff=crypt' >> .gitattributes
    $ git add .gitattributes sensitive_file
    $ git commit -m 'Add encrypted version of a sensitive file'

The _.gitattributes_ file should be committed and tracked along with
everything else in your repository so clones will be aware of what is
encrypted. Make sure you don't accidentally add a pattern that would encrypt
this file :-)

> For your reference, if you find the above description confusing, you'll find
> that this repository has been configured following these exact steps.

### Initialize a Clone of a Configured Repository

If you have just cloned a repository containing files that are encrypted,
you'll want to configure transcrypt with the same cipher and password as the
origin repository. The owner of the origin repository can dump the credentials for you
by running the `--display` command line option:

    $ transcrypt --display
    The current repository was configured using transcrypt v0.2.0
    and has the following configuration:

      CIPHER:   aes-256-cbc
      PASSWORD: correct horse battery staple

    Copy and paste the following command to initialize a cloned repository:

      transcrypt -c aes-256-cbc -p 'correct horse battery staple'

Once transcrypt has stored the matching credentials, it will force a checkout
of any exising encrypted files in order to decrypt them.

### Rekeying

Periodically, you may want to change the encryption cipher or password
used to encrypt the files in your repository. You can do that easily with
transcrypt's rekey option:

    $ transcrypt --rekey

> As a warning, rekeying will remove your ability to see historical diffs
> of the encrypted files in plain text. Changes made with the new key will
> still be visible, and you can always see the historical diffs in
> encrypted form by disabling the text conversion filters:
>
>     $ git log --patch --no-textconv

After rekeying, all clones of your repository should flush their
transcrypt credentials, fetch and merge the new encrypted files via Git,
and then re-configure transcrypt with the new credentials.

    $ transcrypt --flush-credentials
    $ git fetch origin
    $ git merge origin/master
    $ transcrypt -c aes-256-cbc -p 'the-new-password'

### Command Line Options

    transcrypt [option...]

      -p, --password=PASSWORD
           the password to derive the key from;
           defaults to 30 random base64 characters

      -c, --cipher=CIPHER
           the symmetric cipher to utilize for encryption;
           defaults to aes-256-cbc

      -y, --yes
           assume yes and accept defaults for non-specified options

      -d, --display
           display the current repository's cipher and password

      -r, --rekey
           re-encrypt all encrypted files using new credentials

      -f, --flush-credentials
           remove the locally cached encryption credentials
           and re-encrypt any files that had been previously decrypted

      -u, --uninstall
           remove all transcrypt configuration from the repository
           and leave files in the current working copy decrypted

      -v, --version
           print the version information

      -h, --help
           view the help message

Caveats
-------

The method of using filters to selectively encrypt/decrypt files does add some
overhead to Git by regularly forking OpenSSL processes and removing Git's
ability to efficiently cache file changes. That said, it's not too different
from tracking binary files, and when used as intended, transcrypt should not
noticeably impact performance. There are much better options if your goal is
to encrypt the entire repository.

Note that the configuration and encryption information is stored in plain
text within the repository's _.git/config_ file. This prevents them from
being transferred to remote clones, but they are not protected from
inquisitive users on your local machine.

License
-------

transcrypt is provided under the terms of the
[MIT License](https://en.wikipedia.org/wiki/MIT_License).

Copyright &copy; 2014, [Aaron Bull Schaefer](mailto:aaron@elasticdog.com).
