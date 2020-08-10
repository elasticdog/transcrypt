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

@test "crypt: handle challenging file names when 'core.quotePath=true'" {
  # Set core.quotePath=true which is the Git default prior to encrypting a
  # file with non-ASCII characters and spaces in the name, to confirm
  # transcrypt can handle the file properly.
  # For info about the 'core.quotePath' setting see
  # https://git-scm.com/docs/git-config#Documentation/git-config.txt-corequotePath
  git config --local --add core.quotePath true

  FILENAME="Mig – røve"  # Danish
  SECRET_CONTENT_ENC="U2FsdGVkX19Fp9SwTyQ+tz1OgHNIN0OJ+6sMgHIqPMzfdZ6rZ2iVquS293WnjJMx"

  encrypt_named_file "$FILENAME" "$SECRET_CONTENT"
  [[ "${output}" = *"Encrypt file \"$FILENAME\""* ]]

  # Working copy is decrypted
  run cat "$FILENAME"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # Git internal copy is encrypted
  run git show HEAD:"$FILENAME" --no-textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT_ENC" ]

  # transcrypt --show-raw shows encrypted content
  run ../transcrypt --show-raw "$FILENAME"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "==> $FILENAME <==" ]
  [ "${lines[1]}" = "$SECRET_CONTENT_ENC" ]

  # git ls-crypt lists encrypted file
  run git ls-crypt
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$FILENAME" ]

  # transcrypt --list lists encrypted file"
  run ../transcrypt --list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$FILENAME" ]

  rm "$FILENAME"
}

@test "crypt: transcrypt --upgrade applies new merge driver" {
  VERSION=`../transcrypt -v | awk '{print $2}'`

  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  # Simulate a fake old installation of transcrypt without merge driver
  echo "sensitive_file filter=crypt diff=crypt" > .gitattributes
  git add .gitattributes
  git commit -m "Removed merge driver config from .gitattributes"

  git config --local transcrypt.version "0.0"

  rm .git/crypt/merge

  # Check .gitattributes and sensitive_file before re-install
  run cat .gitattributes
  [ "${lines[0]}" = "sensitive_file filter=crypt diff=crypt" ]
  [ ! -f .git/crypt/merge ]

  run git config --get --local transcrypt.version
  [ "${lines[0]}" = "0.0" ]
  run git config --get --local transcrypt.cipher
  [ "${lines[0]}" = "aes-256-cbc" ]
  run git config --get --local transcrypt.password
  [ "${lines[0]}" = "abc123" ]

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # Perform re-install
  run ../transcrypt --upgrade --yes
  [ "$status" -eq 0 ]

  run git config --get --local transcrypt.version
  [ "${lines[0]}" = "$VERSION" ]
  run git config --get --local transcrypt.cipher
  [ "${lines[0]}" = "aes-256-cbc" ]
  run git config --get --local transcrypt.password
  [ "${lines[0]}" = "abc123" ]

  # Check sensitive_file is unchanged after re-install
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # Check merge driver is installed
  [ -f .git/crypt/merge ]

  # Check .gitattributes is updated to include merge driver
  run cat .gitattributes
  [ "${lines[0]}" = "sensitive_file filter=crypt diff=crypt merge=crypt" ]

  run check_repo_is_clean
  [ "$status" -ne 0 ]
}

@test "crypt: transcrypt --force handles files missing from working copy" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  ../transcrypt --uninstall --yes

  # Reset repo to restore .gitattributes file
  git reset --hard

  # Delete secret file from working copy
  rm sensitive_file

  # Re-init with --force should check out deleted secret file
  ../transcrypt --force --cipher=aes-256-cbc --password=abc123 --yes

  # Check sensitive_file is present and decrypted
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}
