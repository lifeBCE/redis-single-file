# Releasing

Releases are published from `.github/workflows/release.yml` through RubyGems
trusted publishing. The workflow accepts only a `v<gem-version>` tag attached
to a commit contained in `main`, runs the test, lint, and package-build gates,
and then enters the protected `release` environment before publishing.

## One-time setup

1. In the GitHub repository settings, create an environment named `release`.
2. Add a required reviewer and restrict deployment branches and tags to the
   protected tag pattern `v*`.
3. Ensure every owner of the `redis-single-file` gem has MFA enabled on
   RubyGems.org.
4. Add a GitHub Actions trusted publisher to the gem on RubyGems.org with:

   | Field | Value |
   | --- | --- |
   | Repository owner | `lifeBCE` |
   | Repository name | `redis-single-file` |
   | Workflow filename | `release.yml` |
   | Environment | `release` |

5. After the first trusted release succeeds, remove the obsolete
   `RUBYGEMS_API_KEY` secret from the GitHub repository.

The trusted publisher should be registered only after `release.yml` is present
on the repository's default branch.

## Release a version

1. Update `RedisSingleFile::VERSION`, `Gemfile.lock`, and `CHANGELOG.md` in a
   pull request.
2. Merge the pull request after every required check passes.
3. Create an annotated tag on the release commit and push it:

   ```bash
   git switch main
   git pull --ff-only origin main
   version="$(ruby -Ilib -rredis_single_file/version -e 'print RedisSingleFile::VERSION')"
   git tag -a "v${version}" -m "Release ${version}"
   git push origin "v${version}"
   ```

4. Approve the `release` environment deployment after verifying the tag,
   commit, and version shown by the workflow.

Do not tag a feature branch or rerun an old tag for a different gem version.
