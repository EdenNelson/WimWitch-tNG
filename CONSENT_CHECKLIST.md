# Consent Checklist (Breaking/Major Changes)

Use this checklist before implementing any change that may alter end-user usage or backward compatibility.

## Pre-Change Analysis (Required Before Approval)

Before requesting approval, the agent must create a persisted plan. See [SPEC_PROTOCOL.md](SPEC_PROTOCOL.md).

- [ ] **Plan created and persisted:**
  - [ ] Plan exists in `.github/prompts/plan-<YYYYMMDD>-<topic>.prompt.md`
  - [ ] Plan includes Problem Statement, Analysis & Assessment, Stages with Checkpoints
  - [ ] Plan includes Consent Gate section with explicit approval request

- [ ] **Plan contains:**
  - [ ] Change summary: What will change and why
  - [ ] Affected surfaces: CLI/API/config/files/env vars/output formats
  - [ ] Compatibility impact: Breaking vs. behavioral change; who is affected
  - [ ] Risks: Technical and user-impact risks
  - [ ] Alternatives considered: Safer or incremental paths
  - [ ] Rollback strategy: How to revert safely if needed
  - [ ] Migration plan: High-level steps users must take

## Approval Gate

**Question for user:** After reviewing the written plan, do you approve this breaking/major change?

- [ ] **Explicit approval received in this session**
  - [ ] User confirms: "Yes, proceed with this plan"
  - [ ] Sign-off recorded in plan: `Approved by USERNAME on DATE`

## Implementation Phase (After Approval)

- [ ] **Implementation follows plan:**
  - [ ] Agent has read the approved plan completely
  - [ ] Agent understands rationale (Analysis & Assessment)
  - [ ] Agent verifies stages and checkpoints
  - [ ] Agent knows dependencies and constraints
  - [ ] Git commits reference the plan artifact

- [ ] **Post-change validation:**
  - [ ] All plan checkpoints verified
  - [ ] Behavior and docs align with approved plan
  - [ ] No deviations from approved scope without re-approval
  - [ ] Migration documentation updated for users

## References

- [SPEC_PROTOCOL.md](SPEC_PROTOCOL.md): Complete guidance on the Spec Protocol workflow and plan structure
- [STANDARDS_ORCHESTRATION.md](STANDARDS_ORCHESTRATION.md): Orchestration rules and non-ephemeral planning requirements
- [MIGRATION_TEMPLATE.md](MIGRATION_TEMPLATE.md): Template for documenting user-facing changes
