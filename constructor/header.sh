#!/bin/sh
#
# NAME:  __NAME__
# VER:   __VERSION__
# PLAT:  __PLAT__
# MD5:   __MD5__

#if osx
unset DYLD_LIBRARY_PATH
#else
export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
unset LD_LIBRARY_PATH
#endif

if ! echo "$0" | grep '\.sh$' > /dev/null; then
    printf 'Please run using "bash"/"dash"/"sh"/"zsh", but not "." or "source".\n' >&2
    return 1
fi

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
THIS_FILE=$(basename "$0")
THIS_PATH="$THIS_DIR/$THIS_FILE"
PREFIX=__DEFAULT_PREFIX__
#if batch_mode
BATCH=1
#else
BATCH=0
#endif
FORCE=0
#if keep_pkgs
KEEP_PKGS=1
#else
KEEP_PKGS=0
#endif
SKIP_SCRIPTS=0
TEST=0
REINSTALL=0
USAGE="
usage: $0 [options]

Installs __NAME__ __VERSION__

#if batch_mode
-i           run install in interactive mode
#else
  #if has_license
-b           run install in batch mode (without manual intervention),
             it is expected the license terms are agreed upon
  #else
-b           run install in batch mode (without manual intervention)
  #endif
#endif
-f           no error if install prefix already exists
-h           print this help message and exit
#if not keep_pkgs
-k           do not clear the package cache after installation
#endif
-p PREFIX    install prefix, defaults to $PREFIX, must not contain spaces.
-s           skip running pre/post-link/install scripts
-u           update an existing installation
#if has_conda
-t           run package tests after installation (may install conda-build)
#endif
"

if which getopt > /dev/null 2>&1; then
    OPTS=$(getopt bifhkp:sut "$@" 2>/dev/null)
    if [ ! $? ]; then
        printf "%s\\n" "$USAGE"
        exit 2
    fi

    eval set -- "$OPTS"

    while true; do
        case "$1" in
            -h)
                printf "%s\\n" "$USAGE"
                exit 2
                ;;
            -b)
                BATCH=1
                shift
                ;;
            -i)
                BATCH=0
                shift
                ;;
            -f)
                FORCE=1
                shift
                ;;
            -k)
                KEEP_PKGS=1
                shift
                ;;
            -p)
                PREFIX="$2"
                shift
                shift
                ;;
            -s)
                SKIP_SCRIPTS=1
                shift
                ;;
            -u)
                FORCE=1
                shift
                ;;
#if has_conda
            -t)
                TEST=1
                shift
                ;;
#endif
            --)
                shift
                break
                ;;
            *)
                printf "ERROR: did not recognize option '%s', please try -h\\n" "$1"
                exit 1
                ;;
        esac
    done
else
    while getopts "bifhkp:sut" x; do
        case "$x" in
            h)
                printf "%s\\n" "$USAGE"
                exit 2
            ;;
            b)
                BATCH=1
                ;;
            i)
                BATCH=0
                ;;
            f)
                FORCE=1
                ;;
            k)
                KEEP_PKGS=1
                ;;
            p)
                PREFIX="$OPTARG"
                ;;
            s)
                SKIP_SCRIPTS=1
                ;;
            u)
                FORCE=1
                ;;
#if has_conda
            t)
                TEST=1
                ;;
#endif
            ?)
                printf "ERROR: did not recognize option '%s', please try -h\\n" "$x"
                exit 1
                ;;
        esac
    done
fi

# For testing, keep the package cache around longer
CLEAR_AFTER_TEST=0
if [ "$TEST" = "1" ] && [ "$KEEP_PKGS" = "0" ]; then
    CLEAR_AFTER_TEST=1
    KEEP_PKGS=1
fi

