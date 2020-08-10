# Changelog

This is a summary of transcrypt releases, dates, and key changes.

See also https://github.com/elasticdog/transcrypt/releases

## transcrypt v2.0.0 (20 Jul 2019)

**\*\*\* WARNING: Re-encryption will be required when updating to version 2.0.0! \*\*\***

This is not a security issue, but the result of a [bug fix](https://github.com/elasticdog/transcrypt/pull/57) to ensure that the salt generation is consistent across all operating systems. Once someone on your team updates to version 2.0.0, it will manifest as the encrypted files in your repository showing as _changed_. You should ensure that all users upgrade at the same time...since `transcrypt` itself is small, it may make sense to commit the script directly into your repo to maintain consistency moving forward.

## Steps to Re-encrypt

After you've upgraded to v2.0.0...

1. Display the current config so you can reference the command to re-initialize things:

   ```
   $ transcrypt --display
   The current repository was configured using transcrypt version 1.1.0
   and has the following configuration:

     GIT_WORK_TREE:  /home/elasticdog/src/transcrypt
     GIT_DIR:        /home/elasticdog/src/transcrypt/.git
     GIT_ATTRIBUTES: /home/elasticdog/src/transcrypt/.gitattributes

     CIPHER:   aes-256-cbc
     PASSWORD: correct horse battery staple

   Copy and paste the following command to initialize a cloned repository:

     transcrypt -c aes-256-cbc -p 'correct horse battery staple'
   ```

2. Flush the credentials and re-configure the repo with the same settings as above:

   ```
   $ transcrypt --flush-credentials
   $ transcrypt -c aes-256-cbc -p 'correct horse battery staple'
   ```

3. Now that all of the appropriate files have been re-encrypted, add them and commit the changes:
   ```
   $ git add -- $(transcrypt --list)
   $ git commit --message="Re-encrypt files protected by transcrypt using new salt value"
   ```

### Fixed

- Force the use of macOS's system `sed` binary to prevent errors (#50)
- Fix cross-platform compatibility by making salt generation logic consistent (#57)

### Changed

- Add an [EditorConfig](https://editorconfig.org/) file to help with consistency in formatting (#51)
- Use [unofficial Bash strict mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/) for safety (#53)
- Reformat files using the automated formatting tools [Prettier](https://prettier.io/) and [shfmt](https://github.com/mvdan/sh)
- Ensure that `transcrypt` addresses all [ShellCheck](https://github.com/koalaman/shellcheck) static analysis warnings

## transcrypt v1.1.0 (26 May 2018)

### Fixed

- Fix broken cipher validation safety check when running with OpenSSL v1.1.0+. (#48)

## transcrypt v1.0.3 (21 Aug 2017)

### Fixed

- Explicitly set digest hash function to match default settings before OpenSSL v1.1.0. (#41)

## transcrypt v1.0.2 (6 Apr 2017)

### Fixed

- Ensure realpath function does not incorrectly return the current directory for certain inputs. (#38)

## transcrypt v1.0.1 (6 Jan 2017)

### Fixed

- Correct the behavior of `mktemp` when running on OS X versions 10.10 Yosemite and earlier.
- Prevent unexpected error output when running transcrypt outside of a Git repository.

## transcrypt v1.0.0 (2 Jan 2017)

Since the v0.9.9 release, these are the notable improvements made to transcrypt:

- properly handle file names with spaces
- adjust usage of `mktemp` utility to be more cross-platform
- additional safety checks for all required cli utility dependencies

## transcrypt v0.9.9 (5 Sep 2016)

Since the v0.9.7 release, these are the notable improvements made to transcrypt:

- support for use of a [wildcard](https://github.com/elasticdog/transcrypt/commit/a0b7d4ec0296e83974cb02be640747149b23ef54) with `--show-raw` to dump the raw commit objects for _all_ encrypted files
- GPG import/export of repository configuration
- more [strict filter script behavior](https://github.com/elasticdog/transcrypt/pull/29) to adhere to upstream recommendations
- automatic caching of the decrypted content for faster Git operations like `git log -p`
- ability to configure bare repositories
- ability to configure "fake bare" repositories for use through [vcsh](https://github.com/RichiH/vcsh)
- ability configure multiple worktrees via [git-workflow](https://github.com/blog/2042-git-2-5-including-multiple-worktrees-and-triangular-workflows)
- support for unencrypted archive exporting via [git-archive](https://git-scm.com/docs/git-archive)

## transcrypt v0.9.8 (5 Sep 2016)

## transcrypt v0.9.7 ( 23 Mar 2015)

## transcrypt v0.9.6 (30 Aug 2014 )

## transcrypt v0.9.5 (23 Aug 2014)

## transcrypt v0.9.4 (3 Mar 2014)
