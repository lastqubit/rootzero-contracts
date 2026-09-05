# Repository Instructions

## Releases

Use this complete flow for every release:

1. Review everything for release readiness.
2. Resolve inconsistencies and run all verification.
3. Split the implementation into logical commits by concern.
4. Move `Unreleased` in `CHANGELOG.md` into the new version section.
5. Update the version in `package.json` and `package-lock.json`.
6. Create a final release commit.
7. Create the annotated version tag.
8. Push the commits and tag to `main`.

Do not publish releases to npm. In particular, do not run `npm publish` or
`npm run publish:package` as part of or after this release process.
