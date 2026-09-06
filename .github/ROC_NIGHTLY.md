# Roc nightly updates

This repository checks once daily at 13:07 UTC, about four hours
after the upstream 09:00 UTC build. Late publication can wait until the next day.

`.roc-version` is the compiler pin. `.github/roc-nightly.json` selects this
repository's validation workflows, including their validation-only release paths.
The controller, its tests, and job permissions are maintained in
[roc-automation](https://github.com/lukewilliamboswell/roc-automation).
The caller workflows pin shared code to `8691138c0aab4a7509e3b489e7dff7d91816264f`.
Dependabot proposes reviewed updates to Actions/workflow references.

Follow the shared [integration and permissions guide](https://github.com/lukewilliamboswell/roc-automation/blob/8691138c0aab4a7509e3b489e7dff7d91816264f/docs/integration.md)
for the PR-creation setting, action allowlists, required checks, and first live
GITHUB_TOKEN run. Keep default token permissions read-only. The updater never approves PRs and receives no protection bypass. This repository
opts into automatic merging of validated compiler-pin PRs as the initial trial.

`automation/roc-nightly` is reserved for the bot's pin-only commits. Put manual
compatibility changes on a separate branch. Candidate failures require diagnosis;
do not weaken tests or mechanically replace baselines to accept a compiler.

The PR configuration check validates the local pin and selected workflow files.
The shared repository owns the controller regression suite. Project tests remain
in this repository and run on the exact candidate commit. Scheduled bot-token
acceptance must be verified after merge; file changes alone cannot prove it.

Use the shared [OpenSSF rollout checklist](https://github.com/lukewilliamboswell/roc-automation/blob/8691138c0aab4a7509e3b489e7dff7d91816264f/docs/openssf.md)
to record project-specific evidence. This integration does not establish badge
compliance or change repository settings.


## Automatic merge trial

`auto_merge: true` in `.github/roc-nightly.json` enables the shared merge policy.
Only a verified Actions-bot commit changing `.roc-version` on the current default
branch can qualify. The isolated merge job performs no repository checkout and reads its policy at
the trusted event SHA. It rechecks both validation runs through the API and requests a squash merge of that exact candidate SHA.

The active default-branch trial ruleset requires PRs, verified signatures, an
up-to-date branch, and these GitHub Actions checks:

- `test-examples`
- `Build release bundle`
- `Test default bundle (ubuntu-latest)`

It blocks deletion and force pushes, grants no bypass, and requires zero human
approvals. Human review remains the project policy for source and automation
changes; this ruleset does not technically enforce that distinction. The bot's
pin-only eligibility is enforced by the trusted controller.

Nightly validation does not publish releases or deploy docs. A bot-token merge
also does not automatically trigger push workflows. Release publication remains
an explicit operation.

Disable merging by setting `auto_merge` to false in a PR. Disable the Update Roc
nightly workflow in GitHub Actions for an immediate stop. On rejection or failure,
inspect the updater run and retry manually after resolving the cause.

This opts into unattended dependency updates, not automated human review. It can
reduce OpenSSF Scorecard's Code-Review score; it does not establish or invalidate
the passing Best Practices badge by itself. See the shared OpenSSF guidance.
