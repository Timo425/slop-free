# Context fit (fork addition, not upstream)

## What this is for

The rest of this skill makes a contribution *well-made*. This file is about whether it *belongs here at all*, which is the harder question and the one an agent tends to skip.

The user often contributes to projects whose context they don't know: the project's direction, the decisions maintainers already made, what was tried and rejected, who else is working on the same thing. A competent agent can produce a clean, tested, perfectly formatted change that a maintainer still closes in ten seconds because "we don't want this". The user has learned to catch that by questioning the agent from many angles before posting, and that questioning has often changed the change or its value. Your job here is to do that questioning yourself, unprompted, and as well as you can.

A real example of the failure (from internal work, same pattern): a well-tooled dependency-upgrade scan was reported, and it was technically fine. People pushed back anyway: it was a customer project that doesn't do minor version upgrades (a strategy that existed only in the lead developer's head), there were duplicate tickets, and another team in the company had related work. None of that was visible in the code.

So treat the user's lack of context as the main risk, not the code. You can't fully fill that gap; aim to find what's findable, to say plainly what isn't, and to turn the rest into questions for someone who knows. "Don't open this" and "ask first" are good outcomes, not failures.

## Before choosing or fixing (with phase 1)

On repos with a lot of history, the bounded scout checks in `references/review-panel.md` can do these searches in parallel.

- **Read the rejections.** Closed-but-unmerged PRs and issues closed as wontfix, not planned or duplicate, with the maintainer comments. These are where unwritten rules get written down: "out of scope", "we're rewriting this", "we don't take dependency bumps". Look at the last few months and anything touching the same area. `gh pr list -R OWNER/REPO --state closed --search "is:unmerged" --limit 30`, then read the relevant ones.
- **Read the strategy, if any exists:** ROADMAP, non-goals or scope sections in README/CONTRIBUTING, ADRs or decision logs, and the dependency bot config (`renovate.json`, `.github/dependabot.yml`), which states the upgrade policy outright.
- **Look for overlap beyond duplicates:** open PRs or issues in the same area, an ongoing refactor, a fork or sibling project where the real work happens, linked discussions.
- Write down the project's direction in 2–3 sentences as you understand it. If you can't, that's a finding.

## Before writing the PR (with phase 4)

1. **Challenge the change:**
   - What does doing nothing cost? What's the simplest alternative?
   - If maintainers wanted this, why haven't they done it? (Often: they don't, or it's harder than it looks.)
   - Does it fit the direction you wrote down, or only the issue's wording?
   - Is the value worth a maintainer's review time? Cosmetic or speculative changes rarely are.
   - Who else is affected: downstream users, other open PRs, a planned rewrite?
2. **Review panel.** Run `references/review-panel.md`: collect the user's doubts, then a judge that never saw this conversation reviews the change from several perspectives and gives the verdict. On repos with a lot of history, bounded scouts gather evidence for it first, and you verify that evidence. Take a "close" seriously even if the code is fine.
3. **List what you couldn't verify:** domain behaviour you inferred, project intentions you guessed, anything you assumed because the user didn't know.

## The verdict to give the user

Not "ready". One of:

- **PR**: it fits, with the evidence (rejections read, direction checked, reviewer pass).
- **Ask first**: open an issue or comment with the specific open questions, written so a maintainer can answer in a minute. This is the cheap way to borrow context only the maintainers have.
- **Drop**: say why. It's a fine outcome.

Recommend a second look in a later session before anything public if the change is non-trivial or the verdict was close. Slow reconsideration catches what one pass doesn't.

The same steps apply to internal work: the trackers become Jira/GitLab, "maintainers" become the lead developer and neighbouring teams.
