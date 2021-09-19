#!/bin/sh

REPOSITORY_OWNER="$INPUT_REPOSITORY_OWNER"
REPOSITORY_NAME="$INPUT_REPOSITORY_NAME"
PULL_REQUEST="$INPUT_PULL_REQUEST"

__LINKED_ISSUES_HTML=""


prepareInputs() {
  if [ -z "$REPOSITORY_OWNER" ]; then
    REPOSITORY_OWNER=$(cat "$GITHUB_EVENT_PATH" | jq -r ".repository.owner.login")
  fi;

  if [ -z "$REPOSITORY_NAME" ]; then
    REPOSITORY_NAME=$(cat "$GITHUB_EVENT_PATH" | jq -r ".repository.name")
  fi;

  if [ -z "$PULL_REQUEST" ]; then
    PULL_REQUEST=$(cat "$GITHUB_EVENT_PATH" | jq ".number")
    if [ "$PULL_REQUEST" = "null" ]; then
      printf "PR number can't be retrieved from event data.\n" >&2
      printf "You must define a pull request number using 'pr_number' input or"
      printf " execute the action using a pull request event.\n"
      exit 1
    fi;
  fi;
}

extractLinkedIssuesHTML() {
  URL="https://github.com/$REPOSITORY_OWNER/$REPOSITORY_NAME/pull/$PULL_REQUEST/"
  inside_form_substring="<form class=\"js-issue-sidebar-form"
  outside_form_substring="</form>"

  echo "$(curl -sSL --retry 3 "$URL")" > \
     /tmp/pr-linked-issues-action-response.txt
  _INSIDE_FORM=0
  while IFS= read -r line; do
    if [ $_INSIDE_FORM -eq 0 ]; then
      if test "${line#*$inside_form_substring}" != "$line"; then
        _INSIDE_FORM=1
      fi
    else
      if test "${line#*$outside_form_substring}" != "$line"; then
        _INSIDE_FORM=0
      else
        _LINKED_ISSUES_HTML="$_LINKED_ISSUES_HTML
$line"
      fi;
    fi;
  done < /tmp/pr-linked-issues-action-response.txt
}


main() {
  prepareInputs

  extractLinkedIssuesHTML

  # extract issues numbers
  ISSUES=$(
    echo "$_LINKED_ISSUES_HTML" \
      | grep -o "data-hovercard-url=\"/$REPOSITORY_OWNER/$REPOSITORY_NAME/issues/[0-9]\+/" \
      | cut -d'/' -f5 \
      | sort -u \
      | tr "\n" ","
  )
  if [ ! -z  "$ISSUES" ]; then
    #ISSUES="${ISSUES::-1}"
    ISSUES=${ISSUES%,}
  fi;
  echo "::set-output name=issues::$ISSUES"
}


main
