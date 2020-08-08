#!/usr/bin/env bats

load $BATS_TEST_DIRNAME/_test_helper.bash

@test "merge: branches with encrypted file - addition, no conflict" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 2"

  git checkout -
  git merge branch-2

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1. First step" ]
  [ "${lines[1]}" = "2. Second step" ]
}

@test "merge: branches with encrypted file - line change incoming branch, no conflict" {
  echo "1. First step" > sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "1. Step the first" > sensitive_file  # Cause line conflict
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 2, change line 1"

  git checkout -
  run git merge branch-2
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1. Step the first" ]
  [ "${lines[1]}" = "2. Second step" ]
}

@test "merge: branches with encrypted file - line changes both branches, no conflict" {
  echo "1. First step" > sensitive_file
  echo "2. Second step" >> sensitive_file
  encrypt_named_file sensitive_file

  git checkout -b branch-2
  echo "1. Step the first" > sensitive_file  # Cause line conflict
  echo "2. Second step" >> sensitive_file
  git add sensitive_file
  git commit -m "Change line 1"

  git checkout -

  echo "1. First step" > sensitive_file
  echo "2. Second step" >> sensitive_file
  echo "3. Third step" >> sensitive_file
  git add sensitive_file
  git commit -m "Add line 3"

  run git merge branch-2
  [ "$status" -eq 0 ]

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1. Step the first" ]
  [ "${lines[1]}" = "2. Second step" ]
  [ "${lines[2]}" = "3. Third step" ]
}

@test "merge: branches with encrypted file - line changes both branches, with conflicts" {
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
  [[ "${output}" = *"CONFLICT (content): Merge conflict in sensitive_file"* ]]

  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "<<<<<<< master" ]
  [ "${lines[1]}" = "a. First step" ]
  [ "${lines[2]}" = "=======" ]
  [ "${lines[3]}" = "1. Step the first" ]
  [ "${lines[4]}" = "2. Second step" ]
  [ "${lines[5]}" = ">>>>>>> branch-2" ]
}