if [ "$BATCH" = "0" ] # interactive mode
then
#if x86 and not x86_64
    if [ "$(uname -m)" = "x86_64" ]; then
        printf "WARNING:\\n"
        printf "    Your system is x86_64, but you are trying to install an x86 (32-bit)\\n"
        printf "    version of __NAME__.  Unless you have the necessary 32-bit libraries\\n"
        printf "    installed, __NAME__ will not work.\\n"
        printf "    We STRONGLY recommend installing the x86_64 version of __NAME__ on\\n"
        printf "    an x86_64 system.\\n"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
#endif

#if x86_64
    if [ "$(uname -m)" != "x86_64" ]; then
        printf "WARNING:\\n"
        printf "    Your operating system appears not to be 64-bit, but you are trying to\\n"
        printf "    install a 64-bit version of __NAME__.\\n"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
#endif

#if ppc64le
    if [ "$(uname -m)" != "ppc64le" ]; then
        printf "WARNING:\\n"
        printf "    Your machine hardware does not appear to be Power8 (little endian), \\n"
        printf "    but you are trying to install a ppc64le version of __NAME__.\\n"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
#endif

#if s390x
    if [ "$(uname -m)" != "s390x" ]; then
        printf "WARNING:\\n"
        printf "    Your machine hardware does not appear to be s390x (big endian), \\n"
        printf "    but you are trying to install a s390x version of __NAME__.\\n"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
#endif

#if aarch64
    if [ "$(uname -m)" != "aarch64" ]; then
        printf "WARNING:\\n"
        printf "    Your machine hardware does not appear to be aarch64, \\n"
        printf "    but you are trying to install a aarch64 version of __NAME__.\\n"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
#endif

#if osx
    if [ "$(uname)" != "Darwin" ]; then
        printf "WARNING:\\n"
        printf "    Your operating system does not appear to be macOS, \\n"
        printf "    but you are trying to install a macOS version of __NAME__.\\n"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
#endif

#if linux
    if [ "$(uname)" != "Linux" ]; then
        printf "WARNING:\\n"
        printf "    Your operating system does not appear to be Linux, \\n"
        printf "    but you are trying to install a Linux version of __NAME__.\\n"
        printf "    Are sure you want to continue the installation? [yes|no]\\n"
        printf "[no] >>> "
        read -r ans
        if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
        then
            printf "Aborting installation\\n"
            exit 2
        fi
    fi
#endif

    printf "\\n"
    printf "Welcome to __NAME__ __VERSION__\\n"
#if has_license
    printf "\\n"
    printf "In order to continue the installation process, please review the license\\n"
    printf "agreement.\\n"
    printf "Please, press ENTER to continue\\n"
    printf ">>> "
    read -r dummy
    pager="cat"
    if command -v "more" > /dev/null 2>&1; then
      pager="more"
    fi
    "$pager" <<EOF
__LICENSE__
EOF
    printf "\\n"
    printf "Do you accept the license terms? [yes|no]\\n"
    printf "[no] >>> "
    read -r ans
    while [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
          [ "$ans" != "no" ]  && [ "$ans" != "No" ]  && [ "$ans" != "NO" ]
    do
        printf "Please answer 'yes' or 'no':'\\n"
        printf ">>> "
        read -r ans
    done
    if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ]
    then
        printf "The license agreement wasn't approved, aborting installation.\\n"
        exit 2
    fi
#endif

    printf "\\n"
    printf "__NAME__ will now be installed into this location:\\n"
    printf "%s\\n" "$PREFIX"
    printf "\\n"
    printf "  - Press ENTER to confirm the location\\n"
    printf "  - Press CTRL-C to abort the installation\\n"
    printf "  - Or specify a different location below\\n"
    printf "\\n"
    printf "[%s] >>> " "$PREFIX"
    read -r user_prefix
    if [ "$user_prefix" != "" ]; then
        case "$user_prefix" in
            *\ * )
                printf "ERROR: Cannot install into directories with spaces\\n" >&2
                exit 1
                ;;
            *)
                eval PREFIX="$user_prefix"
                ;;
        esac
    fi
