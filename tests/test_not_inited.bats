#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

# Custom setup: don't init transcrypt
# We need to init and tear down Git repo for these tests, mainly to avoid
# falling back to the transcrypt repo's Git config and partial transcrypt setup
# shellcheck disable=SC2034
SETUP_SKIP_INIT_TRANSCRYPT=1


# Operations that should work in a repo not yet initialised

@test "not inited: show help for --help" {
  run "$BATS_TEST_DIRNAME"/../transcrypt --help
  [[ "${lines[1]}" = "     transcrypt -- transparently encrypt files within a git repository" ]]
}

@test "not inited: show help for -h" {
  run "$BATS_TEST_DIRNAME"/../transcrypt -h
  [[ "${lines[1]}" = "     transcrypt -- transparently encrypt files within a git repository" ]]
}

@test "not inited: show version for --version" {
  VERSION=$("$BATS_TEST_DIRNAME"/../transcrypt -v | awk '{print $2}')
  run "$BATS_TEST_DIRNAME"/../transcrypt --version
  [[ "${lines[0]}" = "transcrypt $VERSION" ]]
}

@test "not inited: show version for -v" {
  VERSION=$("$BATS_TEST_DIRNAME"/../transcrypt -v | awk '{print $2}')
  run "$BATS_TEST_DIRNAME"/../transcrypt -v
  [[ "${lines[0]}" = "transcrypt $VERSION" ]]
}

@test "not inited: no files listed for --list" {
  run "$BATS_TEST_DIRNAME"/../transcrypt --list
  [[ "${lines[0]}" = "" ]]
}

@test "not inited: no files listed for -l" {
  run "$BATS_TEST_DIRNAME"/../transcrypt -l
  [[ "${lines[0]}" = "" ]]
}


# Operations that should not work in a repo not yet initialised

@test "not inited: error on --display" {
  run "$BATS_TEST_DIRNAME"/../transcrypt --display
  [[ "$status" -ne 0 ]]
  [[ "${lines[0]}" = "transcrypt: the current repository is not configured" ]]
}

@test "not inited: error on -d" {
  run "$BATS_TEST_DIRNAME"/../transcrypt -d
  [[ "$status" -ne 0 ]]
  [[ "${lines[0]}" = "transcrypt: the current repository is not configured" ]]
}

@test "not inited: error on --uninstall" {
  run "$BATS_TEST_DIRNAME"/../transcrypt --uninstall
  [[ "$status" -ne 0 ]]
  [[ "${lines[0]}" = "transcrypt: the current repository is not configured" ]]
}

@test "not inited: error on -u" {
  run "$BATS_TEST_DIRNAME"/../transcrypt -u
  [[ "$status" -ne 0 ]]
  [[ "${lines[0]}" = "transcrypt: the current repository is not configured" ]]
}


@test "not inited: error on --upgrade" {
  run "$BATS_TEST_DIRNAME"/../transcrypt --upgrade
  [[ "$status" -ne 0 ]]
  [[ "${lines[0]}" = "transcrypt: the current repository is not configured" ]]
}
