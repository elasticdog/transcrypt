# Isolate tests from the developer's global and system git config, so
# settings like merge.conflictstyle or commit.gpgsign cannot change test
# behavior. Requires Git 2.32+.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

# Absolute path to the script under test. Tests run inside per-test
# temporary repos, so cwd-relative paths to the script would break.
TRANSCRYPT="$BATS_TEST_DIRNAME/../../transcrypt"

function init_git_repo {
  # Each test builds its repository in the bats-managed per-test temp
  # dir, isolated from every other test so suites run under --jobs N.
  # bats removes BATS_TEST_TMPDIR after teardown; no cleanup needed.
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  git init --quiet -b main "$TEST_REPO"
  pushd "$TEST_REPO" >/dev/null || exit 1
  # Tests will fail if name and email aren't set
  git config --local user.name "John Doe"
  git config --local user.email johndoe@example.com
}

function init_transcrypt {
  "$TRANSCRYPT" --cipher=aes-256-cbc --password='abc 123' --yes
}

function uninstall_transcrypt {
  "$TRANSCRYPT" --uninstall --yes
}

function encrypt_named_file {
  filename="$1"
  content=$2
  context=${3:-default}
  if [[ "$content" ]]; then
    echo "$content" > "$filename"
  fi
  if [[ "$context" = "default" ]]; then
    echo "\"$filename\" filter=crypt diff=crypt merge=crypt" >> .gitattributes
  else
    echo "\"$filename\" filter=crypt-$context diff=crypt-$context merge=crypt-$context" >> .gitattributes
  fi
  git add .gitattributes "$filename"
  run git commit -m "Encrypt file \"$filename\""
}

function setup {
  init_git_repo
  if [[ ! "${SETUP_SKIP_INIT_TRANSCRYPT:-}" ]]; then
    init_transcrypt
  fi
}

function teardown {
  popd >/dev/null || exit 1
}

function check_repo_is_clean {
  git diff-index --quiet HEAD --
}
