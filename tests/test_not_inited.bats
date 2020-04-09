#!/usr/bin/env bats

function setup {
  pushd $BATS_TEST_DIRNAME
}

function teardown {
  popd
}

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


# ?

@test "not inited: no files listed for --list" {
  skip "TODO: --list doesn't work for un-inited repo, should it?"
  run ../transcrypt --list
  [ "${lines[0]}" = "" ]
}

@test "not inited: no files listed for -l" {
  skip "TODO: -l doesn't work for un-inited repo, should it?"
  run ../transcrypt -l
  [ "${lines[0]}" = "" ]
}
