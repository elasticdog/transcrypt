function init_git_repo {
  # Warn and do nothing if test dir envvar is unset
  if [ -z $BATS_TEST_DIRNAME ]; then
    echo "WARNING: Required envvar \$BATS_TEST_DIRNAME is unset"
  # Warn and do nothing if test git repo path already exists
  elif [ -e $BATS_TEST_DIRNAME/.git ]; then
    echo "WARNING: Test repo already exists at $BATS_TEST_DIRNAME/.git"
  else
    # Initialise test git repo at the same path as the test files
    git init $BATS_TEST_DIRNAME
    # Flag test git repo as 100% the test one, for safety before later removal
    touch $BATS_TEST_DIRNAME/.git/repo-for-transcrypt-bats-tests
  fi
}

function nuke_git_repo {
  # Warn and do nothing if test dir envvar is unset
  if [ -z $BATS_TEST_DIRNAME ]; then
    echo "WARNING: Required envvar \$BATS_TEST_DIRNAME is unset"
  # Warn and do nothing if the test git repo is missing the flag file that
  # ensures it *really* is the test one, as set by the 'init_git_repo' function
  elif [ ! -e $BATS_TEST_DIRNAME/.git/repo-for-transcrypt-bats-tests ]; then
    echo "WARNING: Aborting delete of non-test Git repo at $BATS_TEST_DIRNAME/.git"
  else
    # Forcibly delete the test git repo
    rm -fR $BATS_TEST_DIRNAME/.git
  fi
}

function cleanup_all {
  nuke_git_repo
  rm $BATS_TEST_DIRNAME/.gitattributes
  rm -f $BATS_TEST_DIRNAME/sensitive_file
}

function init_transcrypt {
  $BATS_TEST_DIRNAME/../transcrypt --cipher=aes-256-cbc --password=abc123 --yes
}

function encrypt_named_file {
  filename="$1"
  content=$2
  context=${3:-default}
  if [ "$content" ]; then
    echo "$content" > "$filename"
  fi
  if [ "$context" != "default" ]; then
    context_crypt="$context-crypt"
  else
    context_crypt="crypt"
  fi
  echo "\"$filename\" filter=${context_crypt} diff=${context_crypt} merge=${context_crypt}" >> .gitattributes
  git add .gitattributes "$filename"
  run git commit -m "Encrypt file \"$filename\""
}

function setup {
  pushd $BATS_TEST_DIRNAME
  init_git_repo
  if [ ! "$SETUP_SKIP_INIT_TRANSCRYPT" ]; then
    init_transcrypt
  fi
}

function teardown {
  cleanup_all
  popd
}
