---
name: hello-world
description: A starter example skill. Demonstrates the SKILL.md format with frontmatter, instructions, and tool restrictions.
allowed-tools: Read, Glob
---

# Hello World Skill

This is a minimal skill to demonstrate the format.

When invoked:
1. List the files in the current directory using Glob
2. Read the README.md if it exists
3. Summarise what this repo contains in 3 bullet points

This skill is read-only (allowed-tools: Read, Glob) — it can't modify anything.
