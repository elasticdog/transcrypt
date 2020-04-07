#!/usr/bin/env bats

load $BATS_TEST_DIRNAME/_test_helper.bash

SECRET_CONTENT="My secret content"
SECRET_CONTENT_ENC="U2FsdGVkX1/kkWK36bn3fbq5DY2d+JXL2YWoN/eoXA1XJZEk9JS7j/856rXK9gPn"

function init_transcrypt {
  $BATS_TEST_DIRNAME/../transcrypt --cipher=aes-256-cbc --password=abc123 --yes
}

function encrypt_file {
  echo $SECRET_CONTENT > sensitive_file
  echo 'sensitive_file filter=crypt diff=crypt' >> .gitattributes
  git add .gitattributes sensitive_file
  git commit -m 'Add encrypted version of a sensitive file'
}

function check_repo_is_clean {
  git diff-index --quiet HEAD --
}


function setup {
  pushd $BATS_TEST_DIRNAME
  init_git_repo
  init_transcrypt
}

function teardown {
  cleanup_all
  popd
}

@test "git ls-crypt command is available" {
  # No encrypted file yet, so command should work with no output
  run git ls-crypt
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "" ]
}

@test "encrypt a file" {
  encrypt_file
}

@test "encrypted file contents are decrypted in working copy" {
  encrypt_file
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "encrypted file contents are encrypted in git (via git show)" {
  encrypt_file
  run git show HEAD:sensitive_file --no-textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT_ENC" ]
}

@test "transcrypt --show-raw shows encrypted content" {
  encrypt_file
  run ../transcrypt --show-raw sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "==> sensitive_file <==" ]
  [ "${lines[1]}" = "$SECRET_CONTENT_ENC" ]
}

@test "git ls-crypt lists encrypted file" {
  encrypt_file

  run git ls-crypt
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "sensitive_file" ]
}

@test "transcrypt --list lists encrypted file" {
  skip "TODO Fails due to bug in transcrypt requirements checking"
  encrypt_file

  run ../transcrypt --list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "sensitive_file" ]
}

@test "transcrypt --uninstall leaves decrypted file and repo dirty" {
  encrypt_file

  run ../transcrypt --uninstall --yes
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  run cat .gitattributes
  [ "${lines[0]}" = "" ]

  run check_repo_is_clean
  [ "$status" -ne 0 ]
}

@test "git reset after uninstall leaves encrypted file" {
  encrypt_file

  ../transcrypt --uninstall --yes

  git reset --hard
  check_repo_is_clean

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" != "$SECRET_CONTENT" ]
  [ "${lines[0]}" = "$SECRET_CONTENT_ENC" ]
}
