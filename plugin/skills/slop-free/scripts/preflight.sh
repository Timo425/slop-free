#!/usr/bin/env bash
# Read-only checks to run before spending time on a bug in someone else's repo.
#
# Usage: preflight.sh OWNER/REPO [--issue N] [--file PATH]... [--function NAME]...
#   --issue N        look for linked PRs, claims and assignees on issue N
#   --file PATH      look for open or recently merged PRs touching PATH (repeatable)
#   --function NAME  read the diffs of the open PRs that touch those files for NAME
#                    (repeatable; needs --file)
#
# Limits default to the skill's (2 open per repo, 15 open total). Override with
# MAX_PER_REPO and MAX_OPEN. Needs an authenticated gh.
set -uo pipefail

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
[ $# -ge 1 ] || usage 1
case "$1" in -h|--help) usage ;; esac
REPO="$1"; shift
ISSUE=""; FILES=(); FUNCS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) ISSUE="${2:?--issue needs a number}"; shift 2 ;;
    --file) FILES+=("${2:?--file needs a path}"); shift 2 ;;
    --function) FUNCS+=("${2:?--function needs a name}"); shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done
MAX_PER_REPO="${MAX_PER_REPO:-2}"; MAX_OPEN="${MAX_OPEN:-15}"
ME="$(gh api user --jq .login)" || { echo "gh is not authenticated" >&2; exit 1; }

