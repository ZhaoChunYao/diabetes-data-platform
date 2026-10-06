#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${1:-https://github.com/ZhaoChunYao/diabetes-data-platform.git}"
BRANCH="${2:-main}"
COMMIT_MESSAGE="${3:-Publish verified four-phase deployment project}"
SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING="$(mktemp -d -t diabetes-data-platform-publish-XXXXXX)"

cleanup() {
  rm -rf -- "$STAGING"
}
trap cleanup EXIT

echo "Cloning $REPOSITORY into a temporary staging directory..."
git clone --branch "$BRANCH" "$REPOSITORY" "$STAGING"

# Replace the cloned working tree while preserving only its .git directory.
find "$STAGING" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf -- {} +
find "$SOURCE" -mindepth 1 -maxdepth 1 ! -name .git -exec cp -a -- {} "$STAGING"/ \;

# Never publish data, credentials, local transcripts, or raw API payloads.
find "$STAGING" -type d \( \
  -name dataset -o -name sql_dump -o -name __pycache__ -o \
  -name .venv -o -name .pytest_cache \
\) -prune -exec rm -rf -- {} +
find "$STAGING" -type f -name '.env' -delete
find "$STAGING" -type f -name '.env.*' ! -name '.env.example' -delete
find "$STAGING" -type f \( \
  -name '*accessKeys*.csv' -o -name '*credentials*.csv' -o \
  -name '*.secret' -o -name '*environment-final*.txt' -o \
  -name 'Windows PowerShell.txt' -o -name 'phase6-final-verification-*.txt' -o \
  -name '*.pyc' -o -name '*.pyo' \
\) -delete

# Redact account-specific identifiers from the public staging copy.
while IFS= read -r -d '' file; do
  sed -E -i \
    -e 's#arn:aws:iam::[0-9]{12}:#arn:aws:iam::<account-id>:#g' \
    -e 's#[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com#<account-id>.dkr.ecr.<region>.amazonaws.com#g' \
    -e 's#arn:aws:s3:::[a-z0-9.-]+#arn:aws:s3:::<backup-bucket>#g' \
    -e 's#s3://[a-z0-9.-]+/#s3://<backup-bucket>/#g' \
    "$file"
done < <(find "$STAGING" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.md' -o -name '*.ps1' \) -print0)

git -C "$STAGING" add --all

secret_assignment='SECRET''_ACCESS_KEY=[^<[:space:]]+'
private_word='PRIVATE KEY'
private_marker="-----BEGIN .*${private_word}-----"
forbidden="$(git -C "$STAGING" grep --cached -I -n -E "AKIA[0-9A-Z]{16}|${private_marker}|${secret_assignment}" || true)"
if [[ -n "$forbidden" ]]; then
  echo 'Refusing to publish: a credential-like value was found in staged files.' >&2
  echo "$forbidden" >&2
  exit 1
fi

git -C "$STAGING" diff --cached --check
echo 'Files that will be committed:'
git -C "$STAGING" diff --cached --name-status
git -C "$STAGING" commit -m "$COMMIT_MESSAGE"
git -C "$STAGING" push origin "$BRANCH"
echo 'Public repository update completed.'
