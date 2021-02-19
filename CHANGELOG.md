# Changelog for transcrypt

All notable changes to the project will be documented in this file.

The format is based on [Keep a Changelog][1], and this project adheres to
[Semantic Versioning][2].

[1]: https://keepachangelog.com/en/1.0.0/
[2]: https://semver.org/spec/v2.0.0.html

## [Unreleased]

### Fixed

- Ensure Git index is up-to-date before checking for dirty repo, to avoid
  failures seen in CI systems where the repo seems dirty when it isn't. (#37)
- Respect Git `core.hooksPath` setting when installing the pre-commit hook. (#104)
- Zsh completion. (#107)

## [2.1.0] - 2020-09-07

This release includes features to make it easier and safer to use transcrypt, in
particular: fix merge of encrypted files with conflicts, preventing accidental
commit of plain text files by incompatible Git tools, and upgrade easily with
`--upgrade`.

### Steps to Upgrade

1. Make sure you are running the latest version of _transcrypt_:

   ```
   $ transcrypt --version
   ```

2. Upgrade a repository:

   ```
   $ transcrypt --upgrade
   ```

3. Enable the merge handling fix by adding `merge=crypt` to the end of each
   _transcrypt_ pattern in `.gitattribute`, to look like this:

   ```
   sensitive_file  filter=crypt diff=crypt merge=crypt
   ```

### Added

- Add `--upgrade` command to apply the latest transcrypt scripts in an already
  configured repository without the need to re-apply existing settings.
- Install a Git pre-commit hook to reject accidental commit of unencrypted plain
  text version of sensitive files, which could otherwise happen if a tool does
  not respect the `.gitattribute` filters Transcrypt needs to do its job.

### Changed

- Add a functional test suite built on
  [bats-core](https://github.com/bats-core/bats-core#installation).
- Apply Continuous Integration: run functional tests with GitHub Actions.
- Fix [EditorConfig](https://editorconfig.org/) file config for Markdown files.
- Add [CHANGELOG.md](CHANGELOG.md) file to make it easier to find notes about
  project changes (see also Release)

### Fixed

- Fix handling of branch merges with conflicts in encrypted files, which would
  previously leave the user to manually merge files with a mix of encrypted and
  unencrypted content. (#69, #8, #23, #67)
- Remove any cached unencrypted files from Git's object database when
  credentials are removed from a repository with a flush or uninstall, so
  sensitive file data does not remain accessible in a surprising way. (#74)
- Fix handling of sensitive files with non-ASCII file names, such as extended
  Unicode characters. (#78)
- transcrypt `--version` and `--help` commands now work when run outside a Git
  repository. (#68)
- The `--list` command now works in a repository that has not yet been init-ed.

## [2.0.0] - 2019-07-20

**\*\*\* WARNING: Re-encryption will be required when updating to version 2.0.0!
\*\*\***

This is not a security issue, but the result of a
[bug fix](https://github.com/elasticdog/transcrypt/pull/57) to ensure that the
salt generation is consistent across all operating systems. Once someone on your
team updates to version 2.0.0, it will manifest as the encrypted files in your
repository showing as _changed_. You should ensure that all users upgrade at the
same time...since `transcrypt` itself is small, it may make sense to commit the
script directly into your repo to maintain consistency moving forward.

### Steps to Re-encrypt

After you've upgraded to v2.0.0...

1. Display the current config so you can reference the command to re-initialize
   things:

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

2. Flush the credentials and re-configure the repo with the same settings as
   above:

   ```
   $ transcrypt --flush-credentials
   $ transcrypt -c aes-256-cbc -p 'correct horse battery staple'
   ```

3. Now that all of the appropriate files have been re-encrypted, add them and
   commit the changes:
   ```
   $ git add -- $(transcrypt --list)
   $ git commit --message="Re-encrypt files protected by transcrypt using new salt value"
   ```

### Changed

- Add an [EditorConfig](https://editorconfig.org/) file to help with consistency
  in formatting (#51)
- Use
  [unofficial Bash strict mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
  for safety (#53)
- Reformat files using the automated formatting tools
  [Prettier](https://prettier.io/) and [shfmt](https://github.com/mvdan/sh)
- Ensure that `transcrypt` addresses all
  [ShellCheck](https://github.com/koalaman/shellcheck) static analysis warnings

### Fixed

- Force the use of macOS's system `sed` binary to prevent errors (#50)
- Fix cross-platform compatibility by making salt generation logic consistent
  (#57)

## [1.1.0] - 2018-05-26

### Fixed

- Fix broken cipher validation safety check when running with OpenSSL v1.1.0+.
  (#48)

## [1.0.3] - 2017-08-21

### Fixed

- Explicitly set digest hash function to match default settings before OpenSSL
  v1.1.0. (#41)

## [1.0.2] - 2017-04-06

### Fixed

- Ensure realpath function does not incorrectly return the current directory for
  certain inputs. (#38)

## [1.0.1] - 2017-01-06

### Fixed

- Correct the behavior of `mktemp` when running on OS X versions 10.10 Yosemite
  and earlier.
- Prevent unexpected error output when running transcrypt outside of a Git
  repository.

## [1.0.0] - 2017-01-02

Since the v0.9.9 release, these are the notable improvements made to transcrypt:

- properly handle file names with spaces
- adjust usage of `mktemp` utility to be more cross-platform
- additional safety checks for all required cli utility dependencies

## [0.9.9] - 2016-09-05

Since the v0.9.7 release, these are the notable improvements made to transcrypt:

- support for use of a
  [wildcard](https://github.com/elasticdog/transcrypt/commit/a0b7d4ec0296e83974cb02be640747149b23ef54)
  with `--show-raw` to dump the raw commit objects for _all_ encrypted files
- GPG import/export of repository configuration
- more
  [strict filter script behavior](https://github.com/elasticdog/transcrypt/pull/29)
  to adhere to upstream recommendations
- automatic caching of the decrypted content for faster Git operations like
  `git log -p`
- ability to configure bare repositories
- ability to configure "fake bare" repositories for use through
  [vcsh](https://github.com/RichiH/vcsh)
- ability configure multiple worktrees via
  [git-workflow](https://github.com/blog/2042-git-2-5-including-multiple-worktrees-and-triangular-workflows)
- support for unencrypted archive exporting via
  [git-archive](https://git-scm.com/docs/git-archive)

## [0.9.8] - 2016-09-05

## [0.9.7] - 2015-03-23

## [0.9.6] - 2014-08-30

## [0.9.5] - 2014-08-23

## [0.9.4] - 2014-03-03

[unreleased]: https://github.com/elasticdog/transcrypt/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/elasticdog/transcrypt/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/elasticdog/transcrypt/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/elasticdog/transcrypt/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/elasticdog/transcrypt/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/elasticdog/transcrypt/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/elasticdog/transcrypt/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/elasticdog/transcrypt/compare/v0.9.9...v1.0.0
[0.9.9]: https://github.com/elasticdog/transcrypt/compare/v0.9.8...v0.9.9
[0.9.8]: https://github.com/elasticdog/transcrypt/compare/v0.9.7...v0.9.8
[0.9.7]: https://github.com/elasticdog/transcrypt/compare/v0.9.6...v0.9.7
[0.9.6]: https://github.com/elasticdog/transcrypt/compare/v0.9.5...v0.9.6
[0.9.5]: https://github.com/elasticdog/transcrypt/compare/v0.9.4...v0.9.5
[0.9.4]: https://github.com/elasticdog/transcrypt/releases/tag/v0.9.4
