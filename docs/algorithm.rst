The Transcrypt Algorithm
========================

The transcrypt algorithm makes use of the following components:

* `git <https://en.wikipedia.org/wiki/Git>_`
* `bash <https://en.wikipedia.org/wiki/Bash_(Unix_shell)>_`
* `openssl <https://en.wikipedia.org/wiki/OpenSSL>_`

The "clean" and "smudge" git filters implement the core functionality by
encrypting a sensitive file before committing it to the repo history, and
decrypting the file when a local copy of the file is checked out. 

* `filter.crypt.clean` - "transcrypt clean"  

* `filter.crypt.smudge` - "transcrypt smudge"  


Transcrypt uses openssl for all underlying cryptographic operations. 

From git's perspective, is only tracks the encrypted ciphertext of each file.
Thus is it important that any encryption algorithm used must be deterministic,
otherwise changes in the ciphertext (e.g. due to randomized salt) will cause
git to think the file has changed when it hasn't.


Core Algorithms
===============

From a high level, lets assume we have a secure process to save / load a
desired configuration.


The Encryption Process
----------------------

A file is encrypted via the following procedure in the ``filter.crypt.clean`` filter.

Given a sensitive file specified by ``filename``

1. Empty files are ignored

2. A temporary file is created with the (typically plaintext) contents of ``filename``.
   This file only contains user read/write permissions (i.e. 600).
   A bash trap is set such that this file is removed when transcrypt exists.  

2. The first 6 bytes of the file are checked. If they are "U2FsdGVk" (which is
   indicative of a salted openssl encrypted file, we assume the file is already
   encrypted emit it as-is)

3. Otherwise the transcrypt configuration is loaded (which defines the cipher,
   digest, key derivation function, salt, and password), openssl is called to 
   encrypt the plaintext, and the base64 ciphertext is emitted and passed to git.

The following is the openssl invocation used in encryption

.. code:: bash 

    ENC_PASS=$password openssl enc "-${cipher}" -md "${digest}" -pass env:ENC_PASS -e -a -S "$salt" "${pbkdf2_args[@]}"


