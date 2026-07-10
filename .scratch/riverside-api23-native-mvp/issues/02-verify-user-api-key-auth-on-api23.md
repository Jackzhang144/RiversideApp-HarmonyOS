# Verify User API Key authentication on API 23

Type: research
Status: resolved
Blocked by: none

## Question

Can the existing RiverSide Discourse User API Key flow be reproduced by an API 23 ArkTS app without server changes? Determine the native equivalents for RSA key-pair generation, browser or Web authentication redirect handling, encrypted callback payload decoding, and persistent secure storage, including any compatibility risks that must constrain the MVP specification.

## Answer

Yes. Preserve the existing server contract and implement the User API Key flow in embedded ArkWeb: generate an in-memory RSA-2048 PKCS#1 Authorization Request, strictly intercept `riverside://auth_redirect`, decrypt and nonce-validate the payload, then encrypt the resulting Authenticated Session with HUKS before persisting ciphertext in Preferences. Do not depend on an external browser custom-scheme callback.

API 23 physical-device acceptance must prove redirect acceptance, PEM/padding interoperability, callback interception, session recovery, logout cleanup, and an authenticated request. Details and primary-source evidence: [User API Key authentication research](../../../docs/research/user-api-key-auth-api23.md).
