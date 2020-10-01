#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

# Custom setup: don't init transcrypt
# shellcheck disable=SC2034
SETUP_SKIP_INIT_TRANSCRYPT=1


@test "init: works at all" {
  # Use literal command not function to confirm command works at least once
  run "$BATS_TEST_DIRNAME"/../transcrypt --cipher=aes-256-cbc --password=abc123 --yes
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
  [[ -f .git/crypt/clean ]]
  [[ -f .git/crypt/smudge ]]
  [[ -f .git/crypt/textconv ]]
}

@test "init: applies git config" {
  init_transcrypt
  VERSION=$("$BATS_TEST_DIRNAME"/../transcrypt -v | awk '{print $2}')

  [[ "$(git config --get transcrypt.version)" = "$VERSION" ]]
  [[ "$(git config --get transcrypt.cipher)" = "aes-256-cbc" ]]
  [[ "$(git config --get transcrypt.password)" = "abc123" ]]

  # Use --git-common-dir if available (Git post Nov 2014) otherwise --git-dir
  # shellcheck disable=SC2016
  if [[ -d $(git rev-parse --git-common-dir) ]]; then
    [[ "$(git config --get filter.crypt.clean)" = '"$(git rev-parse --git-common-dir)"/crypt/clean %f' ]]
    [[ "$(git config --get filter.crypt.smudge)" = '"$(git rev-parse --git-common-dir)"/crypt/smudge %f' ]]
    [[ "$(git config --get diff.crypt.textconv)" = '"$(git rev-parse --git-common-dir)"/crypt/textconv' ]]
    [[ "$(git config --get merge.crypt.driver)" = '"$(git rev-parse --git-common-dir)"/crypt/merge %O %A %B %L %P' ]]
  else
    [[ "$(git config --get filter.crypt.clean)" = '"$(git rev-parse --git-dir)"/crypt/clean %f' ]]
    [[ "$(git config --get filter.crypt.smudge)" = '"$(git rev-parse --git-dir)"/crypt/smudge %f' ]]
    [[ "$(git config --get diff.crypt.textconv)" = '"$(git rev-parse --git-dir)"/crypt/textconv' ]]
    [[ "$(git config --get merge.crypt.driver)" = '"$(git rev-parse --git-dir)"/crypt/merge %O %A %B %L %P' ]]
  fi

  [[ "$(git config --get filter.crypt.required)" = "true" ]]
  [[ "$(git config --get diff.crypt.cachetextconv)" = "true" ]]
  [[ "$(git config --get diff.crypt.binary)" = "true" ]]
  [[ "$(git config --get merge.renormalize)" = "true" ]]

  [[ "$(git config --get alias.ls-crypt)" = "!git -c core.quotePath=false ls-files | git -c core.quotePath=false check-attr --stdin filter | awk 'BEGIN { FS = \":\" }; / crypt$/{ print \$1 }'" ]]
}

@test "init: show details for --display" {
  init_transcrypt
  VERSION=$("$BATS_TEST_DIRNAME"/../transcrypt -v | awk '{print $2}')

  run "$BATS_TEST_DIRNAME"/../transcrypt --display
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "The current repository was configured using transcrypt version $VERSION" ]]
  [[ "${lines[5]}" = "  CONTEXT:  default" ]]
  [[ "${lines[6]}" = "  CIPHER:   aes-256-cbc" ]]
  [[ "${lines[7]}" = "  PASSWORD: abc123" ]]
  [[ "${lines[9]}" = "  transcrypt -c aes-256-cbc -p 'abc123'" ]]
}

@test "init: show details for -d" {
  init_transcrypt
  VERSION=$("$BATS_TEST_DIRNAME"/../transcrypt -v | awk '{print $2}')

  run "$BATS_TEST_DIRNAME"/../transcrypt -d
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "The current repository was configured using transcrypt version $VERSION" ]]
  [[ "${lines[5]}" = "  CONTEXT:  default" ]]
  [[ "${lines[6]}" = "  CIPHER:   aes-256-cbc" ]]
  [[ "${lines[7]}" = "  PASSWORD: abc123" ]]
  [[ "${lines[9]}" = "  transcrypt -c aes-256-cbc -p 'abc123'" ]]
}

@test "init: cannot re-init, fails with error message" {
  init_transcrypt

  run "$BATS_TEST_DIRNAME"/../transcrypt --cipher=aes-256-cbc --password=abc123 --yes
  [[ "$status" -ne 0 ]]
  [[ "${lines[0]}" = "transcrypt: the current repository is already configured; see 'transcrypt --display'" ]]
}
