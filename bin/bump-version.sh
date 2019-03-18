#!/bin/bash

set -e

if [ $# -ne 1 ]; then
  echo "Usage: `basename $0` <tag>"
  exit 65
fi

TAG=$1
BRANCH=$(git rev-parse --abbrev-ref HEAD)

#
# Check for dependencies
#
box -V
jsawk -h

#
# Run tests
#

vendor/bin/phpunit

#
# Remove dependencies and re-install production composer dependencies
#

rm -fr vendor
composer install --no-dev

#
# Tag & build acquia branch
#
box build

#
# Copy executable file into GH pages
#
git checkout gh-pages

cp cachetool.phar downloads/cachetool-${TAG}.phar
git add downloads/cachetool-${TAG}.phar

if [ "$BRANCH" == "acquia" ]; then
  cp cachetool.phar downloads/cachetool.phar
  git add downloads/cachetool.phar
fi

if [ "$(uname)" == "Darwin" ]; then
    SHA1=$(shasum cachetool.phar | awk '{print $1}')
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    SHA1=$(openssl sha1 cachetool.phar)
fi

JSON='name:"cachetool.phar"'
JSON="${JSON},sha1:\"${SHA1}\""
JSON="${JSON},url:\"http://lcatlett.github.io/cachetool/downloads/cachetool-${TAG}.phar\""
JSON="${JSON},version:\"${TAG}\""

if [ -f cachetool.phar.pubkey ]; then
    cp cachetool.phar.pubkey pubkeys/cachetool-${TAG}.phar.pubkeys
    git add pubkeys/cachetool-${TAG}.phar.pubkeys
    JSON="${JSON},publicKey:\"http://lcatlett.github.io/cachetool/pubkeys/cachetool-${TAG}.phar.pubkey\""
fi

#
# Update manifest
#
cat manifest.json | jsawk -a "this.push({${JSON}})" | python -mjson.tool > manifest.json.tmp
mv manifest.json.tmp manifest.json
git add manifest.json

git commit -m "Bump version ${TAG}"

#
# Go back to acquia
#
git checkout acquia

git tag ${TAG}
git push origin gh-pages
git push --tags

composer install

echo "New version created: ${TAG}."
