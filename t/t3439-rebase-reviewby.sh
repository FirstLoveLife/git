#!/bin/sh

test_description='git rebase --reviewby

This test runs git rebase --reviewby and make sure that it works.
'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup' '
	git commit --allow-empty -m "Initial empty commit" &&
	test_commit first file a &&
	test_commit second file &&
	git checkout -b conflict-branch first &&
	test_commit file-2 file-2 &&
	test_commit conflict file &&
	test_commit third file &&

	ident="$GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL>" &&

	# Expected commit message for initial commit after rebase --reviewby
	cat >expected-initial-reviewed <<-EOF &&
	Initial empty commit

	Reviewed-by: $ident
	EOF

	# Expected commit message after rebase --reviewby
	cat >expected-reviewed <<-EOF &&
	first

	Reviewed-by: $ident
	EOF

	# Expected commit message after conflict resolution for rebase --reviewby
	cat >expected-reviewed-conflict <<-EOF &&
	third

	Reviewed-by: $ident

	conflict

	Reviewed-by: $ident

	file-2

	Reviewed-by: $ident

	EOF

	# Expected commit message after rebase without --reviewby (or with --no-reviewby)
	cat >expected-unreviewed <<-EOF &&
	first
	EOF

	git config alias.rbr "rebase --reviewby"
'

test_expect_success 'rebase --apply --reviewby adds a Reviewed-by line' '
	test_must_fail git rbr --apply second third &&
	git checkout --theirs file &&
	git add file &&
	git rebase --continue &&
	git log --format=%B -n3 >actual &&
	test_cmp expected-reviewed-conflict actual
'

test_expect_success 'rebase --no-reviewby does not add a Reviewed-by line' '
	git commit --amend -m "first" &&
	git rbr --no-reviewby HEAD^ &&
	test_commit_message HEAD expected-unreviewed
'

test_expect_success 'rebase --exec --reviewby adds a Reviewed-by line' '
	test_when_finished "rm exec" &&
	git rebase --exec "touch exec" --reviewby first^ first &&
	test_path_is_file exec &&
	test_commit_message HEAD expected-reviewed
'

test_expect_success 'rebase --root --reviewby adds a Reviewed-by line' '
	git checkout first &&
	git rebase --root --keep-empty --reviewby &&
	test_commit_message HEAD^ expected-initial-reviewed &&
	test_commit_message HEAD expected-reviewed
'

test_expect_success 'rebase -m --reviewby adds a Reviewed-by line' '
	test_must_fail git rebase -m --reviewby second third &&
	git checkout --theirs file &&
	git add file &&
	GIT_EDITOR="sed -n /Conflicts:/,/^\\\$/p >actual" \
		git rebase --continue &&
	cat >expect <<-\EOF &&
	# Conflicts:
	#	file

	EOF
	test_cmp expect actual &&
	git log --format=%B -n3 >actual &&
	test_cmp expected-reviewed-conflict actual
'

test_expect_success 'rebase -i --reviewby adds a Reviewed-by line when editing commit' '
	(
		set_fake_editor &&
		FAKE_LINES="edit 1 edit 3 edit 2" \
			git rebase -i --reviewby first third
	) &&
	echo a >a &&
	git add a &&
	test_must_fail git rebase --continue &&
	git checkout --ours file &&
	echo b >a &&
	git add a file &&
	git rebase --continue &&
	echo c >a &&
	git add a &&
	git log --format=%B -n3 >actual &&
	cat >expect <<-EOF &&
	conflict

	Reviewed-by: $ident

	third

	Reviewed-by: $ident

	file-2

	Reviewed-by: $ident

	EOF
	test_cmp expect actual
'

test_done
