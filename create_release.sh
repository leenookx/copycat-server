#!/bin/bash

TMP_DIR="tmp_dir"
VERSION=`cat VERSION`
RELEASE_FILE="release-"$VERSION".tar.gz"

rm -rf $TMP_DIR
rm -rf $RELEASE_FILE

git clone ~/copycat-server $TMP_DIR

FILES=`cat ignore_files`
cd $TMP_DIR
for FILE in $FILES
do
  rm -rf ${FILE}
done
cd ..

cd $TMP_DIR
cp -R ~/site-configs/copycat-server/* .
cd ..

tar -C $TMP_DIR -c -z -f $RELEASE_FILE .