fi # !BATCH

if [ "$FORCE" = "0" ] && [ -e "$PREFIX" ]; then
    printf "ERROR: File or directory already exists: '%s'\\n" "$PREFIX" >&2
    printf "If you want to update an existing installation, use the -u option.\\n" >&2
    exit 1
elif [ "$FORCE" = "1" ] && [ -e "$PREFIX" ]; then
    REINSTALL=1
fi

if ! mkdir -p "$PREFIX"; then
    printf "ERROR: Could not create directory: '%s'\\n" "$PREFIX" >&2
    exit 1
fi

# pwd does not convert two leading slashes to one
# https://github.com/conda/constructor/issues/284
PREFIX=$(cd "$PREFIX"; pwd | sed 's@//@/@')
export PREFIX

printf "PREFIX=%s\\n" "$PREFIX"

# 3-part dd from https://unix.stackexchange.com/a/121798/34459
# Using a larger block size greatly improves performance, but our payloads
# will not be aligned with block boundaries. The solution is to extract the
# bulk of the payload with a larger block size, and use a block size of 1
# only to extract the partial blocks at the beginning and the end.
extract_range () {
    # Usage: extract_range first_byte last_byte_plus_1
    blk_siz=16384
    dd1_beg=$1
    dd3_end=$2
    dd1_end=$(( ( $dd1_beg / $blk_siz + 1 ) * $blk_siz ))
    dd1_cnt=$(( $dd1_end - $dd1_beg ))
    dd2_end=$(( $dd3_end / $blk_siz ))
    dd2_beg=$(( ( $dd1_end - 1 ) / $blk_siz + 1 ))
    dd2_cnt=$(( $dd2_end - $dd2_beg ))
    dd3_beg=$(( $dd2_end * $blk_siz ))
    dd3_cnt=$(( $dd3_end - $dd3_beg ))
    dd if="$THIS_PATH" bs=1 skip=$dd1_beg count=$dd1_cnt 2>/dev/null
    dd if="$THIS_PATH" bs=$blk_siz skip=$dd2_beg count=$dd2_cnt 2>/dev/null
    dd if="$THIS_PATH" bs=1 skip=$dd3_beg count=$dd3_cnt 2>/dev/null
}

# the line marking the end of the shell header and the beginning of the payload
last_line=$(grep -anm 1 '^@@END_HEADER@@' "$THIS_PATH" | sed 's/:.*//')
# the start of the first payload, in bytes, indexed from zero
boundary0=$(head -n $last_line "$THIS_PATH" | wc -c | sed 's/ //g')
# the start of the second payload / the end of the first payload, plus one
boundary1=$(( $boundary0 + __FIRST_PAYLOAD_SIZE__ ))
# the end of the second payload, plus one
boundary2=$(( $boundary1 + __SECOND_PAYLOAD_SIZE__ ))

# verify the MD5 sum of the tarball appended to this header
#if osx
MD5=$(extract_range $boundary0 $boundary2 | md5)
#else
MD5=$(extract_range $boundary0 $boundary2 | md5sum -)
#endif

if ! echo "$MD5" | grep __MD5__ >/dev/null; then
    printf "WARNING: md5sum mismatch of tar archive\\n" >&2
    printf "expected: __MD5__\\n" >&2
    printf "     got: %s\\n" "$MD5" >&2
fi

cd "$PREFIX"

# disable sysconfigdata overrides, since we want whatever was frozen to be used
unset PYTHON_SYSCONFIGDATA_NAME _CONDA_PYTHON_SYSCONFIGDATA_NAME

# the first binary payload: the standalone conda executable
CONDA_EXEC="$PREFIX/conda.exe"
extract_range $boundary0 $boundary1 > "$CONDA_EXEC"
chmod +x "$CONDA_EXEC"

export TMP_BACKUP="$TMP"
export TMP=$PREFIX/install_tmp
mkdir -p "$TMP"

