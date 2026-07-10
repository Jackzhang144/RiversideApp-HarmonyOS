# Decide native module and navigation boundaries

Type: grilling
Status: resolved
Blocked by: 01, 02, 03

## Question

Given the verified HDS/API 23 fit, authentication feasibility, and API contract, what ArkTS module boundaries, navigation ownership, session-state model, and dependency direction make the MVP simple to implement and test while preserving the agreed user journey?

## Answer

Use a single AppShell as composition root. It owns the root Home/Category tab layout, `NavPathStack`, and the current Authenticated Session; Topic detail, login, and reply are pushed secondary pages. Pages render only feature state models. Home, Category, and Topic state models depend on ForumRepository; AuthRepository separately owns ArkWeb authorization, temporary RSA material, HUKS persistence, restoration, and logout.

Both repositories use DiscourseHttpClient, which owns base URL, timeouts, User-Agent, authenticated header injection, and the canonical 401 result. AppShell alone converts that result into global logout; all other failures remain feature-level errors. The final modules are therefore `app` (AppShell/routes), `core` (transport), `auth`, `forum`, and `features` (home, category, topic, login/reply presentation). Dependencies point only toward the core/repository layers, never from them into ArkUI pages.
