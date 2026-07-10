# Use embedded ArkWeb for User API Key authentication

The MVP opens Discourse User API Key authorization inside ArkWeb and intercepts the strictly matched `riverside://auth_redirect` callback before navigation. This preserves the existing server protocol without depending on unverified external-browser custom-scheme dispatch; the temporary RSA private key stays in memory, while the resulting Authenticated Session is HUKS-encrypted before persistence.
