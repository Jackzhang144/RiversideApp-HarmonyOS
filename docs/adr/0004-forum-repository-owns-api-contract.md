# ForumRepository owns the forum API contract

All HTTP transport and Discourse JSON decoding for the MVP live behind ForumRepository. Page-specific state models own loading, pagination, and presentation errors, while ArkUI pages render that state and request actions without calling the network directly.
