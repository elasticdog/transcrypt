#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/_test_helper.bash"

@test "pre-commit: pre-commit hook installed on init" {
  # Confirm pre-commit-crypt file is installed
  [[ -f .git/hooks/pre-commit-crypt ]]
  run cat .git/hooks/pre-commit-crypt
  [[ "${lines[1]}" = '# Transcrypt pre-commit hook: fail if secret file in staging lacks the magic prefix "Salted" in B64' ]]

  # Confirm hook is also installed/activated at pre-commit file name
  [[ -f .git/hooks/pre-commit ]]
  run cat .git/hooks/pre-commit
  [[ "${lines[1]}" = '# Transcrypt pre-commit hook: fail if secret file in staging lacks the magic prefix "Salted" in B64' ]]
}

@test "pre-commit: permit commit of encrypted file with encrypted content" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  echo " and more secrets" >> sensitive_file
  git add sensitive_file
  run git commit -m "Added more"
  [[ "$status" -eq 0 ]]

  run git log --format=oneline
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = *"Added more" ]]
  [[ "${lines[1]}" = *"Encrypt file \"sensitive_file\"" ]]
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
  [[ "$status" -ne 0 ]]
  [[ "${output}" = *"Transcrypt managed file is not encrypted in the Git index: sensitive_file"* ]]
  [[ "${output}" = *"You probably staged this file using a tool that does not apply .gitattribute filters as required by Transcrypt."* ]]
  [[ "${output}" = *"Fix this by re-staging the file with a compatible tool or with Git on the command line:"* ]]
  [[ "${output}" = *"    git reset -- sensitive_file"* ]]
  [[ "${output}" = *"    git add sensitive_file"* ]]
}

@test "pre-commit: pre-commit hook ignores symlinks to encrypted files" {
  echo "Secret stuff" > sensitive_file
  encrypt_named_file sensitive_file

  ln -s sensitive_file symlink_to_sensitive_file
  echo "\"symlink_to_sensitive_file\" filter=crypt diff=crypt merge=crypt" >> .gitattributes
  git add .gitattributes symlink_to_sensitive_file

  git commit -m "Commit symlink to encrypted file"
  [[ "$status" -eq 0 ]]

  rm symlink_to_sensitive_file
}

@test "pre-commit: warn and don't clobber existing pre-commit hook on init" {
  # Uninstall pre-existing transcrypt config from setup()
  run git transcrypt --uninstall --yes

  # Create a pre-existing pre-commit hook
  touch .git/hooks/pre-commit

  run "$BATS_TEST_DIRNAME"/../transcrypt --cipher=aes-256-cbc --password=abc123 --yes
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = "WARNING:" ]]
  [[ "${lines[1]}" = "Cannot install Git pre-commit hook script because file already exists: .git/hooks/pre-commit" ]]
  [[ "${lines[2]}" = "Please manually install the pre-commit script saved as: .git/hooks/pre-commit-crypt" ]]

  # Confirm pre-commit-crypt file is installed, but not copied to pre-commit
  run cat .git/hooks/pre-commit-crypt
  [[ "$status" -eq 0 ]]
  [[ "${lines[1]}" = '# Transcrypt pre-commit hook: fail if secret file in staging lacks the magic prefix "Salted" in B64' ]]
  [[ ! -s .git/hooks/pre-commit ]] # Zero file size]
}

@test "pre-commit: de-activate and remove transcrypt's pre-commit hook" {
  git transcrypt --uninstall --yes
  [[ ! -f .git/hooks/pre-commit ]]
  [[ ! -f .git/hooks/pre-commit-crypt ]]
}

@test "pre-commit: warn and don't delete customised pre-commit hook on uninstall" {
  # Customise transcrypt's pre-commit hook
  echo "#" >> .git/hooks/pre-commit

  run git transcrypt --uninstall --yes
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" = 'WARNING: Cannot safely disable Git pre-commit hook .git/hooks/pre-commit please check it yourself' ]]
  [[ -f .git/hooks/pre-commit ]]
  [[ ! -f .git/hooks/pre-commit-crypt ]]
}
