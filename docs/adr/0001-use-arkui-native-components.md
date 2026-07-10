# Use HDS-first ArkUI native components

The API 23 phone MVP will use ArkTS and ArkUI. UI Design Kit (HDS) extension components and visual capabilities are preferred for navigation, tabs, list items, feedback, and actions; ArkUI base components are the fallback only when HDS has no suitable component or cannot satisfy the API 23 requirement. The Flutter client is a reference for information architecture and interaction semantics, not a pixel-level visual target.

## Constraints

- HDS is used only for the Chinese mainland distribution scope.
- HDS immersion effects require API 23 physical-device visual acceptance; the emulator is limited to structure and basic interaction regression.
- Every intended HDS component must be researched and confirmed for API 23 before it is selected. Compatibility with newer HDS capabilities is never assumed.
