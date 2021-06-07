#!/bin/bash

set -e

PR_NUMBER=$(jq -r ".issue.number" "$GITHUB_EVENT_PATH")
COMMENT_BODY=$(jq -r '.comment.body | gsub("\r\n"; "\n")' "$GITHUB_EVENT_PATH")

# Grab the old commit message and use it if there is nothing else
# But really only handling of the message is required now, and a lot of cleanup
echo "Softfixing #$PR_NUMBER in $GITHUB_REPOSITORY"

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Set a github token"
	exit 1
fi

URI="https://api.github.com"

github_api () {
	curl -s \
	-H "Authorization: token $GITHUB_TOKEN" \
	-H "Accept: application/vnd.github.v3+json" \
	"$@"
}

pr_response=$(github_api "${URI}/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")

COMMITS_URL=$(jq -r .commits_url <<<"$pr_response")
commits_response=$(github_api $COMMITS_URL)
# This is limited to 250 entries, but it should be okay
N_COMMITS=$(jq -r length <<<"$commits_response")

# /softfix ``` ... ```
COMMIT_MSG=$(jq -rRs 'match("(?<!\\S)/softfix(?::squash)?\\n```\\n(.*?)\\n```(?:\\n|\\z)"; "m").captures[0].string' <<<"$COMMENT_BODY")

COMMENT_URL="$(jq -r '.comment.url' "$GITHUB_EVENT_PATH")"

add_reaction () {
	github_api -X POST \
               -H "Accept: application/vnd.github.squirrel-girl-preview" \
               -d "$(jq -nc --arg content "$1" '{content:$content}')" \
               "$COMMENT_URL/reactions" || :
}

command=$(jq -rRs 'match("(?<!\\S)/(softfix(?::[a-z0-9\\-_]+)?)$").captures[0].string' <<<"$COMMENT_BODY")

case "$command" in
	"")
		echo "No valid directive is found, aborting..."
		exit 0
		;;
	*:*)
		command=${command#*:}
		;;
	*)
		command=fixup
esac

case "$command" in
	fixup|squash)
		if [[ -z "$COMMIT_MSG" && "$N_COMMITS" -eq 1 ]]; then
			echo "Nothing to do here, aborting..."
			add_reaction laugh
			exit 0
		fi
		;;
	rebase|merge)
		;;
	*)
		echo "Unknown command, aborting..."
		add_reaction eyes
		exit 0
esac

add_reaction +1

USER_LOGIN=$(jq -r ".comment.user.login" "$GITHUB_EVENT_PATH")
user_response=$(github_api "${URI}/users/${USER_LOGIN}")
USER_NAME="$(jq -r --arg default "$USER_LOGIN" '.name // $default' <<<"$user_response") (Softfix Action)"
USER_EMAIL="$(jq -r --arg default "$USER_LOGIN@users.noreply.github.com" '.email // $default' <<<"$user_response")"
HEAD_REPO=$(jq -r .head.repo.full_name <<<"$pr_response")
HEAD_BRANCH=$(jq -r .head.ref <<<"$pr_response")

USER_TOKEN=${USER_LOGIN}_TOKEN
COMMITTER_TOKEN=${!USER_TOKEN:-$GITHUB_TOKEN}

git remote set-url origin "https://x-access-token:$COMMITTER_TOKEN@github.com/$GITHUB_REPOSITORY.git"
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

git remote add fork "https://x-access-token:$COMMITTER_TOKEN@github.com/$HEAD_REPO.git"

git fetch fork "$HEAD_BRANCH"

git checkout -b "$HEAD_BRANCH" "fork/$HEAD_BRANCH"

case "$command" in
	fixup|squash)
		if [[ -z "$COMMIT_MSG" && "$command" == squash ]]; then
			# /softfix:squash: GitHub's Squash and merge style
			COMMIT_MSG=$(git log --reverse --pretty=format:"* %B" "HEAD~$N_COMMITS..HEAD" | tail -c +3)
		fi

		git reset --soft HEAD~$(($N_COMMITS-1))

		if [[ -z "$COMMIT_MSG" ]]; then
			git commit --amend --no-edit
		else
			git commit --amend -m "$COMMIT_MSG"
		fi
		;;
	rebase|merge)
		BASE_BRANCH=$(jq -r .base.ref <<<"$pr_response")

		git fetch origin "$BASE_BRANCH"

		echo 'ChangeLog   merge=merge-changelog' >> .git/info/attributes
		echo 'ChangeLog.* merge=merge-changelog' >> .git/info/attributes
		git config merge.merge-changelog.name 'GNU-style ChangeLog merge driver'
		git config merge.merge-changelog.driver 'git-merge-changelog %O %A %B'

		echo 'schema.rb merge=merge-schema-rb' >> .git/info/attributes
		git config merge.merge-schema-rb.name 'Rails schema.rb merge driver'
		git config merge.merge-schema-rb.driver 'merge_db_schema %O %A %B'
		git config merge.merge-schema-rb.recursive 'text'

		echo 'structure.sql merge=merge-structure-sql' >> .git/info/attributes
		git config merge.merge-structure-sql.name 'Rails structure.sql merge driver'
		git config merge.merge-structure-sql.driver 'git-merge-structure-sql %A %O %B'

		case "$command" in
			rebase)
				git rebase HEAD~$N_COMMITS --onto "origin/$BASE_BRANCH"
				;;
			merge)
				if [[ -z "$COMMIT_MSG" ]]; then
					git merge "origin/$BASE_BRANCH" --no-edit
				else
					git merge "origin/$BASE_BRANCH" -m "$COMMIT_MSG"
				fi
				;;
			*)
				false
		esac || {
			add_reaction confused
			exit 0
		}
		;;
	*)
		false
esac

git push --force-with-lease fork "$HEAD_BRANCH" || {
	add_reaction confused
	exit 0
}

add_reaction hooray
