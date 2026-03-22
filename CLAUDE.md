# gstack

For all web browsing, use the `/browse` skill from gstack. Never use `mcp__claude-in-chrome__*` tools.

## Available skills

- `/office-hours` - Brainstorming and idea exploration
- `/plan-ceo-review` - Strategy-level plan review
- `/plan-eng-review` - Architecture-level plan review
- `/plan-design-review` - Design-level plan review
- `/design-consultation` - Design system creation
- `/review` - Code review before merge
- `/ship` - Deploy / create PR
- `/browse` - Web browsing (use this for all browsing)
- `/qa` - Test the app
- `/qa-only` - Testing only (no code changes)
- `/design-review` - Visual design audit
- `/setup-browser-cookies` - Configure browser cookies
- `/retro` - Weekly retrospective
- `/investigate` - Debug errors
- `/document-release` - Post-ship doc updates
- `/codex` - Second opinion / adversarial code review
- `/careful` - Working with production or live systems
- `/freeze` - Scope edits to one module/directory
- `/guard` - Maximum safety mode
- `/unfreeze` - Remove edit restrictions
- `/gstack-upgrade` - Upgrade gstack to latest version

## Troubleshooting

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to build the binary and register skills.
