#!/usr/bin/env bats

load $BATS_TEST_DIRNAME/_test_helper.bash

SECRET_CONTENT="My secret content"
SECRET_CONTENT_ENC="U2FsdGVkX1/kkWK36bn3fbq5DY2d+JXL2YWoN/eoXA1XJZEk9JS7j/856rXK9gPn"

function check_repo_is_clean {
  git diff-index --quiet HEAD --
}

@test "crypt: git ls-crypt command is available" {
  # No encrypted file yet, so command should work with no output
  run git ls-crypt
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "" ]
}

@test "crypt: encrypt a file" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
}

@test "crypt: encrypted file contents are decrypted in working copy" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}

@test "crypt: encrypted file contents are encrypted in git (via git show)" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run git show HEAD:sensitive_file --no-textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT_ENC" ]
}

@test "crypt: transcrypt --show-raw shows encrypted content" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run ../transcrypt --show-raw sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "==> sensitive_file <==" ]
  [ "${lines[1]}" = "$SECRET_CONTENT_ENC" ]
}

@test "crypt: git ls-crypt lists encrypted file" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  run git ls-crypt
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "sensitive_file" ]
}

@test "crypt: transcrypt --list lists encrypted file" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  run ../transcrypt --list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "sensitive_file" ]
}

@test "crypt: transcrypt --uninstall leaves decrypted file and repo dirty" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

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

@test "crypt: git reset after uninstall leaves encrypted file" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  ../transcrypt --uninstall --yes

  git reset --hard
  check_repo_is_clean

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" != "$SECRET_CONTENT" ]
  [ "${lines[0]}" = "$SECRET_CONTENT_ENC" ]
}
