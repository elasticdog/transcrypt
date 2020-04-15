#!/usr/bin/env bats

load $BATS_TEST_DIRNAME/_test_helper.bash

# Custom setup: don't init transcrypt
# We need to init and tear down Git repo for these tests, mainly to avoid
# falling back to the transcrypt repo's Git config and partial transcrypt setup
SETUP_SKIP_INIT_TRANSCRYPT=1


# Operations that should work in a repo not yet initialised

@test "not inited: show help for --help" {
  run ../transcrypt --help
  [ "${lines[1]}" = "     transcrypt -- transparently encrypt files within a git repository" ]
}

@test "not inited: show help for -h" {
  run ../transcrypt -h
  [ "${lines[1]}" = "     transcrypt -- transparently encrypt files within a git repository" ]
}

@test "not inited: show version for --version" {
  VERSION=`../transcrypt -v | awk '{print $2}'`
  run ../transcrypt --version
  [ "${lines[0]}" = "transcrypt $VERSION" ]
}

@test "not inited: show version for -v" {
  VERSION=`../transcrypt -v | awk '{print $2}'`
  run ../transcrypt -v
  [ "${lines[0]}" = "transcrypt $VERSION" ]
}

@test "not inited: no files listed for --list" {
  run ../transcrypt --list
  [ "${lines[0]}" = "" ]
}

@test "not inited: no files listed for -l" {
  run ../transcrypt -l
  [ "${lines[0]}" = "" ]
}


# Operations that should not work in a repo not yet initialised

@test "not inited: error on --display" {
  run ../transcrypt --display
  [ "$status" -ne 0 ]
  [ "${lines[0]}" = "transcrypt: the current repository is not configured" ]
}

@test "not inited: error on -d" {
  run ../transcrypt -d
  [ "$status" -ne 0 ]
  [ "${lines[0]}" = "transcrypt: the current repository is not configured" ]
}

@test "not inited: error on --uninstall" {
  run ../transcrypt --uninstall
  [ "$status" -ne 0 ]
  [ "${lines[0]}" = "transcrypt: the current repository is not configured" ]
}

@test "not inited: error on -u" {
  run ../transcrypt -u
  [ "$status" -ne 0 ]
  [ "${lines[0]}" = "transcrypt: the current repository is not configured" ]
}
