#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

@test "security: diagnose crypto reports openssl and python capabilities" {
  run ../transcrypt --diagnose-crypto
  [ "$status" -eq 0 ]
  [[ "$output" = *"Crypto diagnostics for transcrypt"* ]]
  [[ "$output" = *"openssl version:"* ]]
  [[ "$output" = *"openssl enc -pbkdf2:"* ]]
  [[ "$output" = *"python3 PBKDF2 fallback:"* ]]
}

@test "security: audit warns about legacy crypto settings" {
  run ../transcrypt --audit
  [ "$status" -eq 0 ]
  [[ "$output" = *"Security audit for this transcrypt repository"* ]]
  [[ "$output" = *"Crypto format:  legacy"* ]]
  [[ "$output" = *"[HIGH] Legacy password derivation is enabled."* ]]
  [[ "$output" = *"[HIGH] Ciphertext authentication is not enabled."* ]]
}
