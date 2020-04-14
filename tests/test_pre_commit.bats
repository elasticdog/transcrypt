#!/usr/bin/env bats

load $BATS_TEST_DIRNAME/_test_helper.bash

function init_transcrypt {
  $BATS_TEST_DIRNAME/../transcrypt --cipher=aes-256-cbc --password=abc123 --yes
}

function encrypt_named_file {
  filename=$1
  echo "$filename filter=crypt diff=crypt merge=crypt" >> .gitattributes
  git add .gitattributes $filename
  git commit -m "Encrypt file $filename"
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

@test "pre-commit: permit commit of encrypted file with encrypted content" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  echo " and more secrets" >> sensitive_file
  git add sensitive_file
  run git commit -m "Added more"
  [ "$status" -eq 0 ]

  run git log --format=oneline
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" = *"Added more" ]]
  [[ "${lines[1]}" = *"Encrypt file sensitive_file" ]]
}

@test "pre-commit: reject commit of encrypted file with unencrypted content" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  echo " and more secrets" >> sensitive_file

  # Disable file's crypt config in .gitattributes, add change, then re-enable
  echo "" > .gitattributes
  git add sensitive_file
  echo "sensitive_file filter=crypt diff=crypt merge=crypt" > .gitattributes

  # Confirm the pre-commit rejects plain text content in what should be
  # an encrypted file
  run git commit -m "Added more"
  [ "$status" -ne 0 ]
  [ "${lines[0]}" = "Transcrypt managed file is not encrypted in the Git index: sensitive_file" ]
  [ "${lines[1]}" = "You probably staged this file using a tool that does not apply .gitattribute filters as required by Transcrypt." ]
  [ "${lines[2]}" = "Fix this by re-staging the file with a compatible tool or with Git on the command line:" ]
  [ "${lines[3]}" = "    git reset -- sensitive_file" ]
  [ "${lines[4]}" = "    git add sensitive_file" ]
}
