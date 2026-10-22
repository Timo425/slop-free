# Review panel (fork addition)

For the question in `context-fit.md`: is this the right thing to do here, done the right way? An agent reviewing its own work misses what it already assumed. So the panel is one strong judge who never saw the conversation and reads the repo itself.

**Why one judge and no helper agents:** different perspectives come from different questions and inputs, not from more agents of the same model, which share blind spots. In a backtest on ~20 real outside PRs, evidence-gathering subagents only repeated what the judge found in its first few searches, at several times the cost. A judge run costs roughly 70–90k tokens, so run one per contribution, not in bulk.

## When

- Non-trivial contributions, before writing the PR (phase 4).
- Skip it for typo or doc fixes that a policy or issue explicitly invites.

## Step 1: the user's doubts

Ask: "What are your doubts about this, however vague?" Hunches like "do they even want this?", "feels too big" or "isn't someone else doing this?" are often the best angles. Pass them to the judge word for word.

## Step 2: the judge

**Claude Code:** Agent tool, `model: opus`, read-only (`gh`, `git`, reading files, web fetch). Give it: the diff (or the plan), the issue text, the repo's contribution and AI rules, the user's doubts, and anything you found during the context-fit searches, labelled as leads, not the whole picture. Don't pass your own opinion of the change, or the conversation. **Without subagents:** do this as a separate pass from those inputs only, and argue each perspective as if you hadn't written the change.

Prompt, adapted:

> You maintain OWNER/REPO. You haven't seen how this change was made. Read the change and as much of the repo and its history as you need: rejected PRs in this area, stated direction, overlapping work, who is assigned to the issue. The leads below are not the whole picture. Review it from each perspective in a few lines:
> 1. **Maintainer:** would you merge it, ask for changes, or close it? Base it on the project's direction and past rejections, not on code quality alone.
> 2. **Skeptic:** make the best case for not doing it at all. What does doing nothing cost? What's the simplest alternative? If maintainers wanted this, why haven't they done it?
> 3. **Downstream user:** who is affected and how? Any behaviour change they didn't ask for?
> 4. **Six months on:** what does it cost to maintain? Does it conflict with ongoing work or a planned rewrite? Is it a general fix in the right place, or a special case (a hardcoded rule for one input, a patch on a symptom) that breaks at the next small change?
> 5. **Fit:** does it match the house style and the size and shape of what gets merged here? Could it be a third of the size, or does it need a paragraph of defence to justify it? If so, say what the small version is.
> 6. **The user's doubts:** answer each one by name, with evidence. Don't drop any.
> Then give the verdict: **PR**, **Ask first** (with the exact questions a maintainer could answer in a minute), or **Drop**, plus your confidence from 1 to 5. If your confidence is 3 or lower, the verdict can't be PR: make it Ask first. Say where the evidence was thin and what you'd need to be sure. Link every claim about the project.

## Step 3: report to the user

- Check the links behind any claim the verdict depends on before repeating it.
- The verdict and confidence, the perspective that drove it, the answers to their doubts, and any open questions. Don't smooth over a "close" or a "drop" because the code is good.
- If the verdict was close or the evidence thin, recommend running the panel again in a later session before anything goes public.

Internal work (Jira/GitLab etc.): the same steps, with those trackers and neighbouring projects as sources. "Maintainer" becomes the lead developer or owning team, and the stated direction includes project agreements (e.g. "customer project: no minor version upgrades").
