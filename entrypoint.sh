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
COMMIT_MSG=$(jq -rRs 'match("(?<!\\S)/softfix\\n```\\n(.*?)\\n```(?:\\n|\\z)"; "m").captures[0].string' <<<"$COMMENT_BODY")

if [[ -z "$COMMIT_MSG" ]] && [[ "$N_COMMITS" -eq 1 ]]; then
	echo "Nothing to do here, aborting..."
	exit 0
fi

github_api -X POST \
           -H "Accept: application/vnd.github.squirrel-girl-preview" \
           -d '{"content":"+1"}' \
           "$(jq -r '.comment.url' "$GITHUB_EVENT_PATH")/reactions" || :

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

if [[ -z "$COMMIT_MSG" ]] && jq -eRs 'test("(?<!\\S)/softfix:squash\\b")' <<<"$COMMENT_BODY" >/dev/null; then
	# /softfix:squash: GitHub's Squash and merge style
	COMMIT_MSG=$(git log --reverse --pretty=format:"* %B" "HEAD~$N_COMMITS..HEAD" | tail -c +3)
fi

git reset --soft HEAD~$(($N_COMMITS-1))

if [[ -z "$COMMIT_MSG" ]]; then
	git commit --amend --no-edit
else
	git commit --amend -m "$COMMIT_MSG"
fi

git push --force-with-lease fork "$HEAD_BRANCH"
