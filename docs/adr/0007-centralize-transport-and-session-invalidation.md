# Centralize transport and session invalidation

DiscourseHttpClient owns base URL, timeout, User-Agent, Authenticated Session header injection, and the canonical 401 result. Both repositories use it rather than reproducing HTTP rules; AppShell is its sole consumer for global session invalidation, so a 401 clears session state once while other failures remain page-level errors.
