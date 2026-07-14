# Centralize transport and session invalidation

DiscourseHttpClient owns base URL, timeout, User-Agent, Authenticated Session header injection, and the canonical 401 result. Repositories use it rather than reproducing HTTP rules. Page-specific state models may report that canonical 401 to the shared `RepositoryAuthenticationLifecycle`; the lifecycle is the sole consumer that logs out the `AuthRepository`, deduplicates concurrent invalidation, and asks the AppShell UI to synchronize. A 401 therefore clears session state once while other failures remain page-level errors.
