# AppShell owns navigation and session

The MVP has one AppShell that owns the ArkUI navigation stack and the current Authenticated Session. Pages own only presentation state and request transitions through AppShell-facing actions, preventing individual screens from coupling directly to session persistence, ArkWeb authentication, or global 401 handling.
