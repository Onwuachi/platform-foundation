#!/usr/bin/env bash
# Repo cleanup — run from platform-foundation/ root.
# Review with `git status` after, before committing.
set -e

echo "== Stale/duplicate Hugo site copies =="
git rm -rf hugo-updated/
git rm -f hugobuild-updated.tar.gz
git rm -f apps/hugo/hugo-service-bak-20260613.tar.gz

echo "== Old prototype, unrelated lineage =="
git rm -rf my-hugo-site/

echo "== Early-learning lab leftovers =="
git rm -rf devops-lab-hugo/
git rm -rf devops-lab-admin-ui/
git rm -rf wordpress-docker/
git rm -rf hello-docker-node/

echo "== Unused Packer/cloud-init learning material (packer.zip alone is 23MB) =="
git rm -rf infra/packer_ami_files/

echo "== Bak/catch-all dirs =="
git rm -rf infra/archive/
git rm -rf infra/admin-ui-Pending/
git rm -rf infra/unused-api/

echo "== Stray backup file =="
git rm -f .gitignore-bak

echo "== Auto-generated, untested service scaffolds =="
git rm -rf apps/analytics/
git rm -rf apps/billings/
git rm -rf apps/invoices/
git rm -rf apps/payments/
git rm -rf apps/derrick-app/

echo "== Binary tool that shouldn't be tracked in git =="
git rm -f session-manager-plugin.deb

echo
echo "Done staging deletions. Review with: git status"
echo "Then: git commit -m \"chore: repo cleanup — remove stale duplicates, dead lab code, and untested scaffolds\""
