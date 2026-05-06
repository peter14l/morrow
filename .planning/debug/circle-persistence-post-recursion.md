---
status: investigating
trigger: "Investigate and fix persistent infinite recursion on post deletion and circle persistence."
created: 2025-01-24T16:00:00Z
updated: 2025-01-24T16:00:00Z
---

## Current Focus

hypothesis: Infinite recursion is caused by a trigger on `posts` (likely `decrement_user_posts_count`) updating `profiles`, which triggers a recursive UPDATE policy on `profiles`. Circle persistence issue is due to missing or incorrect DELETE policies.
test: Examine trigger definitions and RLS policies in `supabase/` directory.
expecting: Find `profiles` update policies that call functions or subqueries that depend on `profiles` itself.
next_action: Search for trigger functions and RLS policies.

## Symptoms

expected: Posts deleted without recursion error; Circles stay deleted.
actual: "infinite recursion detected in policy for relation 'profiles'" when deleting posts; Circles reappear after restart.
reproduction: Delete a post; Delete a circle and restart.
started: after implementing circle posts.

## Eliminated

## Evidence

## Resolution

root_cause: 
fix: 
verification: 
files_changed: []
