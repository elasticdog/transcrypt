#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

# Custom setup: don't init transcrypt
# shellcheck disable=SC2034
SETUP_SKIP_INIT_TRANSCRYPT=1


@test "init: works at all" {
  # Use literal command not function to confirm command works at least once
  run ../transcrypt --cipher=aes-256-cbc --password='abc 123' --yes
  [ "$status" -eq 0 ]
  [[ "${output}" = *"The repository has been successfully configured by transcrypt."* ]]
}

@test "init: creates .gitattributes" {
  init_transcrypt
  [ -f .gitattributes ]
  run cat .gitattributes
  [ "${lines[0]}" = "#pattern  filter=crypt diff=crypt merge=crypt" ]
}

@test "init: creates scripts in .git/crypt/" {
  init_transcrypt
  [ -d .git/crypt ]
  [ -f .git/crypt/transcrypt ]
}

@test "init: applies git config" {
  init_transcrypt
  VERSION=$(../transcrypt -v | awk '{print $2}')

  [ "$(git config --get transcrypt.version)" = "$VERSION" ]
  [ "$(git config --get transcrypt.cipher)" = "aes-256-cbc" ]
  [ "$(git config --get transcrypt.password)" = "abc 123" ]
  [ "$(git config --get transcrypt.openssl-path)" = "openssl" ]

  # Use --git-common-dir if available (Git post Nov 2014) otherwise --git-dir
  # shellcheck disable=SC2016
  [ "$(git config --get filter.crypt.clean)" = '"$(git config transcrypt.crypt-dir 2>/dev/null || printf ''%s/crypt'' ""$(git rev-parse --git-dir)"")"/transcrypt clean context=default %f' ]
  [ "$(git config --get filter.crypt.smudge)" = '"$(git config transcrypt.crypt-dir 2>/dev/null || printf ''%s/crypt'' ""$(git rev-parse --git-dir)"")"/transcrypt smudge context=default' ]
  [ "$(git config --get diff.crypt.textconv)" = '"$(git config transcrypt.crypt-dir 2>/dev/null || printf ''%s/crypt'' ""$(git rev-parse --git-dir)"")"/transcrypt textconv context=default' ]
  [ "$(git config --get merge.crypt.driver)" = '"$(git config transcrypt.crypt-dir 2>/dev/null || printf ''%s/crypt'' ""$(git rev-parse --git-dir)"")"/transcrypt merge context=default %O %A %B %L %P' ]

  [ "$(git config --get filter.crypt.required)" = "true" ]
  [ "$(git config --get diff.crypt.cachetextconv)" = "true" ]
  [ "$(git config --get diff.crypt.binary)" = "true" ]
  [ "$(git config --get merge.renormalize)" = "true" ]
  [ "$(git config --get merge.crypt.name)" = "Merge transcrypt secret files" ]

  [ "$(git config --get alias.ls-crypt)" = '!"$(git config transcrypt.crypt-dir 2>/dev/null || printf %s/crypt ""$(git rev-parse --git-dir)"")"/transcrypt --list' ]

  [ "$(git config --get alias.add-crypt)" = '!"$(git config transcrypt.crypt-dir 2>/dev/null || printf %s/crypt ""$(git rev-parse --git-dir)"")"/transcrypt --add' ]
}

@test "init: show details for --display" {
  init_transcrypt
  VERSION=$(../transcrypt -v | awk '{print $2}')

  run ../transcrypt --display
  [ "$status" -eq 0 ]
  [[ "${output}" = *"The current repository was configured using transcrypt version $VERSION"* ]]
  [[ "${output}" = *"  CIPHER:   aes-256-cbc"* ]]
  [[ "${output}" = *"  PASSWORD: abc 123"* ]]
  [[ "${output}" = *"  transcrypt -c aes-256-cbc -p 'abc 123'"* ]]
}

@test "init: show details for -d" {
  init_transcrypt
  VERSION=$(../transcrypt -v | awk '{print $2}')

  run ../transcrypt -d
  [ "$status" -eq 0 ]
  [[ "${output}" = *"The current repository was configured using transcrypt version $VERSION"* ]]
  [[ "${output}" = *"  CIPHER:   aes-256-cbc"* ]]
  [[ "${output}" = *"  PASSWORD: abc 123"* ]]
  [[ "${output}" = *"  transcrypt -c aes-256-cbc -p 'abc 123'"* ]]
}

@test "init: respects core.hooksPath setting" {
  git config core.hooksPath ".git/myhooks"
  [ "$(git config --get core.hooksPath)" = '.git/myhooks' ]

  init_transcrypt
  [ -d .git/myhooks ]
  [ -f .git/myhooks/pre-commit ]

  VERSION=$(../transcrypt -v | awk '{print $2}')
  run ../transcrypt --display
  [ "$status" -eq 0 ]
  [[ "${output}" = *"The current repository was configured using transcrypt version $VERSION"* ]]
  [[ "${output}" = *"  CIPHER:   aes-256-cbc"* ]]
  [[ "${output}" = *"  PASSWORD: abc 123"* ]]
  [[ "${output}" = *"  transcrypt -c aes-256-cbc -p 'abc 123'"* ]]
}

