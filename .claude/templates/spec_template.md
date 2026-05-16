# [MECHANIC_NAME] — Implementation Spec

## Source
- Design doc: [path]
- Related ARCHITECTURE.md sections: [list]
- Date specced: [YYYY-MM-DD]

## What This Mechanic Does (Design Intent)
[2-3 paragraphs describing what player experience this creates,
in design language not implementation language]

## Data Schema Changes
- New Resources: [list with field types]
- Modified Resources: [list with what changes]
- New constants in GameConstants: [list]

## Behavior Specification
[Numbered behavior assertions. Each one must be testable.]
1. When [condition], [outcome] must occur.
2. If [state], the system transitions to [new state].

## Signals
- New signals on GameEvents: [name(payload)]
- New listeners required: [where, for what]

## Edge Cases and Failure Modes
- What if [edge case]?
- What if [failure mode]?

## Out of Scope
[Explicit list of related mechanics this spec does NOT cover]

## Open Questions for Human
[Things the translator could not decide alone]
