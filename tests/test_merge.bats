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

@test "merge: branches with encrypted file - addition, no conflict" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 2"

  git checkout -
  git merge branch-2

  cat sensitive_file
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1. First step" ]
  [ "${lines[1]}" = "2. Second step" ]
}

@test "merge: branches with encrypted file - line change, no conflict" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "1. Step the first" > sensitive_file  # Cause line conflict
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 2, change line 1"

  git checkout -
  git merge branch-2

  cat sensitive_file
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1. Step the first" ]
  [ "${lines[1]}" = "2. Second step" ]
}

@test "merge: branches with encrypted file - with conflicts" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "1. Step the first" > sensitive_file  # Cause line conflict
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 2, change line 1"

  git checkout -
  echo "a. First step" > sensitive_file
  git add sensitive_file
  git commit -m "Change line 1 in original branch to set up conflict"

  run git merge branch-2
  [ "$status" -ne 0 ]
  [ "${lines[1]}" = "CONFLICT (content): Merge conflict in sensitive_file" ]

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" = "<<<<<<< "* ]]
  [ "${lines[1]}" = "a. First step" ]
  [ "${lines[2]}" = "=======" ]
  [ "${lines[3]}" = "1. Step the first" ]
  [ "${lines[4]}" = "2. Second step" ]
  [[ "${lines[5]}" = ">>>>>>> "* ]]
}
