# Verify HDS API 23 component fit

Type: research
Status: resolved
Blocked by: none

## Question

For the MVP's navigation, tabs, topic lists, reply feedback, and contextual actions, which HDS components can be used on API 23, what imports and prerequisite configuration do they need, and where must ArkUI base components be the fallback? Confirm the China-mainland and physical-device visual-verification constraints from primary Huawei documentation.

## Answer

The five requested components are API 23 candidates in a Stage-model app imported from `@kit.UIDesignKit`: `HdsNavigation` starts at API 18, and `HdsTabs`, `HdsListItem`, `HdsSnackBar`, and `HdsActionBar` start at API 20. Preserve ArkUI fallbacks; use `HdsNavigation` for page navigation, conditionally use `HdsTabs`, use `HdsSnackBar` for lightweight feedback, and do not make `HdsActionBar` or `HdsListItem` prerequisites for the reply journey. `HdsListItem` requires a clickable and accessible topic-row prototype before adoption.

HDS is limited to Chinese mainland, and the emulator cannot validate HDS immersion effects. Treat API 23-added visual features as opt-in only after device evidence. Full sources, component imports, limitations, screen mapping, and fallback choices: [HDS API 23 component-fit research](../../../docs/research/hds-api23-component-fit.md).
