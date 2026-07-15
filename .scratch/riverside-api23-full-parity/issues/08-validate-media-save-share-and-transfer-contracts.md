# 08 — 验证媒体选择、保存、分享与传输契约

Type: research
Status: resolved
Blocked by: 02

## Question

What exact API 23 phone implementation and acceptance contract can reproduce Flutter's image selection, upload, gallery save, external share, and resumable transfer behaviours with minimum permissions?

Use official API documentation and a narrow source-level feasibility check to resolve PhotoPicker URI lifetime, Request Kit upload/download behaviour, SaveButton or creation-dialog authorisation, and Share Kit URI/MIME/target failure handling. Record required permissions, user-consent points, and real-device acceptance cases; do not add permissions or production code in this ticket.

## Answer

The implementation-ready contract is recorded in [API 23 媒体选择、上传、保存、分享与传输契约](../../../docs/research/api23-media-save-share-transfer-contracts.md). It keeps `ohos.permission.INTERNET` as the sole required manifest permission: PhotoPicker selection is copied into the app cache before multipart upload, and SaveButton or the official save authorisation dialog handles explicit gallery-save consent.

The frozen Flutter reference contains image selection, Discourse multipart upload, image saving, copying a link, and opening a browser. It contains no media-share or resumable-transfer implementation. Share Kit and `request.agent` are feasible future APIs, but are explicitly not parity commitments; a true resumable upload needs a server-side protocol that is outside this project’s allowed scope.

No production code, manifest permission, server contract, or test data was changed.
