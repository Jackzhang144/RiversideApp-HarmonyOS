# Keep five visible product tabs while capabilities are incomplete

The production root navigation visibly contains Home, Category, Chat, Notifications, and Account to preserve the product direction established by the UI prototype. Home, Category, and Account have real product flows; Chat and Notifications are inert placeholders that do not change the selected destination, open static pages, or produce feedback until separately specified and implemented. Their icons and labels are visually de-emphasized, never show a selected state, and are announced by accessibility services as “未实现”. Root-level horizontal content swiping is disabled so placeholder tabs cannot become selected through gestures. Home's nested tab strip remains horizontally scrollable to reveal all labels, but its content cannot page into unimplemented sorting tabs. Topic, authentication, and Reply remain secondary flows.

Account shows entries for Personal Information, RSC Wallet, My Topics, My Replies, My Drafts, My Bookmarks, App Settings, and About RiverSide. After authentication and an authoritative Full Profile load, Personal Information and the four “My” content entries are real destinations backed by their Discourse contracts. RSC Wallet, App Settings, and About RiverSide remain visually de-emphasized placeholders labelled “未实现” and never open empty destinations.

The eight Account entries remain visible before and after authentication. Before Full Profile authority is available, protected entries do not start navigation or network work. Session restoration and sign-out update their availability without hiding the persistent prototype capsule.

The authenticated Account header and Profile destinations show only server-proven Full Profile facts. Identity, groups, alumni verification, relationship state, profile fields, and capabilities come from `/u/{username}.json`; a missing low-activity summary does not invalidate identity. Email addresses are loaded only for the current user and remain read-only until a dedicated disposable email account exists. Prototype fixture identity never enters production state.

The prototype-only system-notification trigger is excluded from the production-page migration. Notification permission, test publishing, its UI control, and its supporting service remain isolated inside the prototype rather than becoming formal Message behavior.

Home retains the Search and New Topic icons as non-interactive future-capability placeholders. They use the same de-emphasized and accessibility-labelled “未实现” semantics as other placeholders and do not introduce destinations or API work in this migration.

Home is a root destination and therefore does not retain the prototype's Back action. Its header contains the Riverside title plus the two explicitly unimplemented placeholder actions only.

Of the five visible Home sorting tabs, only Latest Replies is backed by the current production state model. Latest Created, Unread, Hot, and Featured remain visually de-emphasized, accessibility-labelled “未实现” placeholders that do not switch content; their known server contracts require separate functional tickets rather than expansion inside the UI migration.

Category adopts the prototype's visual hierarchy, system Symbols, spacing, and list treatment while continuing to render the server-provided Category tree, ordering, cache, and refresh behavior. Prototype fixture names and fixture grouping labels never enter production data or presentation.

The prototype is a persistent UI experimentation area rather than temporary migration scaffolding. Account retains a floating capsule entry, visually consistent with the prototype-control capsule, that opens the prototype with its fixtures and state controls; whether this entry is exposed in Release builds is intentionally deferred. The capsule remains visible before login, while session restoration is in progress, and after login, and it floats above the root tab bar while respecting the bottom safe area.

Prototype changes never propagate automatically into formal pages. Each experiment requires explicit user approval followed by a separate production specification or ticket, and migration must reconnect the approved UI to real data, page-specific state, and existing business contracts instead of copying fixtures.

The Reply editor similarly retains Image and Mention icons only as de-emphasized, non-interactive placeholders announced as “未实现”. Production Reply behavior remains limited to plain text or Discourse Markdown source text, with no attachment or mention capability added by the UI migration.

Reply retains a live character count and the in-memory-draft notice, but does not migrate the prototype's unverified 1000-character limit. Server rejection continues through the existing error flow while preserving the draft.

Topic does not migrate the prototype's Earliest/Latest Reply-order control. Production reading preserves the current Post ordering, segmented loading, pagination recovery, and Reply entry behavior while adopting the prototype's card hierarchy and visual treatment.