@test "init: transcrypt.openssl-path config setting defaults to 'openssl'" {
  init_transcrypt
  [ "$(git config --get transcrypt.openssl-path)" = 'openssl' ]
}

@test "init: --set-openssl-path is applied during init" {
  run ../transcrypt --cipher=aes-256-cbc --password='abc 123' --yes --set-openssl-path=/test/path
  [ "$(git config --get transcrypt.openssl-path)" = "/test/path" ]
}

@test "init: --set-openssl-path is applied during upgrade" {
  init_transcrypt
  [ "$(git config --get transcrypt.openssl-path)" = 'openssl' ]

  # Set openssl path
  FULL_OPENSSL_PATH=$(which openssl)

  run ../transcrypt --upgrade --yes --set-openssl-path="$FULL_OPENSSL_PATH"
  [ "$(git config --get transcrypt.openssl-path)" = "$FULL_OPENSSL_PATH" ]
  [ ! "$(git config --get transcrypt.openssl-path)" = 'openssl' ]
}

@test "init: transcrypt.openssl-path config setting is retained with --upgrade" {
  init_transcrypt
  [ "$(git config --get transcrypt.openssl-path)" = 'openssl' ]

  # Set openssl path
  FULL_OPENSSL_PATH=$(which openssl)
  run ../transcrypt --set-openssl-path="$FULL_OPENSSL_PATH"'' --yes

  # Retain transcrypt.openssl-path config setting on upgrade
  run ../transcrypt --upgrade --yes
  [ "$(git config --get transcrypt.openssl-path)" = "$FULL_OPENSSL_PATH" ]
  [ ! "$(git config --get transcrypt.openssl-path)" = 'openssl' ]
}

@test "init: transcrypt.crypt-dir config setting is applied during init" {
  # Clear tmp crypt/ directory, in case junk was left there from prior test runs
  rm -fR /tmp/crypt/

  # Set a custom location for the crypt/ directory
  git config transcrypt.crypt-dir /tmp/crypt

  init_transcrypt

  # Confirm crypt/ directory is populated in custom location
  [ ! -d .git/crypt ]
  [ ! -f .git/crypt/transcrypt ]
  [ -d /tmp/crypt ]
  [ -f /tmp/crypt/transcrypt ]
}

@test "crypt: transcrypt.crypt-dir config setting produces working scripts" {
  # Clear tmp crypt/ directory, in case junk was left there from prior test runs
  rm -fR /tmp/crypt/

  # Set a custom location for the crypt/ directory
  git config transcrypt.crypt-dir /tmp/crypt

  init_transcrypt

  SECRET_CONTENT="My secret content"
  SECRET_CONTENT_ENC="U2FsdGVkX1/6ilR0PmJpAyCF7iG3+k4aBwbgVd48WaQXznsg42nXbQrlWsf/qiCg"

  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  run ../transcrypt --show-raw sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "==> sensitive_file <==" ]
  [ "${lines[1]}" = "$SECRET_CONTENT_ENC" ]
}

@test "crypt: warn on incorrect password as indicated by dirty files after init" {
  init_transcrypt

  SECRET_CONTENT="My secret content"
  SECRET_CONTENT_ENC="U2FsdGVkX1/6ilR0PmJpAyCF7iG3+k4aBwbgVd48WaQXznsg42nXbQrlWsf/qiCg"

  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  # Clear the password and reset the repo
  uninstall_transcrypt
  git reset --hard

  # Init transcrypt with wrong password, command fails with error message
  run "$BATS_TEST_DIRNAME"/../transcrypt --cipher=aes-256-cbc --password='WRONG' --yes
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "transcrypt: Unexpected new dirty files in the repository when configured by transcrypt, please check your password." ]
}

@test "crypt: warn on incorrect password as indicated by dirty files after init when forced" {
  init_transcrypt

  SECRET_CONTENT="My secret content"
  SECRET_CONTENT_ENC="U2FsdGVkX1/6ilR0PmJpAyCF7iG3+k4aBwbgVd48WaQXznsg42nXbQrlWsf/qiCg"

  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  # Clear the password and reset the repo
  uninstall_transcrypt
  git reset --hard

  # Dirty repo before init, to check pre- and post-init dirty files counts
  # work despite the pre-existing dirty file
  echo "Dirty file" > dirty_file
  git add dirty_file

  # Force init transcrypt with wrong password, command fails with error message
  run "$BATS_TEST_DIRNAME"/../transcrypt --force --cipher=aes-256-cbc --password='WRONG' --yes
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "transcrypt: Unexpected new dirty files in the repository when configured by transcrypt, please check your password." ]

  rm dirty_file
}
