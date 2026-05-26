#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

@test "settings: display reads non-secret legacy public settings file" {
  mkdir -p .transcrypt
  cat > .transcrypt/config <<'CONFIG'
[transcrypt]
format = legacy
cipher = aes-256-cbc
digest = MD5
kdf = legacy
CONFIG

  run ../transcrypt --display
  [ "$status" -eq 0 ]
  [[ "$output" = *"  FORMAT:   legacy"* ]]
  [[ "$output" = *"  KDF:      legacy"* ]]
  [[ "$output" = *"  DIGEST:   MD5"* ]]
}

@test "settings: display rejects unsupported public settings" {
  mkdir -p .transcrypt
  cat > .transcrypt/config <<'CONFIG'
[transcrypt]
format = legacy
cipher = aes-256-cbc
digest = MD5
kdf = unsupported
CONFIG

  run ../transcrypt --display
  [ "$status" -ne 0 ]
  [[ "$output" = *"unsupported transcrypt KDF"* ]]
}

@test "settings: display rejects PBKDF2 before PBKDF2 is implemented" {
  mkdir -p .transcrypt
  cat > .transcrypt/config <<'CONFIG'
[transcrypt]
format = v3
cipher = aes-256-cbc
digest = sha256
kdf = pbkdf2
iterations = 250000
base-salt = test-public-salt
CONFIG

  run ../transcrypt --display
  [ "$status" -ne 0 ]
  [[ "$output" = *"unsupported transcrypt format"* || "$output" = *"unsupported transcrypt KDF"* ]]
}
