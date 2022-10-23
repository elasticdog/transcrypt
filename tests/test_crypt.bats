#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

SECRET_CONTENT="My secret content"
SECRET_CONTENT_ENC="U2FsdGVkX1/6ilR0PmJpAyCF7iG3+k4aBwbgVd48WaQXznsg42nXbQrlWsf/qiCg"

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

@test "crypt: encrypted file contents can be decrypted (via git show --textconv)" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"
  run git show HEAD:sensitive_file --textconv
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
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
  [[ "${output}" = *"sensitive_file" ]]
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

  "$BATS_TEST_DIRNAME"/../transcrypt --uninstall --yes

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
  SECRET_CONTENT_ENC="U2FsdGVkX18jeEpsv589tzPzs+2KY6Bv6uxAHqAV6WvcSmckLHHVEvq3uItd9oq7"

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
  [[ "${output}" = *"$FILENAME" ]]

  # transcrypt --list lists encrypted file"
  run ../transcrypt --list
  [ "$status" -eq 0 ]
  [[ "${output}" = *"$FILENAME" ]]

  rm "$FILENAME"
}

@test "crypt: handle very small file" {
  FILENAME="small file.txt"
  SECRET_CONTENT="sh"
  SECRET_CONTENT_ENC="U2FsdGVkX1+fWwQTmT7tfxgGSJ+TLQJVV9WWlxtRZ38="

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
  [[ "${output}" = *"$FILENAME" ]]

  # transcrypt --list lists encrypted file"
  run ../transcrypt --list
  [ "$status" -eq 0 ]
  [[ "${output}" = *"$FILENAME" ]]

  rm "$FILENAME"
}

@test "crypt: handle file with problematic bytes" {
  FILENAME="problem bytes file.txt"
  SECRET_CONTENT_ENC="U2FsdGVkX18oyzDfF0Yjh1oqnz8RvjksOYpv53eaJ7c="

  # Write octal byte 375 and null byte as file contents
  printf "\375 \0 shh" > "$FILENAME"

  encrypt_named_file "$FILENAME"
  [[ "${output}" = *"Encrypt file \"$FILENAME\""* ]]

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
  [[ "${output}" = *"$FILENAME" ]]

  # transcrypt --list lists encrypted file"
  run ../transcrypt --list
  [ "$status" -eq 0 ]
  [[ "${output}" = *"$FILENAME" ]]

  rm "$FILENAME"
}

@test "crypt: transcrypt --upgrade applies new merge driver" {
  VERSION=$("$BATS_TEST_DIRNAME"/../transcrypt -v | awk '{print $2}')

  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  # Simulate a fake old installation of transcrypt without merge driver
  echo "sensitive_file filter=crypt diff=crypt" > .gitattributes
  git add .gitattributes
  git commit -m "Removed merge driver config from .gitattributes"

  git config --local transcrypt.version "0.0"

  git config --local --unset merge.crypt.driver

  # Check .gitattributes and sensitive_file before re-install
  run cat .gitattributes
  [ "${lines[0]}" = "sensitive_file filter=crypt diff=crypt" ]
  # Check merge driver is not installed
  [ ! "$(git config --get merge.crypt.driver)" = '"$(git config transcrypt.crypt-dir 2>/dev/null || printf ''%s/crypt'' ""$(git rev-parse --git-dir)"")"/transcrypt merge %O %A %B %L %P' ]

  run git config --get --local transcrypt.version
  [ "${lines[0]}" = "0.0" ]
  run git config --get --local transcrypt.cipher
  [ "${lines[0]}" = "aes-256-cbc" ]
  run git config --get --local transcrypt.password
  [ "${lines[0]}" = "abc 123" ]

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
  [ "${lines[0]}" = "abc 123" ]

  # Check sensitive_file is unchanged after re-install
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # Check merge driver is installed
  [ "$(git config --get merge.crypt.driver)" = '"$(git config transcrypt.crypt-dir 2>/dev/null || printf ''%s/crypt'' ""$(git rev-parse --git-dir)"")"/transcrypt merge context=default %O %A %B %L %P' ]

  # Check .gitattributes is updated to include merge driver
  run cat .gitattributes
  [ "${lines[0]}" = "sensitive_file filter=crypt diff=crypt merge=crypt" ]

  run check_repo_is_clean
  [ "$status" -ne 0 ]
}

@test "crypt: transcrypt --force handles files missing from working copy" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  "$BATS_TEST_DIRNAME"/../transcrypt --uninstall --yes

  # Reset repo to restore .gitattributes file
  git reset --hard

  # Delete secret file from working copy
  rm sensitive_file

  # Re-init with --force should check out deleted secret file
  ../transcrypt --force --cipher=aes-256-cbc --password='abc 123' --yes

  # Check sensitive_file is present and decrypted
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]
}
