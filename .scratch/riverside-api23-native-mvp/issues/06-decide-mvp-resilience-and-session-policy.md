# Decide MVP resilience and session policy

Type: grilling
Status: resolved
Blocked by: 03

## Question

Given the reference contract, what MVP policy should govern first load, pagination, loading, empty, network-error and retry states; optional local Category/Topic caching; reply timeout recovery; and the rule that only a 401 invalidates an Authenticated Session? Define the user-visible behaviour without adding server endpoints.

## Answer

Only the Category directory is cached, partitioned by anonymous/Authenticated Session identity and refreshed in the background. A cached Category stays visible on refresh failure with HdsSnackBar feedback and a manual refresh; Topic lists, Post windows, and reply drafts are not persisted.

Without usable content, first loads use a full loading state; successful empty results use an explicit empty state; and failures use an inline retryable error state. Pagination retains displayed items, uses a bottom loading/error state, retries only the failed page, and de-duplicates Topic/Post IDs. Only a 401 causes AppShell logout; a Reply's in-memory text survives an immediate re-login but not process death. For uncertain Reply submission, check the expected Post first, then preserve text and require an explicit manual retry rather than automatic resubmission.
