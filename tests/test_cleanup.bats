#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

SECRET_CONTENT="My secret content"

# Example generation:
# - Using project salt: 5J0Q
# - Generate file key
#   openssl dgst -hmac "sensitive_file:5J0Q" -sha256 sensitive_file  | tr -d '\r\n' | tail -c16
#   => ec32c0fbf2261d18
# - Encrypt file
#   cat sensitive_file | ENC_PASS='abc 123' openssl enc -e -a -aes-256-cbc -md sha512 -pass env:ENC_PASS -pbkdf2 -iter 99 -S ec32c0fbf2261d18
#   => U2FsdGVkX1+NiURgsIjgkwyiBw0TSC8WhhDRly2h4x2exuwjay6y/nOahblrBL62
SECRET_CONTENT_ENC="U2FsdGVkX1+NiURgsIjgkwyiBw0TSC8WhhDRly2h4x2exuwjay6y/nOahblrBL62"

@test "cleanup: transcrypt -f flush clears cached plaintext" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  # Confirm working copy file is decrypted
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # Show all changes, caches plaintext due to `cachetextconv` setting
  run git log -p -- sensitive_file
  [ "$status" -eq 0 ]
  [[ "${output}" = *"+$SECRET_CONTENT" ]]  # Check last line of patch

  # Look up notes ref to cached plaintext
  [ -f $BATS_TEST_DIRNAME/.git/refs/notes/textconv/crypt ]
  cached_plaintext_obj=$(cat "$BATS_TEST_DIRNAME/.git/refs/notes/textconv/crypt")

  # Confirm plaintext is cached
  run git show "$cached_plaintext_obj"
  [ "$status" -eq 0 ]
  [[ "${output}" = *"+$SECRET_CONTENT" ]]  # Check last line of patch

  # Repack to force all objects into packs (which are trickier to clear)
  git repack

  # Flush credentials
  run ../transcrypt -f --yes
  [ "$status" -eq 0 ]

  # Confirm working copy file is encrypted
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT_ENC" ]

  # Confirm show all changes shows encrypted content, not plaintext
  git log -p -- sensitive_file
  run git log -p -- sensitive_file
  [ "$status" -eq 0 ]
  [[ "${output}" = *"+$SECRET_CONTENT_ENC" ]]  # Check last line of patch

  # Confirm plaintext cache ref was cleared
  [ ! -e $BATS_TEST_DIRNAME/.git/refs/notes/textconv/crypt ]

  # Confirm plaintext obj was truly cleared and is no longer visible
  run git show "$cached_plaintext_obj"
  [ "$status" -ne 0 ]
}

@test "cleanup: transcrypt --uninstall clears cached plaintext" {
  encrypt_named_file sensitive_file "$SECRET_CONTENT"

  # Confirm working copy file is decrypted
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # Show all changes, caches plaintext due to `cachetextconv` setting
  run git log -p -- sensitive_file
  [ "$status" -eq 0 ]
  [[ "${output}" = *"+$SECRET_CONTENT" ]]  # Check last line of patch

  # Look up notes ref to cached plaintext
  [ -f $BATS_TEST_DIRNAME/.git/refs/notes/textconv/crypt ]
  cached_plaintext_obj=$(cat "$BATS_TEST_DIRNAME/.git/refs/notes/textconv/crypt")

  # Confirm plaintext is cached
  run git show "$cached_plaintext_obj"
  [ "$status" -eq 0 ]
  [[ "${output}" = *"+$SECRET_CONTENT" ]]  # Check last line of patch

  # Repack to force all objects into packs (which are trickier to clear)
  git repack

  # Uninstall
  run ../transcrypt --uninstall --yes
  [ "$status" -eq 0 ]

  # Confirm working copy file remains unencrypted (per uninstall contract)
  run cat sensitive_file
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$SECRET_CONTENT" ]

  # Confirm show all changes shows encrypted content, not plaintext
  run git log -p -- sensitive_file
  [ "$status" -eq 0 ]
  [[ "${output}" = *"+$SECRET_CONTENT_ENC" ]]  # Check last line of patch

  # Confirm plaintext cache ref was cleared
  [ ! -e $BATS_TEST_DIRNAME/.git/refs/notes/textconv/crypt ]

  # Confirm plaintext obj was truly cleared and is no longer visible
  run git show "$cached_plaintext_obj"
  [ "$status" -ne 0 ]
}
