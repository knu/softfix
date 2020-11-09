# Softfix a pull request
After installation, simply write `/softfix` to fixup all commits of the pr into the first one. This will use the commit message of the first one by default.

If you want to edit the commit message, the action will use the text within triple quotes in direct connection with the command like so

````
/softfix
```
The new commit message

The details of the new commit message
```

Some other text not related to the commit message in particular.
````

There is also an option to concatenate all messages like GitHub's "Squash and merge" feature.

```
/softfix:squash
```

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
    - uses: dekvall/softfix@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

