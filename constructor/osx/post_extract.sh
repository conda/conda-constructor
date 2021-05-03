#!/bin/bash
# Copyright (c) 2017 Anaconda, Inc.
# All rights reserved.

unset DYLD_LIBRARY_PATH

PREFIX="$2/__NAME_LOWER__"
PREFIX=$(cd "$PREFIX"; pwd)
export PREFIX
echo "PREFIX=$PREFIX"

CONDA_EXEC="$PREFIX/conda.exe"
chmod +x "$CONDA_EXEC"

# Create a blank history file so conda thinks this is an existing env
mkdir -p $PREFIX/conda-meta
touch $PREFIX/conda-meta/history

# Extract the conda packages but avoiding the overwriting of the
# custom metadata we have already put in place
"$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-conda-pkgs || exit 1

# See https://github.com/conda/constructor/issues/302
FAKE_HOME="$PREFIX/pkgs/.fake"
mkdir -p "$FAKE_HOME/.conda" $HOME/.conda 2>/dev/null
cp -p $HOME/.conda/environments.txt $FAKE_HOME/.conda/environments.txt 2>/dev/null

HOME="$FAKE_HOME" \
CONDA_PREFIX="$FAKE_HOME" \
CONDA_SAFETY_CHECKS=disabled \
CONDA_EXTRA_SAFETY_CHECKS=no \
CONDA_CHANNELS=__CHANNELS__ \
CONDA_PKGS_DIRS="$PREFIX/pkgs" \
"$CONDA_EXEC" install --offline --file "$PREFIX/pkgs/env.txt" -yp "$PREFIX" || exit 1

cp -p $FAKE_HOME/.conda/environments.txt $HOME/.conda/environments.txt 2>/dev/null
rm -rf $FAKE_HOME

# Move the prepackaged history file into place
mv "$PREFIX/pkgs/conda-meta/history" "$PREFIX/conda-meta/history"

# Cleanup!
rm -f "$CONDA_EXEC"
rm -f "$PREFIX/env.txt"
find "$PREFIX/pkgs" -type d -empty -exec rmdir {} \; 2>/dev/null || :

__WRITE_CONDARC__

"$PREFIX/bin/python" -V || exit 1

# This is unneeded for the default install to ~, but if the user changes the
# install location, the permissions will default to root unless this is done.
chown -R $USER "$PREFIX"
