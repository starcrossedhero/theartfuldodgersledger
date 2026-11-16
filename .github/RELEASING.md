# Releasing

Create and push an annotated version tag from the commit to release:

```bash
git tag -a v1.0.2 -m "v1.0.2"
git push origin v1.0.2
```

The WoW packager replaces the TOC's version placeholder with the tag when building the release ZIP. Unpackaged source checkouts display `development` in the chronicle.