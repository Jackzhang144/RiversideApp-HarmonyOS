# Map the MVP contract from the reference client

Type: research
Status: resolved
Blocked by: none

## Question

From the Flutter reference client, identify the exact existing endpoints, headers, request fields, response models, and error states required by the agreed MVP journey: home/categories, topic list, topic detail, login, and plain-text or Discourse-Markdown reply. Record the canonical mapping using the vocabulary in `CONTEXT.md`, with no server changes proposed.

## Answer

The reference client provides a direct MVP contract: `latest.json` and `c/{categoryId}.json` for Topic lists, `site.json` plus `categories.json` for the Category hierarchy, `t/{topicId}.json?track_visit=true` plus `t/{topicId}/posts.json` for Topic/Post windows, `session/current.json` for the authenticated user, and `posts.json` with `topic_id`, `raw`, and optional `reply_to_post_number` for a Reply. Authenticated requests use the existing User API headers.

The native specification must preserve the reference behaviour that only `401` clears an Authenticated Session, keep pagination by empty result plus Topic-ID de-duplication, and make reply-response ambiguity and timeout recovery explicit API 23 real-device validation cases. Full endpoint, model, pagination, and error evidence: [MVP API contract](../../../docs/research/mvp-api-contract.md).