# the second binary payload: the tarball of packages
printf "Unpacking payload ...\n"
extract_range $boundary1 $boundary2 | \
    "$CONDA_EXEC" constructor --extract-tarball --prefix "$PREFIX"

"$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-conda-pkgs || exit 1

PRECONDA="$PREFIX/preconda.tar.bz2"
"$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-tarball < "$PRECONDA" || exit 1
rm -f "$PRECONDA"

#The templating doesn't support nested if statements
#if has_pre_install
if [ "$SKIP_SCRIPTS" = "1" ]; then
    export INST_OPT='--skip-scripts'
    printf "WARNING: skipping pre_install.sh by user request\\n" >&2
else
    export INST_OPT=''
#endif
#if has_pre_install and direct_execute_pre_install
    if ! "$PREFIX/pkgs/pre_install.sh"; then
#endif
#if has_pre_install and not direct_execute_pre_install
    if ! sh "$PREFIX/pkgs/pre_install.sh"; then
#endif
#if has_pre_install
        printf "ERROR: executing pre_install.sh failed\\n" >&2
        exit 1
    fi
fi
#endif

PYTHON="$PREFIX/bin/python"
MSGS="$PREFIX/.messages.txt"
touch "$MSGS"
export FORCE

# original issue report:
# https://github.com/ContinuumIO/anaconda-issues/issues/11148
# First try to fix it (this apparently didn't work; QA reported the issue again)
# https://github.com/conda/conda/pull/9073
mkdir -p ~/.conda > /dev/null 2>&1

CONDA_SAFETY_CHECKS=disabled \
CONDA_EXTRA_SAFETY_CHECKS=no \
CONDA_CHANNELS=__CHANNELS__ \
CONDA_PKGS_DIRS="$PREFIX/pkgs" \
"$CONDA_EXEC" install --offline --file "$PREFIX/pkgs/env.txt" -yp "$PREFIX" || exit 1

if [ "$KEEP_PKGS" = "0" ]; then
    rm -f "$PREFIX/pkgs/*.tar.bz2"
    rm -f "$PREFIX/pkgs/*.conda"
fi

__INSTALL_COMMANDS__

POSTCONDA="$PREFIX/postconda.tar.bz2"
"$CONDA_EXEC" constructor --prefix "$PREFIX" --extract-tarball < "$POSTCONDA" || exit 1
rm -f "$POSTCONDA"

rm -f "$CONDA_EXEC"
rm -f "$PREFIX/pkgs/env.txt"

rm -rf "$PREFIX/install_tmp"
export TMP="$TMP_BACKUP"

#if has_conda
mkdir -p "$PREFIX/envs"
#endif

#The templating doesn't support nested if statements
#if has_post_install
if [ "$SKIP_SCRIPTS" = "1" ]; then
    printf "WARNING: skipping post_install.sh by user request\\n" >&2
else
#endif
#if has_post_install and direct_execute_post_install
    if ! "$PREFIX/pkgs/post_install.sh"; then
#endif
#if has_post_install and not direct_execute_post_install
    if ! sh "$PREFIX/pkgs/post_install.sh"; then
#endif
#if has_post_install
        printf "ERROR: executing post_install.sh failed\\n" >&2
        exit 1
    fi
fi
#endif

if [ -f "$MSGS" ]; then
  cat "$MSGS"
fi
rm -f "$MSGS"
if [ "$KEEP_PKGS" = "0" ]; then
    rm -rf "$PREFIX"/pkgs
else
    # Attempt to delete the empty temporary directories in the package cache
    # These are artifacts of the constructor --extract-conda-pkgs
    find "$PREFIX/pkgs" -type d -empty -exec rmdir {} \; 2>/dev/null || :
fi

printf "installation finished.\\n"

