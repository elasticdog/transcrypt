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
  rm $BATS_TEST_DIRNAME/sensitive_file
}
