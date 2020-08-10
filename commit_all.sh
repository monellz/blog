#!/usr/bin/bash
COMMIT=$1
if [ -z "$COMMIT" ]
then
    echo "Error: need commit message"
    exit -1
fi

echo "Commit:" "$COMMIT"

hugo
cd public
git add ./
git commit -m "$COMMIT"
cd ..
git add ./
git commit -m "$COMMIT"

