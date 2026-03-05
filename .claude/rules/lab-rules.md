# Lab Rules — Safe Experimentation

## This Is a Sandbox

This repo is for learning and experimentation. Unlike work repos, you CAN:
- Create and delete files freely
- Test hooks, skills, and agent definitions
- Try new Claude Code features

## Safety Boundaries

Even in a sandbox, these rules apply:

1. **No production credentials** — Never store AWS keys, API tokens, or secrets in this repo
2. **No real data** — Use mock/synthetic data for testing
3. **No destructive external actions** — Don't push to other repos, don't call production APIs
4. **No AWS access** — This repo has no AWS context. Don't run AWS CLI commands here
5. **Test locally first** — Before moving experiments to work repos, verify they work here

## Before Moving to Production

When an experiment is ready to deploy to a work repo:
1. Review the skill/hook/agent definition
2. Test it in this sandbox
3. Copy (don't move) to the target repo
4. Test again in the target repo's context
