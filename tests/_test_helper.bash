function init_git_repo {
  git init $BATS_TEST_DIRNAME
}

function nuke_git_repo {
  rm -fR $BATS_TEST_DIRNAME/.git
}

function cleanup_all {
  nuke_git_repo
  rm $BATS_TEST_DIRNAME/.gitattributes
  rm $BATS_TEST_DIRNAME/sensitive_file
}