if [ "$PYTHONPATH" != "" ]; then
    printf "WARNING:\\n"
    printf "    You currently have a PYTHONPATH environment variable set. This may cause\\n"
    printf "    unexpected behavior when running the Python interpreter in __NAME__.\\n"
    printf "    For best results, please verify that your PYTHONPATH only points to\\n"
    printf "    directories of packages that are compatible with the Python interpreter\\n"
    printf "    in __NAME__: $PREFIX\\n"
fi

if [ "$BATCH" = "0" ]; then
#if has_conda
    # Interactive mode.
  #if osx
    BASH_RC="$HOME"/.bash_profile
    DEFAULT=yes
  #else
    BASH_RC="$HOME"/.bashrc
    DEFAULT=no
  #endif
  #if initialize_by_default is True
    DEFAULT=yes
  #endif
  #if initialize_by_default is False
    DEFAULT=no
  #endif

    printf "Do you wish the installer to initialize __NAME__\\n"
    printf "by running conda init? [yes|no]\\n"
    printf "[%s] >>> " "$DEFAULT"
    read -r ans
    if [ "$ans" = "" ]; then
        ans=$DEFAULT
    fi
    if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
       [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
    then
        printf "\\n"
        printf "You have chosen to not have conda modify your shell scripts at all.\\n"
        printf "To activate conda's base environment in your current shell session:\\n"
        printf "\\n"
        printf "eval \"\$($PREFIX/bin/conda shell.YOUR_SHELL_NAME hook)\" \\n"
        printf "\\n"
        printf "To install conda's shell functions for easier access, first activate, then:\\n"
        printf "\\n"
        printf "conda init\\n"
        printf "\\n"
    else
        case $SHELL in
            *zsh) "$PREFIX/bin/conda" init zsh ;;
            *) "$PREFIX/bin/conda" init ;;
        esac
    fi
    printf "If you'd prefer that conda's base environment not be activated on startup, \\n"
    printf "   set the auto_activate_base parameter to false: \\n"
    printf "\\n"
    printf "conda config --set auto_activate_base false\\n"
    printf "\\n"
#endif

    printf "Thank you for installing __NAME__!\\n"
fi # !BATCH


#if has_conda
if [ "$TEST" = "1" ]; then
    printf "INFO: Running package tests in a subshell\\n"
    (. "$PREFIX"/bin/activate
     which conda-build > /dev/null 2>&1 || conda install -y conda-build
     if [ ! -d "$PREFIX"/conda-bld/__PLAT__ ]; then
         mkdir -p "$PREFIX"/conda-bld/__PLAT__
     fi
     cp -f "$PREFIX"/pkgs/*.tar.bz2 "$PREFIX"/conda-bld/__PLAT__/
     cp -f "$PREFIX"/pkgs/*.conda "$PREFIX"/conda-bld/__PLAT__/
     if [ "$CLEAR_AFTER_TEST" = "1" ]; then
         rm -rf "$PREFIX/pkgs"
     fi
     conda index "$PREFIX"/conda-bld/__PLAT__/
     conda-build --override-channels --channel local --test --keep-going "$PREFIX"/conda-bld/__PLAT__/*.tar.bz2
    )
    NFAILS=$?
    if [ "$NFAILS" != "0" ]; then
        if [ "$NFAILS" = "1" ]; then
            printf "ERROR: 1 test failed\\n" >&2
            printf "To re-run the tests for the above failed package, please enter:\\n"
            printf ". %s/bin/activate\\n" "$PREFIX"
            printf "conda-build --override-channels --channel local --test <full-path-to-failed.tar.bz2>\\n"
        else
            printf "ERROR: %s test failed\\n" $NFAILS >&2
            printf "To re-run the tests for the above failed packages, please enter:\\n"
            printf ". %s/bin/activate\\n" "$PREFIX"
            printf "conda-build --override-channels --channel local --test <full-path-to-failed.tar.bz2>\\n"
        fi
        exit $NFAILS
    fi
fi
#endif

exit 0
@@END_HEADER@@
