# Note Templates

## Decision Record

```markdown
# Decision: <Title>

## Context
<Why this decision was needed — 1-2 sentences>

## Decision
<What was decided — 1 sentence>

## Observations
- [decision] <The choice made> #<domain>
- [requirement] <Key constraint that drove the decision> #<area>
- [fact] <Supporting evidence> #<topic>
- [insight] <Key realization> #<topic>

## Rationale
<Why this option over alternatives — bullet points>

## Consequences
<What this means going forward — bullet points>

## Relations
- implements [[<Spec or Plan>]]
- affects [[<Impacted System>]]
- contrasts_with [[<Alternative Considered>]]
```

## Discovery / Troubleshooting

```markdown
# Discovery: <Title>

## Context
<What was the symptom or trigger>

## Observations
- [problem] <What was wrong> #<area>
- [insight] <Root cause finding> #<topic>
- [solution] <What fixed it> #<topic>
- [technique] <Debugging method used> #<approach>
- [fact] <Measurable impact> #metrics

## Resolution
<Summary of the fix>

## Relations
- relates_to [[<Affected System>]]
- caused_by [[<Root Cause Entity>]]
```

## Conversation Summary

```markdown
# Conversation: <Topic> - <Date>

## Summary
<2-3 sentence overview>

## Key Points
<Bullet points of main discussion items>

## Observations
- [decision] <Any decisions made> #<topic>
- [insight] <Key realizations> #<topic>
- [action] <Follow-up tasks> #task
- [fact] <Important facts established> #<topic>

## Relations
- relates_to [[<Related Topic>]]
- follows [[<Previous Conversation>]]
- leads_to [[<Next Steps Entity>]]
```

## Plan / Action Items

```markdown
# Plan: <Title>

## Overview
<What this plan covers>

## Observations
- [requirement] <Key constraint> #<area>
- [action] <Task to complete> #task
- [decision] <Approach chosen> #<topic>

## Timeline
<Milestones or phases>

## Relations
- implements [[<Strategy or Goal>]]
- requires [[<Dependency>]]
- affects [[<Impacted System>]]
```

## Learning

```markdown
# Learning: <Title>

## What We Learned
<Core insight in 1-2 sentences>

## Observations
- [technique] <Method or approach learned> #<topic>
- [fact] <Key fact discovered> #<area>
- [insight] <Why this matters> #<topic>

## How This Helps
<Practical applications>

## Relations
- relates_to [[<Domain>]]
- extends [[<Prior Knowledge>]]
```
