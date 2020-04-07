#!/usr/bin/env bats

function setup {
  pushd $BATS_TEST_DIRNAME
}

function teardown {
  popd
}

@test "show help for --help" {
  run ../transcrypt --help
  [ "${lines[1]}" = "     transcrypt -- transparently encrypt files within a git repository" ]
}

@test "show help for -h" {
  run ../transcrypt -h
  [ "${lines[1]}" = "     transcrypt -- transparently encrypt files within a git repository" ]
}
