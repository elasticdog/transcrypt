# Transcrypt v3 development notes

The v3 work introduces a repository-versioned settings file for public,
non-secret encryption parameters. The settings file lives at:

```text
.transcrypt/config
```

The file is intended to be committed to the repository. It must not contain
passwords or other secret material.

This initial settings reader only accepts values that match the existing legacy
encryption behavior. Later v3 changes will expand the supported settings once
PBKDF2 encryption and decryption are implemented.

Supported settings at this stage are:

```ini
[transcrypt]
format = legacy
cipher = aes-256-cbc
digest = MD5
kdf = legacy
```

Legacy repositories without this file continue to use the historical settings
stored in local Git config.