Note: For OpenSSL V3.x, which does not prepend the salt to the ciphertext, we
manually prepend the raw salt bytes to the raw openssl output (without ``-a``
for base64 encoding) and then perform base64 encoding of the concatenated text
as a secondary task. This makes the output from version 3.x match outputs from
the 1.x openssl releases. (Also note: this is now independently patched in
https://github.com/elasticdog/transcrypt/pull/135)
   

The Decryption Process
----------------------

When a sensitive file is checked out, it is first decrypted before being placed
in the user's working branch via the ``filter.crypt.smudge`` filter.

1. The ciphertext is passed to the smudge filter via stdin.

2. The transcrypt configuration is loaded.

3. The ciphertext is decrypted using openssl and emitted via stdout. If
   decryption fails the ciphertext itself is emitted via stdout.


The following invocation is used for decryption

.. code:: bash 

    # used to decrypt a file. the cipher, digest, password, and key derivation
    # function must be known in advance. the salt is always prepended to the
    # file ciphertext, and ready by openssl, so it does not need to be supplied here.
    ENC_PASS=$password openssl enc "-${cipher}" -md "${digest}" -pass env:ENC_PASS "${pbkdf2_args[@]}" -d -a


Configuration
=============

Loading the configuration is a critical subroutine in the core transcrypt
components.

In the proposed transcrypt 3.x implementation, the following *bash* variables
are required for encryption and decryption:

* ``cipher``
* ``password``
* ``digest``
* ``pbkdf2_args``
 

And additionally, encryption needs the variable:

* ``salt``

Cipher, Password, and Digest
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For the first 3 variables ``cipher``, ``password``, and ``digest`` the method
transcrypt uses to store them is straightforward. In the local ``.git/config``
directory these passwords are stored as checkout-specific git variables stored
in plaintext.

* ``transcrypt.cipher``
* ``transcrypt.digest``
* ``transcrypt.password``

Note, that before transcrypt 3.x only cipher and password were configurable.
Legacy behavior of transcrypt is described by assuming digest is MD5. 

The other two variables ``pbkdf2_args`` and ``salt`` are less straight forward.


PBKDF2
~~~~~~

The `PBKDF2`_ (Password Based Key Derivation Function v2) adds protection
against brute force attacks by increasing the amount of time it takes to derive
the actual key and iv values used in the encryption / decryption process.

.. _PBKDF2: https://en.wikipedia.org/wiki/PBKDF2

OpenSSL enables ``pbkdf2`` if the ``-pbkdf2`` flag is specified. 
To coerce this into a key-value configuration scheme we use the git
configuration variable

* ``transcrypt.use-pbkdf2``

Which can be set to 0 or 1. At configuration load time, depending on the value
in the config transcrypt will set ``pbkdf2_args`` to an empty bash array in the
case where pbkdf2 is disabled, and ``-pbkdf2`` otherwise. This allows us to use
bash array syntax to express both variants as a single openssl command.

The backwards compatible setting for transcrypt < 3.x is ``--use-pbkdf2=0``.

See Also: 

PKCS5#5.2 (RFC-2898) 
https://datatracker.ietf.org/doc/html/rfc2898#section-5.2

Salt
~~~~

Lastly, there is ``salt``, which the least straightforward of these options.

Ideally, when using openssl, a unique and random salt is generated **each
time** the file is encrypted. This prevents an attacker from executing a
known-plaintext attack by pre-computing common password / ciphertext pairs on
small files and being able to determine the user's password if any of the
precomputed ciphertexts exist in the repo.

However, transcrypt is unable to use a random salt, because it requires
encryption to be a deterministic process. Otherwise, git would always see a
changed file every time the "clean" command was executed.

Transcrypt therefore defines two strategies to generate a deterministic salt:

1. The "password" salt method.
2. The "configured" salt method.

The first method is equivalent to the existing process in transcrypt 2.x.
The second method is a new more secure variant, but will rely on a new
"versioned config" that we will discuss in 
:ref:`the configuration storage section <ConfigStorage>`.

The two salt methods are very similar. In both cases, a unique 32-byte salt is
generated for each file via the following invocation: 

.. code:: bash 

    # Used to compute salt for a specific file using "extra-salt" that can be supplied in one of several ways
    openssl dgst -hmac "${filename}:${extra_salt}" -sha256 "$filename" | tr -d '\r\n' | tail -c 16

This salt is based on the name of the file, its sha256 hash, and something
called "extra-salt", which is determined by the user's choice of
``transcrypt.salt-method``. 

In the case where ``transcrypt.salt-method=password``, the "extra-salt" is set
to the user's plaintext password. This exactly mimics the behavior of
transcrypt 2.x and is used as the default to provide backwards compatibility.

However, as discussed in 
`#55 <https://github.com/elasticdog/transcrypt/issues/55>_`, this introduces a
security weakness that weakens the extra security provided the use of
``-pbkdf2``. Thus transcrypt 3.x introduces a new "configured" method.

In the case where ``transcrypt.salt-method=configured``, the implementation
will check if a special configuration variable ``transcrypt.config-salt`` is
set, and if not, it will set it to a random 32 character hex string, and check
the choice of that value into the repo. Then the value of
``transcrypt.config-salt`` will be used as "extra-salt". The value of
``transcrypt.config-salt`` is randomized every time the user changes their
password. We note that this method this method does provide less entropy than
randomly choosing the salt on each encryption cycle, but we are unaware of 
any security concerns that arise from this method.

Note: this method could be further improved by generated a randomized
config-salt for each file that is modified when the file itself is modified.
Such a scheme should exactly match the entropy of the openssl default
randomized salt method.  However, due to the added implementation complexity
and unclear security benefits we defer that to future work.

See Also:

PKCS5#4.1 (RFC-2898) https://datatracker.ietf.org/doc/html/rfc2898#section-4.1

.. _ConfigStorage:

Configuration Storage
---------------------

In transcrypt 2.x, there are currently two ways to store a configuration
containing credentials and 

1. The unversioned config. 
2. The GPG-exported config.

Method 1 stores the configuration in the ``[transcrypt]`` section of the local
``.git/config`` file.  This is the primary location for the configuration and
it is typically populated via specifying all settings either via an interactive
process or through non-interactive command line invocation. Whenever transcrypt
is invoked, any needed configuration variable is read from this plaintext file
using git's versatile configuration tool.

Method 2 is used exclusively for securely transporting configurations between
machines or authorized users. The ``[transcrypt]`` section of an existing
primary configuration in the ``.git/config`` is exported into a simple new line
separated key/value store format, and then encrypted for a specific GPG user.
This encrypted file can be sent to the target recipient. They can then use
transcrypt to "import" the file, which uses 
`GPG <https://en.wikipedia.org/wiki/GNU_Privacy_Guard>_` to decrypt the file and
populate their local unversioned ``.git/config`` file. 

In Transcrypt 3.x we propose a third configuration method:

3. The versioned config.

Method 3 will store the non-sensitive subset of configuration settings
(everything but ``transcrypt.password``) in a versioned ``.transcrypt/config``
file using the same git configuration system as Method 1.

The motivation for this is twofold. 

First, the new deterministic salt method requires a way of storing randomly
sampled bits for the salt (in the ``transcrypt.config-salt`` variable) that are
decorrelated from sensitive information (i.e. the password and contents of
decrypted files).

Second, transcrypt 3.x adds 4 new parameters that a user will need to
configure. By storing these parameters in the repo itself it will ease the
burden of decrypting a fresh clone of a repo.

Using this versioned config for everything but ``transcrypt.config-salt`` is
completely optional (and using ``transcrypt.config-salt`` is not needed if
``transcrypt.salt-method=password``, although that is not recommended). Thus
the user can still choose to keep the chosen cipher, digest, and use of pbkdf2
a secret if they desire (although we will remind the reader that 
`security by obscurity <https://en.wikipedia.org/wiki/Security_through_obscurity>_` 
should never be relied on).

NOTE: Currently, as of 2022-05-09, the current implementation of transcrypt 3.x
does not implement the ability for ``.transcrypt/config`` to store any config
variable other than ``transcrypt.config-salt``. We will wait for this proposal
to be reviewed because the design of the priority in which configuration
variables are stored is is currently an open question in the mind of the
author. However, proposed example *behavior* is as follows:

Case Study and Open Questions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Given: A fresh clone of a repo without a ``.transcrypt/config`` file.

The user invokes ``transcrypt`` and is prompted for all 6 configuration variables.

These are stored to the primary ``.git/config`` file, except for
``transcrypt.config-salt``, which --- if the salt method is "configured" --- is
always stored in ``.git/transcrypt`` and checked into the repo. The user is notified 
that transcrypt used ``git add`` to stage this file, and instructs the user to commit 
the file (transcrypt never invokes the ``git commit`` command). 

Proposal: The user is additionally prompted if they want to add the
non-sensitive configuration to the versioned config. This prompt can be skipped
by specifying ``--versioned=1`` or ``--versioned=0``. In the unversioned case,
the process proceeded as-is, otherwise the non-sensitive configuration is written 
to ``.transcrypt/config`` **instead of** being written to ``.git/config``. 

Open Question: When non-sensitive configuration variables are written, should they be:

1. Written only to ``.transcrypt/config`` and not ``.git/config``?
2. Written to both ``.transcrypt/config`` and ``.git/config``?
3. Written only to ``.transcrypt/config`` and ensured they are removed from ``.git/config``?

Because all of these configuration files are plain-text and editable we have to
consider the precedence of config settings when loading. The current proposal
is to always look at ``.git/config`` first and then fallback to
``.transcrypt/config``.

Open Question: When we read a variable from ``.git/config`` and it disagrees
with ``.transcrypt/config`` do we "fix" ``.transcrypt/config``, warn, or ignore
it. My current proposal is to ignore it and rely on documented precedence
rules.
