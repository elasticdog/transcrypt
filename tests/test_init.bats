#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

# Custom setup: don't init transcrypt
# shellcheck disable=SC2034
SETUP_SKIP_INIT_TRANSCRYPT=1


@test "init: works at all" {
  # Use literal command not function to confirm command works at least once
  run ../transcrypt --cipher=aes-256-cbc --password=abc123 --yes
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "The repository has been successfully configured by transcrypt." ]]
}

@test "init: creates .gitattributes" {
  init_transcrypt
  [[ -f .gitattributes ]]
  run cat .gitattributes
  [[ "${lines[0]}" = "#pattern  filter=crypt diff=crypt merge=crypt" ]]
}

@test "init: creates scripts in .git/crypt/" {
  init_transcrypt
  [[ -d .git/crypt ]]
  [[ -f .git/crypt/transcrypt ]]
}

@test "init: applies git config" {
  init_transcrypt
  VERSION=$(../transcrypt -v | awk '{print $2}')

  [[ "$(git config --get transcrypt.version)" = "$VERSION" ]]
  [[ "$(git config --get transcrypt.cipher)" = "aes-256-cbc" ]]
  [[ "$(git config --get transcrypt.password)" = "abc123" ]]

  # Use --git-common-dir if available (Git post Nov 2014) otherwise --git-dir
  # shellcheck disable=SC2016
  if [[ -d $(git rev-parse --git-common-dir) ]]; then
    [[ "$(git config --get filter.crypt.clean)" = '"$(git rev-parse --git-common-dir)"/crypt/transcrypt clean %f' ]]
    [[ "$(git config --get filter.crypt.smudge)" = '"$(git rev-parse --git-common-dir)"/crypt/transcrypt smudge' ]]
    [[ "$(git config --get diff.crypt.textconv)" = '"$(git rev-parse --git-common-dir)"/crypt/transcrypt textconv' ]]
  else
    [[ "$(git config --get filter.crypt.clean)" = '"$(git rev-parse --git-dir)"/crypt/transcrypt clean %f' ]]
    [[ "$(git config --get filter.crypt.smudge)" = '"$(git rev-parse --git-dir)"/crypt/transcrypt smudge' ]]
    [[ "$(git config --get diff.crypt.textconv)" = '"$(git rev-parse --git-dir)"/crypt/transcrypt textconv' ]]
  fi

  [[ "$(git config --get filter.crypt.required)" = "true" ]]
  [[ "$(git config --get diff.crypt.cachetextconv)" = "true" ]]
  [[ "$(git config --get diff.crypt.binary)" = "true" ]]
  [[ "$(git config --get merge.renormalize)" = "true" ]]

  [[ "$(git config --get alias.ls-crypt)" = "!git -c core.quotePath=false ls-files | git -c core.quotePath=false check-attr --stdin filter | awk 'BEGIN { FS = \":\" }; /crypt$/{ print \$1 }'" ]]
}

@test "init: show details for --display" {
  init_transcrypt
  VERSION=$(../transcrypt -v | awk '{print $2}')

  run ../transcrypt --display
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "The current repository was configured using transcrypt version $VERSION" ]]
  [[ "${lines[5]}" = "  CIPHER:   aes-256-cbc" ]]
  [[ "${lines[6]}" = "  PASSWORD: abc123" ]]
  [[ "${lines[8]}" = "  transcrypt -c aes-256-cbc -p 'abc123'" ]]
}

@test "init: show details for -d" {
  init_transcrypt
  VERSION=$(../transcrypt -v | awk '{print $2}')

  run ../transcrypt -d
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "The current repository was configured using transcrypt version $VERSION" ]]
  [[ "${lines[5]}" = "  CIPHER:   aes-256-cbc" ]]
  [[ "${lines[6]}" = "  PASSWORD: abc123" ]]
  [[ "${lines[8]}" = "  transcrypt -c aes-256-cbc -p 'abc123'" ]]
}

