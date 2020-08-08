#!/usr/bin/env bats

load $BATS_TEST_DIRNAME/_test_helper.bash

SECRET_CONTENT="My secret content"
SECRET_CONTENT_ENC="U2FsdGVkX1/kkWK36bn3fbq5DY2d+JXL2YWoN/eoXA1XJZEk9JS7j/856rXK9gPn"
SUPER_SECRET_CONTENT_ENC="U2FsdGVkX1/kkWK36bn3fbq5DY2d+JXL2YWoN/eoXA1XJZEk9JS7j/856rXK9gPn"

function setup {
  pushd $BATS_TEST_DIRNAME
  init_git_repo
  init_transcrypt

  # Init transcrypt with 'super-secret' context
  $BATS_TEST_DIRNAME/../transcrypt --context=super-secret --cipher=aes-256-cbc --password=321cba --yes
}

function teardown {
  cleanup_all
  rm -f $BATS_TEST_DIRNAME/super_sensitive_file
  popd
}

@test "contexts: check git config for 'super-secret' context" {
  VERSION=`../transcrypt -v | awk '{print $2}'`
  GIT_DIR=`git rev-parse --git-dir`

  [ `git config --get transcrypt.super-secret-version` = $VERSION ]
  [ `git config --get transcrypt.super-secret-cipher` = "aes-256-cbc" ]
  [ `git config --get transcrypt.super-secret-password` = "321cba" ]

  # Use --git-common-dir if available (Git post Nov 2014) otherwise --git-dir
  if [[ -d $(git rev-parse --git-common-dir) ]]; then
    [[ `git config --get filter.super-secret-crypt.clean` = '"$(git rev-parse --git-common-dir)"/crypt/clean %f' ]]
    [[ `git config --get filter.super-secret-crypt.smudge` = '"$(git rev-parse --git-common-dir)"/crypt/smudge' ]]
    [[ `git config --get diff.super-secret-crypt.textconv` = '"$(git rev-parse --git-common-dir)"/crypt/textconv' ]]
  else
    [[ `git config --get filter.super-secret-crypt.clean` = '"$(git rev-parse --git-dir)"/crypt/clean %f' ]]
    [[ `git config --get filter.super-secret-crypt.smudge` = '"$(git rev-parse --git-dir)"/crypt/smudge' ]]
    [[ `git config --get diff.super-secret-crypt.textconv` = '"$(git rev-parse --git-dir)"/crypt/textconv' ]]
  fi

  [ `git config --get filter.super-secret-crypt.required` = "true" ]
  [ `git config --get diff.super-secret-crypt.cachetextconv` = "true" ]
  [ `git config --get diff.super-secret-crypt.binary` = "true" ]
  [ `git config --get merge.renormalize` = "true" ]

  [[ `git config --get alias.ls-super-secret-crypt` = "!git -c core.quotePath=false ls-files"* ]]

  [[ `git config --get alias.ls-crypt` = "!git -c core.quotePath=false ls-files"* ]]
}

@test "contexts: encrypt a file in default and 'super-secret' contexts" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  encrypt_named_file super_sensitive_file "$SECRET_CONTENT" "super-secret"

  # Confirm .gitattributes is configured for multiple contexts
  run cat .gitattributes
  [ "${lines[1]}" = '"sensitive_file" filter=crypt diff=crypt merge=crypt' ]
  [ "${lines[2]}" = '"super_sensitive_file" filter=super-secret-crypt diff=super-secret-crypt merge=super-secret-crypt' ]
}

@test "contexts: confirm --list-contexts lists context with config status" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  encrypt_named_file super_sensitive_file "$SECRET_CONTENT" "super-secret"

  # Confirm .gitattributes is configured for multiple contexts
  run ../transcrypt --list-contexts
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'default (configured, in .gitattributes)' ]
  [ "${lines[1]}" = 'super-secret (configured, in .gitattributes)' ]
}

@test "contexts: encrypted file contents in multiple context are decrypted in working copy" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  encrypt_named_file super_sensitive_file "$SECRET_CONTENT" "super_secret"

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  run cat super_sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}
