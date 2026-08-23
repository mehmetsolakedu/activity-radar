## Summary

Describe the user problem and the smallest coherent change.

## Scope

- In scope:
- Explicitly out of scope:

## Privacy and safety

- [ ] Codex-owned state remains read-only.
- [ ] No task text, identifiers, local paths, or account data were added.
- [ ] Examples and fixtures are synthetic.
- [ ] No dashboard, diagnostics, research-ledger, or background path
      transmits Codex content or starts an agent call.
- [ ] Any Wingman change preserves the exact intended JSON preview, one-shot
      consent, redaction, bounds, separately opt-in prompt excerpts and derived
      text signals, authentication-only temporary home, cleanup, and the
      documented residual local-read boundary.
- [ ] Research logging remains opt-in, local, content-free, and bounded.
- [ ] Lifecycle confirmations remain explicit and reversible.
- [ ] Abstention and snooze/waiting intent are preserved.
- [ ] Security-sensitive changes were reported privately before this pull request.

Explain any item that is not applicable or that required a design decision.

## Verification

- [ ] swift run ActivityRadarSelfTest
- [ ] continuity-store privacy harness
- [ ] swift build -c release --product ActivityRadar
- [ ] packaged app verification, when packaging or UI behavior changed
- [ ] native accessibility/UI check, when user-visible behavior changed

Paste concise pass/fail summaries only. Reviewed aggregate diagnostics are
allowed; private task data is not.

## Claim boundary

- [ ] The description distinguishes implemented behavior from untested user,
      scientific, publication, or distribution claims.
