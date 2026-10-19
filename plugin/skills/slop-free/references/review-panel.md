# Review panel (fork addition)

A panel for the question in `context-fit.md`: is this the right thing to do here, done the right way? One agent reviewing its own work misses what it already assumed. The panel splits the work: cheap scouts gather evidence from different places in parallel, and one strong judge, who never saw the conversation, weighs it from several perspectives.

**Why the split:** small models are good at finding and quoting things and weak at judging fit. As judges they produce plausible, generic concerns, which is noise. So scouts report facts with links and never give verdicts. Judgment goes to one strong model, which gets its range of angles from the different evidence and from being asked each perspective explicitly.

## When

- Non-trivial contributions: before writing the PR (phase 4). Scouts 1–3 can already run in phase 1, while choosing; reuse their reports later instead of re-running them.
- Skip it for typo or doc fixes that a policy or issue explicitly invites.

## How to run it

**Claude Code:** spawn the scouts in parallel with the Agent tool (`model: haiku`, read-only: `gh`, `git`, reading files, web fetch). When they're done, spawn the judge (`model: opus`) with the inputs below. Don't pass on your own opinion of the change, or the conversation.

**Agents without subagents** (Gemini, Vibe): do the scouts' searches yourself, one after another. Then run the judge pass as a separate step, working only from the evidence, the diff and the rules, and argue each perspective as if you hadn't written the change.

Give every scout: the repo (`OWNER/REPO`), the issue (if any), the files and functions touched, and a two-line description of the change. Each scout returns at most ~25 lines: findings with links and short quotes, plus "searched X, found nothing" lines. No recommendations.

## Scouts

1. **Rejections.** Closed-but-unmerged PRs and issues closed as wontfix, not planned or duplicate, from the last ~6 months and any time in the same area. For each relevant one: the link and the maintainer's reason, quoted. Start with `gh pr list -R OWNER/REPO --state closed --search "is:unmerged" --limit 50` and `gh issue list -R OWNER/REPO --state closed --search 'reason:"not planned"' --limit 50`.
2. **Strategy.** Statements of direction: ROADMAP, non-goals or scope sections, CONTRIBUTING and AI policy, ADRs or decision logs, the dependency bot config (`renovate.json`, `.github/dependabot.yml`), recent release notes, and maintainer comments in discussions that describe what the project is or isn't. Quote the lines that bear on this change.
3. **Overlap.** Open and recently closed PRs and issues touching the same files, functions or topic, whether or not they mention the issue. Recent commits in the area (is a rewrite underway?). Forks or sibling projects where this work actually happens.
4. **House style.** 3–5 recently merged PRs in the same area: size, how tests were done, how the description reads, and what maintainers asked for in review before merging.

## Judge

Inputs: the diff (or the plan, if nothing is written yet), the issue text, the repo's contribution and AI rules, and the scouts' reports. Prompt, adapted:

> You maintain OWNER/REPO. You haven't seen how this change was made. Using only the evidence below, review it from each perspective in a few lines:
> 1. **Maintainer:** would you merge it, ask for changes, or close it? Base it on the project's stated direction and past rejections, not on code quality alone.
> 2. **Skeptic:** make the best case for not doing it at all. What does doing nothing cost? What's the simplest alternative? If maintainers wanted this, why haven't they done it?
> 3. **Downstream user:** who is affected and how? Any behaviour change they didn't ask for?
> 4. **Six months on:** what does this cost to maintain? Does it conflict with ongoing work or a planned rewrite?
> 5. **Fit:** does it match the house style and the size and shape of what gets merged here?
> Then give the verdict: **PR**, **Ask first** (with the exact questions a maintainer could answer in a minute), or **Drop**. Say where the evidence was thin and what you'd need to be sure. Cite links for every claim about the project.

## Using the result

- Show the user the verdict, the perspective that drove it, and any open questions. Don't smooth over a "close" or a "drop" because the code is good.
- If the verdict is close, or the judge said the evidence was thin, recommend a second panel run in a later session before anything goes public.
- Internal work (Jira/GitLab): the scouts search those trackers and neighbouring projects instead. "Maintainer" becomes the lead developer, and the strategy sources include project agreements (e.g. "customer project: no minor upgrades").