@test "init: respects core.hooksPath setting" {
  git config core.hooksPath ".git/myhooks"
  [[ "$(git config --get core.hooksPath)" = '.git/myhooks' ]]

  init_transcrypt
  [[ -d .git/myhooks ]]
  [[ -f .git/myhooks/pre-commit ]]

  VERSION=$(../transcrypt -v | awk '{print $2}')
  run ../transcrypt --display
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "The current repository was configured using transcrypt version $VERSION" ]]
  [[ "${lines[5]}" = "  CIPHER:   aes-256-cbc" ]]
  [[ "${lines[6]}" = "  PASSWORD: abc123" ]]
  [[ "${lines[8]}" = "  transcrypt -c aes-256-cbc -p 'abc123'" ]]
}

@test "init: transcrypt.openssl-path config setting defaults to 'openssl'" {
  init_transcrypt
  [[ "$(git config --get transcrypt.openssl-path)" = 'openssl' ]]
}

@test "init: --set-openssl-path changes transcrypt.openssl-path" {
  init_transcrypt
  [[ "$(git config --get transcrypt.openssl-path)" = 'openssl' ]]
}

@test "init: --set-openssl-path is applied during init" {
  init_transcrypt
  run ../transcrypt --set-openssl-path=/test/path
  [[ "$(git config --get transcrypt.openssl-path)" = "/test/path" ]]
}

@test "init: --set-openssl-path is applied during upgrade" {
  init_transcrypt
  [[ "$(git config --get transcrypt.openssl-path)" = 'openssl' ]]

  # Set openssl path
  FULL_OPENSSL_PATH=$(which openssl)

  "$BATS_TEST_DIRNAME"/../transcrypt --upgrade --yes --set-openssl-path="$FULL_OPENSSL_PATH"
  [[ "$(git config --get transcrypt.openssl-path)" = "$FULL_OPENSSL_PATH" ]]
  [[ ! "$(git config --get transcrypt.openssl-path)" = 'openssl' ]]
}

@test "init: transcrypt.openssl-path config setting is retained with --upgrade" {
  init_transcrypt
  [[ "$(git config --get transcrypt.openssl-path)" = 'openssl' ]]

  # Set openssl path
  FULL_OPENSSL_PATH=$(which openssl)
  run ../transcrypt --set-openssl-path="$FULL_OPENSSL_PATH"''

  # Retain transcrypt.openssl-path config setting on upgrade
  "$BATS_TEST_DIRNAME"/../transcrypt --upgrade --yes
  [[ "$(git config --get transcrypt.openssl-path)" = "$FULL_OPENSSL_PATH" ]]
  [[ ! "$(git config --get transcrypt.openssl-path)" = 'openssl' ]]
}

@test "init: transcrypt.crypt-dir config setting is applied during init" {
  # Set a custom location for the crypt/ directory
  git config transcrypt.crypt-dir /tmp/crypt

  init_transcrypt

  # Confirm crypt/ directory is populated in custom location
  [[ ! -d .git/crypt ]]
  [[ ! -f .git/crypt/transcrypt ]]
  [[ -d /tmp/crypt ]]
  [[ -f /tmp/crypt/transcrypt ]]
}

@test "crypt: transcrypt.crypt-dir config setting produces working scripts" {
  # Set a custom location for the crypt/ directory
  git config transcrypt.crypt-dir /tmp/crypt

  init_transcrypt

  SECRET_CONTENT="My secret content"
  SECRET_CONTENT_ENC="U2FsdGVkX1/kkWK36bn3fbq5DY2d+JXL2YWoN/eoXA1XJZEk9JS7j/856rXK9gPn"

  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  run cat sensitive_file
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "$SECRET_CONTENT" ]]

  run ../transcrypt --show-raw sensitive_file
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "==> sensitive_file <==" ]]
  [[ "${lines[1]}" = "$SECRET_CONTENT_ENC" ]]
}
