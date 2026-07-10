# RiversideApp HarmonyOS

The API 23 native HarmonyOS client for the RiverSide Discourse community. It preserves the forum's existing user-facing concepts and server contract while replacing the Flutter client implementation.

## Forum

**Category**:
A named grouping of topics in the RiverSide forum.
_Avoid_: Section, channel

**Topic**:
One discussion thread, identified by its Discourse topic ID and started by its first post.
_Avoid_: Post, article

**Post**:
One message within a topic, identified by its post number. The first post starts the topic; later posts are replies.
_Avoid_: Comment

**Reply**:
A post after the first post in a topic. A reply may be addressed to the topic as a whole or to an earlier post.
_Avoid_: Comment

## Identity

**Authenticated Session**:
The user's Discourse API-key credentials paired with a client ID, which authorise authenticated forum operations.
_Avoid_: Login cookie, password session

**Authorization Request**:
A short-lived User API Key request containing an RSA key pair, client ID, nonce, requested scopes, and callback target. It exists only until its encrypted callback is validated and becomes an Authenticated Session.
_Avoid_: Authenticated Session, login session
