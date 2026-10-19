# Review panel (fork addition)

For the question in `context-fit.md`: is this the right thing to do here, done the right way? An agent reviewing its own work misses what it already assumed. The core of the panel is one strong judge who never saw the conversation. On repos with a lot of history, cheap scouts add evidence for it.

**Why it's shaped this way:**
- Small models do well on a narrow, checkable task (one question, given inputs, quote the source). Given an open question, they become confidently wrong, and several of them can agree on the same wrong finding. So scouts get bounded checks only, never verdicts, and everything they report is verified before it's used.
- Different perspectives come mostly from different inputs and questions, not from more agents of the same model, which share blind spots.
- Whether the scouts paid off is measured every run (scorecard), not assumed.

## When

- **Judge only:** most contributions, including small repos with little history. You (the orchestrator) do the context-fit searches yourself.
- **Judge + scouts:** non-trivial changes to repos with a lot of history (many closed PRs, several areas touched), where reading it all would flood your own context.
- Skip it for typo or doc fixes that a policy or issue explicitly invites.

## Step 1: the user's doubts

Ask: "What are your doubts about this, however vague?" Hunches like "do they even want this?", "feels too big" or "isn't someone else doing this?" are often the best angles. Pass them to the judge word for word. If a doubt needs facts, add a scout check for it.

## Step 2: scouts (optional, in parallel)

**Claude Code:** Agent tool, `model: haiku`, read-only (`gh`, `git`, reading files, web fetch). **Agents without subagents:** run the checks yourself, one after another.

Each scout gets **one bounded check**, the exact inputs, and the files or queries it may use. Split the checks by area of the change (the files and functions touched), so scouts don't all re-read the same history. Typical checks:

1. **Rejections in this area:** closed-unmerged PRs and not-planned/duplicate issues that touched `<files>` or mention `<function/topic>`. For each: link, plus the maintainer's closing reason, quoted. Start with `gh pr list -R OWNER/REPO --state closed --search "is:unmerged <term>" --limit 50` and `gh issue list -R OWNER/REPO --state closed --search 'reason:"not planned" <term>' --limit 50`.
2. **Stated direction:** in `<ROADMAP, README scope/non-goals, CONTRIBUTING, AI policy, ADRs/decision log, renovate.json / dependabot.yml>`, quote every line that bears on `<the change in one sentence>`.
3. **Overlap:** open or recently closed PRs and issues touching `<files>`, plus commits to `<files>` in the last 3 months. Is a rewrite or move underway?
4. **House style:** the last 3–5 merged PRs that touched `<area>`: size, tests added, description length, and the changes reviewers asked for. Quote them.
5. **A user doubt** that needs facts, phrased as a check.

Every scout answer: findings with link and quote, "searched X, found nothing" lines (a valid answer), at most ~25 lines, no recommendations.

## Step 3: verify

Before the judge sees anything, open the links for every scout finding the verdict could depend on (and a sample of the rest) and check that the quote is there and says what the scout claims. Drop anything you can't confirm and note it for the scorecard.

## Step 4: the judge

**Claude Code:** Agent tool, `model: opus`, read-only, allowed to read the repo and its history itself. Give it: the diff (or the plan), the issue text, the repo's contribution and AI rules, the user's doubts, and the verified scout findings, labelled as leads, not the whole picture. Don't pass your own opinion of the change, or the conversation. **Without subagents:** do this as a separate pass from those inputs only, and argue each perspective as if you hadn't written the change.

Prompt, adapted:

> You maintain OWNER/REPO. You haven't seen how this change was made. Read the change and as much of the repo and its history as you need; the scout findings are leads, not the whole picture. Review it from each perspective in a few lines:
> 1. **Maintainer:** would you merge it, ask for changes, or close it? Base it on the project's direction and past rejections, not on code quality alone.
> 2. **Skeptic:** make the best case for not doing it at all. What does doing nothing cost? What's the simplest alternative? If maintainers wanted this, why haven't they done it?
> 3. **Downstream user:** who is affected and how? Any behaviour change they didn't ask for?
> 4. **Six months on:** what does it cost to maintain? Does it conflict with ongoing work or a planned rewrite? Is it a general fix in the right place, or a special case (a hardcoded rule for one input, a patch on a symptom) that breaks at the next small change?
> 5. **Fit:** does it match the house style and the size and shape of what gets merged here?
> 6. **The user's doubts:** answer each one by name, with evidence. Don't drop any.
> Then give the verdict: **PR**, **Ask first** (with the exact questions a maintainer could answer in a minute), or **Drop**. Say where the evidence was thin and what you'd need to be sure. Link every claim about the project.

## Step 5: report to the user

- The verdict, the perspective that drove it, the answers to their doubts, and any open questions. Don't smooth over a "close" or a "drop" because the code is good.
- **Scorecard**, when scouts ran: per scout, findings confirmed, dropped as wrong or unverifiable, findings the judge actually used, and tokens. If scouts keep adding nothing on a kind of repo, stop using them there.
- If the verdict was close or the evidence thin, recommend running the panel again in a later session before anything goes public.

Internal work (Jira/GitLab etc.): the same steps, with those trackers and neighbouring projects as sources. "Maintainer" becomes the lead developer or owning team, and the stated direction includes project agreements (e.g. "customer project: no minor version upgrades").
