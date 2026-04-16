# Launch Batch Checklist — Phase 1

## Route inventory
| Route | Page type | Source file | Monetization mix | Notes | Status |
| --- | --- | --- | --- | --- | --- |
| `/` | home | `content/pages/home.md` | newsletter + affiliate highlights + ads reserve | Main `e-acc.ai` entrypoint | ready-for-build |
| `/hub/ai-coding-workflows` | hub | `content/hubs/ai-coding-workflows.md` | newsletter + ads reserve | Primary launch cluster | ready-for-build |
| `/hub/ai-agent-operations` | hub | `content/hubs/ai-agent-operations.md` | newsletter + ads reserve | Secondary launch cluster | ready-for-build |
| `/workflow/ship-an-ai-code-review-loop` | workflow | `content/workflows/ship-an-ai-code-review-loop.md` | affiliate + newsletter + ads | Launch workflow #1 | ready-for-build |
| `/workflow/build-a-context-passing-debug-stack` | workflow | `content/workflows/build-a-context-passing-debug-stack.md` | affiliate + newsletter + ads | Launch workflow #2 | ready-for-build |
| `/workflow/run-a-weekly-agent-ops-audit` | workflow | `content/workflows/run-a-weekly-agent-ops-audit.md` | newsletter + affiliate + ads | Launch workflow #3 | ready-for-build |
| `/compare/claude-code-vs-cursor-for-solo-repo-ships` | comparison | `content/comparisons/claude-code-vs-cursor-for-solo-repo-ships.md` | affiliate + ads + newsletter | Support BOFU page | ready-for-build |
| `/ritual` | lab | `content/pages/ritual-lab.md` | internal-nav + newsletter handoff | Preserved immersive route | preserved |

## Acceptance coverage checklist
- [x] `e-acc.ai` is the only phase-1 public domain in launch artifacts.
- [x] Workflow/tutorial pages outnumber comparison pages in the launch set.
- [x] Launch batch includes home, hubs, workflows, comparison, and ritual/lab coverage.
- [x] Each workflow has at least one related hub and comparison target.
- [x] Ads are documented as supplemental rather than primary revenue.
- [x] Newsletter capture appears on the home/hub/workflow system.

## Backlog after launch batch
| Priority | Candidate route | Reason to add next |
| --- | --- | --- |
| P1 | `/hub/ai-automation-stacks` | Gives the site a third cluster without diluting launch scope |
| P1 | `/workflow/launch-a-two-tool-automation-stack` | Extends cluster coverage with a faster-to-produce workflow |
| P2 | `/compare/claude-code-vs-openai-codex-for-solo-dev-loops` | Second BOFU page once the first coding workflow cluster has traction |
| P2 | `/hub/ai-research-workflows` | Expands into research once coding + ops content proves repeatable |

## Launch notes for implementers
- The route manifest should ship exactly these routes before additional slugs are added.
- If engineering needs fixture data before the CMS/parser exists, these markdown sources should be treated as the temporary source of truth.
- Keep `/ritual` linked from home navigation, footer, and at least one workflow CTA block so the original product DNA remains discoverable.
