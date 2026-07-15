# Local signing

DevEco Studio writes local HarmonyOS signing material directly into
`app/build-profile.json5`. The generated values include machine-specific paths
and encrypted credential fields, so they must remain local and must not enter a
Git commit.

This repository keeps the committed `build-profile.json5` free of signing
material and protects the staged version with a pre-commit hook.

Enable the repository hooks once per checkout:

```bash
git config core.hooksPath .githooks
```

After DevEco Studio generates a local signing configuration, leave
`app/build-profile.json5` unstaged. The local file can still be used by
`devecocli build` and `devecocli run`; the hook only inspects content selected
for the next commit.
