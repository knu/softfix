# Softfix a pull request
After installation, simply comment `/softfix` to fix up all commits of the pr into the first one. This will use the commit message of the first one by default.

If you want to edit the commit message, the action will use the text within triple quotes in direct connection with the command like so

````
/softfix
```
The new commit message

The details of the new commit message
```

Some other text not related to the commit message in particular.
````

If you want to concatenate all messages like GitHub's "Squash and merge" feature does, comment this:

```
/softfix:squash
```

You can get softfix to rebase the head branch to the latest base branch by commenting this:

```
/softfix:rebase
```

Or merge the latest base branch into the head branch by this:

```
/softfix:merge
```

The following merge drivers are used (as necessary) in rebase/merge operations.

- [git-merge-changelog](http://manpages.ubuntu.com/manpages/focal/man1/git-merge-changelog.1.html) - git merge driver for GNU ChangeLog files
- [git-merge-structure-sql](https://github.com/knu/git-merge-structure-sql) - git merge driver for db/structure.sql files of Rails

## Motivation
A PR should be atomic in itself, and can usually be a single commit. When you submit a change to an upstream repo, after a long and arduous review process, you will probably be asked to "squash" your commits. This can be confusing, especially for new contributors, so this action makes it easy to turn the entire changeset into one commit and if one wants to do so, change the commit message.

![softfix_demo](img/softfix_demo.png)

## Installation
Add the following lines to a file named `.github/workflows/softfix.yml` to use.
```
name: Softfix workflow
on: 
  issue_comment:
    types: [created]
jobs:
  softfix:
    name: Softfix action
    if: github.event.issue.pull_request != '' && contains(github.event.comment.body, '/softfix')
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: knu/softfix@v2
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

