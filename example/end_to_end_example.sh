#!/bin/bash
__doc__="
A simple demo of transcrypt
"

TMP_DIR=$HOME/tmp/transcrypt-demo
mkdir -p "$TMP_DIR"
rm -rf "$TMP_DIR"


# Make a git repo and add some public content
DEMO_REPO=$TMP_DIR/repo
mkdir -p "$DEMO_REPO"
cd "$DEMO_REPO"
git init
echo "content" > README.md
git add README.md
git commit -m "add readme"


# Create safe directory that we will encrypt
echo "
safe/* filter=crypt diff=crypt merge=crypt
" > .gitattributes
git add .gitattributes
git commit -m "add attributes"

mkdir -p "$DEMO_REPO"/safe


# Configure transcrypt with legacy defaults
transcrypt -c aes-256-cbc -p 'correct horse battery staple' -md MD5 --use-pbkdf2=0 -sm password -y

echo "Secret contents" > "$DEMO_REPO"/safe/secret_file
cat "$DEMO_REPO"/safe/secret_file

git add safe/secret_file
git commit -m "add secret with config1"
transcrypt -s safe/secret_file


# Rekey with more secure settings
transcrypt --rekey -c aes-256-cbc -p 'correct horse battery staple' -md SHA256 --use-pbkdf2=1 -sm password -y
git commit -am "changed crypto settings"


echo "New secret contents" >> "$DEMO_REPO"/safe/secret_file
git commit -am "added secrets"

transcrypt -f -y
