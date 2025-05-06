#!/bin/sh
#

test_description='git rebase --trailer integration tests
We verify that --trailer on the merge/interactive/exec/root backends,
and that it is rejected early when the apply backend is requested.'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh       # test_commit_message, helpers

create_expect () {
	cat >"$1" <<-EOF
	$2

	Reviewed-by: Dev <dev@example.com>
	EOF
}

############################################################################
# 1.  repository setup
############################################################################

test_expect_success 'setup repo with a small history' '
	git commit --allow-empty -m "Initial empty commit" &&
	test_commit first file a &&
	test_commit second file &&
	git checkout -b conflict-branch first &&
	test_commit file-2 file-2 &&
	test_commit conflict file &&
	test_commit third file &&
	ident="$GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL>" &&
	create_expect initial-signed  "Initial empty commit" &&
	create_expect first-signed    "first"                 &&
	create_expect second-signed   "second"                &&
	create_expect file2-signed    "file-2"                &&
	create_expect third-signed    "third"                 &&
	create_expect conflict-signed "conflict"
'

############################################################################
# 2.  explicitly reject --apply + --trailer
############################################################################

test_expect_success 'apply backend is rejected with --trailer' '
	git reset --hard third &&
	head_before=$(git rev-parse HEAD) &&
    test_expect_code 128 \
    		git rebase --apply --trailer "Reviewed-by: Dev <dev@example.com>" \
    			HEAD^ 2>err &&
	test_grep "requires the merge backend" err &&
	test_cmp_rev HEAD $head_before
'

############################################################################
# 4.  merge backend (-m), conflict resolution path
############################################################################

test_expect_success 'rebase -m --trailer adds trailer after conflicts' '
	git reset --hard third &&
	test_must_fail git rebase -m \
		--trailer "Reviewed-by: Dev <dev@example.com>" \
		second third &&
	git checkout --theirs file &&
	git add file &&
    git rebase --continue &&
	test_commit_message HEAD~2 file2-signed
'

############################################################################
# 6.  --root path
############################################################################

test_expect_success 'rebase --root --trailer updates every commit' '
	git checkout first &&
	git rebase --root --keep-empty \
		--trailer "Reviewed-by: Dev <dev@example.com>" &&
	test_commit_message HEAD   first-signed &&
	test_commit_message HEAD^  initial-signed
'
test_done