days_ago() { date -u -d "$1 days ago" +%Y-%m-%d 2>/dev/null || date -u -v-"$1"d +%Y-%m-%d; }
raw() { gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$1" 2>/dev/null; }

echo "== $REPO (checked as $ME)"

echo
echo "## 1. Is anyone merging outside work?"
gh api "repos/$REPO" --jq '"  archived=\(.archived)  default branch=\(.default_branch)  last push=\(.pushed_at[:10])"'
last=$(gh pr list -R "$REPO" --state merged --limit 20 --json mergedAt --jq 'map(.mergedAt) | max // "never"')
echo "  last merge: ${last:0:10}"
gh api -X GET search/issues -f q="repo:$REPO type:pr is:merged merged:>=$(days_ago 60)" -f per_page=100 --jq '
  [.items[] | select(.user.type != "Bot")] as $h
  | ($h | map(select(.author_association | test("^(CONTRIBUTOR|FIRST_TIME_CONTRIBUTOR|FIRST_TIMER|NONE)$")))) as $o
  | "  merged in the last 60 days: \(.total_count) total, \($h | length) by humans in the first 100, \($o | length) from outside authors (\($o | map(.user.login) | unique | length) distinct)"'
echo "  (few distinct outside authors means outside PRs rarely land, whatever the issue count says)"

echo
echo "## 2. Contribution and AI policy (read the files in full; these are only the lines that matter most)"
found=0
for p in CONTRIBUTING.md .github/CONTRIBUTING.md docs/CONTRIBUTING.md AGENTS.md CLAUDE.md \
         AI_POLICY.md .github/AI_POLICY.md .github/copilot-instructions.md \
         .github/PULL_REQUEST_TEMPLATE.md .github/pull_request_template.md; do
  body=$(raw "$p") || continue
  [ -n "$body" ] || continue
  found=1
  echo "  -- $p"
  printf '%s\n' "$body" | grep -inE '\bAI\b|LLM|language model|copilot|chatgpt|claude|generated|agent|automated|issue first|open an issue|discuss|approved|assign|CLA\b|license agreement|DCO|signed-off-by|sign-off|force.push|squash|changeset|changelog' \
    | grep -viE 'user.?agent' | head -25 | sed 's/^/     /'
done
[ "$found" = 1 ] || echo "  no CONTRIBUTING, AGENTS or PR template found at the usual paths"

echo
echo "## 3. Your load"
open_all=$(gh api -X GET search/issues -f q="type:pr author:$ME -user:$ME state:open" --jq .total_count)
open_here=$(gh api -X GET search/issues -f q="type:pr author:$ME repo:$REPO state:open" --jq .total_count)
week=$(gh api -X GET search/issues -f q="type:pr author:$ME -user:$ME created:>=$(days_ago 7)" --jq .total_count)
flag() { [ "$1" -ge "$2" ] && echo "  <- at or over the limit of $2" || echo; }
printf '  open PRs to other repos: %s%s\n' "$open_all" "$(flag "$open_all" "$MAX_OPEN")"
printf '  open PRs in %s: %s%s\n' "$REPO" "$open_here" "$(flag "$open_here" "$MAX_PER_REPO")"
printf '  PRs opened in the last 7 days: %s\n' "$week"

if [ -n "$ISSUE" ]; then
  echo
  echo "## 4. Issue #$ISSUE"
  gh api "repos/$REPO/issues/$ISSUE" --jq '"  \(.state): \(.title)\n  labels: \([.labels[].name] | join(", "))\n  assignees: \([.assignees[].login] | join(", ") | if . == "" then "none" else . end)\n  opened \(.created_at[:10]) by \(.user.login), \(.comments) comments, updated \(.updated_at[:10])"'
  echo "  PRs that reference it:"
  gh api "repos/$REPO/issues/$ISSUE/timeline?per_page=100" --jq '
    .[] | select(.event == "cross-referenced" and .source.issue.pull_request != null)
    | .source.issue | "    #\(.number) \(.state)\(if .pull_request.merged_at then " (merged)" else "" end) by \(.user.login): \(.title)"' | sort -u
  echo "  comments that look like a claim:"
  gh api "repos/$REPO/issues/$ISSUE/comments?per_page=100" --jq '
    .[] | select(.body | test("(work on|working on|take (this|it)|assign (it to )?me|pick (this|it) up|claim|I.ll (fix|do|look)|PR (incoming|coming|soon))"; "i"))
    | "    \(.created_at[:10]) \(.user.login): \(.body | gsub("\n"; " ") | .[0:120])"'
  echo "  (nothing above means none found, not that none exist: read the thread)"
fi

if [ ${#FILES[@]} -gt 0 ]; then
  echo
  echo "## 5. Other PRs touching your files (100 most recently updated open, 50 most recently merged)"
  owner="${REPO%/*}"; name="${REPO#*/}"
  open_hits=$(mktemp)
  for state in OPEN MERGED; do
    [ "$state" = OPEN ] && n=100 || n=50
    gh api graphql -F o="$owner" -F r="$name" -F n="$n" -f s="$state" -f query='
      query($o:String!,$r:String!,$n:Int!,$s:PullRequestState!){repository(owner:$o,name:$r){
        pullRequests(states:[$s],first:$n,orderBy:{field:UPDATED_AT,direction:DESC}){nodes{
          number title state mergedAt author{login} files(first:100){nodes{path}}}}}}' \
      --jq '.data.repository.pullRequests.nodes[] | "\(.number)\t\(.state)\t\(.mergedAt // "-" | .[:10])\t\(.author.login // "?")\t\(.title)\t\([.files.nodes[].path] | join(" "))"' |
    while IFS=$'\t' read -r num st merged author title paths; do
      for f in "${FILES[@]}"; do
        case " $paths " in *" $f "*)
          [ "$merged" = "-" ] && merged=""
          echo "  #$num $st${merged:+ $merged} by $author touches $f: $title"
          [ "$st" = OPEN ] && echo "$num" >> "$open_hits" ;;
        esac
      done
    done
  done
  echo "  (no lines means no match in that window)"

  if [ ${#FUNCS[@]} -gt 0 ]; then
    echo
    echo "## 5b. Open PRs among those whose diff names your functions (read those hunks)"
    for num in $(sort -un "$open_hits"); do
      if ! diff=$(gh pr diff "$num" -R "$REPO" 2>/dev/null); then
        # Over 20000 lines GitHub refuses the diff: compare just your files at base and head.
        shas=$(gh api "repos/$REPO/pulls/$num" --jq '"\(.base.sha) \(.head.sha)"') || { echo "  #$num: diff not readable"; continue; }
        diff=""
        for f in "${FILES[@]}"; do
          diff+=$(diff <(gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$f?ref=${shas% *}" 2>/dev/null) \
                       <(gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$f?ref=${shas#* }" 2>/dev/null) \
                  | sed -n 's/^</-/p; s/^>/+/p')$'\n'
        done
      fi
      for fn in "${FUNCS[@]}"; do
        hits=$(printf '%s\n' "$diff" | grep -E '^(@@|[+-])' | grep -vE '^(\+\+\+|---) ' | grep -cF -- "$fn")
        [ "$hits" -gt 0 ] && echo "  #$num changes lines naming $fn ($hits): gh pr diff $num -R $REPO | grep -n -C5 '$fn'"
      done
    done
    echo "  (no lines means no open PR above changes a line naming them)"
  fi
  rm -f "$open_hits"
fi

echo
echo "## 6. What the project has turned down recently (last 120 days)"
# Rejections are where unwritten rules get written down. For each closed-unmerged PR
# and each issue closed as not planned, show the maintainer's last word on it.
since=$(days_ago 120)
reason() {
  gh api "repos/$REPO/issues/$1/comments?per_page=100" --jq '
    [.[] | select(.author_association | test("^(OWNER|MEMBER|COLLABORATOR)$"))] | last
    | if . == null then "      (no maintainer comment)"
      else "      \(.user.login): \(.body | gsub("\n"; " ") | .[0:160])" end' 2>/dev/null
}
gh api -X GET search/issues -f q="repo:$REPO is:pr is:unmerged is:closed closed:>=$since -author:app/dependabot -author:app/renovate" \
  -f sort=updated -f per_page=12 --jq '.items[] | "\(.number)\t\(.user.login)\t\(.title)"' |
while IFS=$'\t' read -r num author title; do
  echo "  PR #$num by $author: $title"
  reason "$num"
done
gh api -X GET search/issues -f q="repo:$REPO is:issue reason:\"not planned\" closed:>=$since" \
  -f sort=updated -f per_page=8 --jq '.items[] | "\(.number)\t\(.title)"' |
while IFS=$'\t' read -r num title; do
  echo "  issue #$num (not planned): $title"
  reason "$num"
done
echo "  Strategy files present:"
for p in ROADMAP.md docs/ROADMAP.md .github/ROADMAP.md docs/adr docs/decisions renovate.json .github/renovate.json .renovaterc .renovaterc.json .github/dependabot.yml; do
  gh api "repos/$REPO/contents/$p" --silent 2>/dev/null && echo "    $p"
done
echo "  (read the closes in the area you'd touch; an empty list is not a green light)"

echo
echo "## 7. Does their CI run on Windows?"
wf=$(gh api "repos/$REPO/contents/.github/workflows" --jq '.[].path' 2>/dev/null | head -40)
if [ -z "$wf" ]; then
  echo "  no GitHub Actions workflows found"
else
  hits=$(for p in $wf; do raw "$p" | grep -qiE 'windows-(latest|20[0-9]{2})' && echo "    $p"; done)
  [ -n "$hits" ] && { echo "  yes, in:"; echo "$hits"; echo "  so check paths and line endings"; } || echo "  not that the workflow files show"
fi
