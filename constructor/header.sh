#!/bin/bash
#
# NAME:  __NAME__
# VER:   __VERSION__
# PLAT:  __PLAT__
# BYTES: @SIZE_BYTES@
# LINES: @LINES@
# MD5:   __MD5__

#if osx
unset DYLD_LIBRARY_PATH
#else
export OLD_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
unset LD_LIBRARY_PATH
#endif

echo "$0" | grep '\.sh$' >/dev/null
if (( $? )); then
    echo 'Please run using "bash" or "sh", but not "." or "source"' >&2
    return 1
fi

THIS_DIR=$(cd $(dirname $0); pwd)
THIS_FILE=$(basename $0)
THIS_PATH="$THIS_DIR/$THIS_FILE"
PREFIX=__DEFAULT_PREFIX__
BATCH=0
FORCE=0
SKIP_SCRIPTS=0

while getopts "bfhp:su" x; do
    case "$x" in
        h)
            echo "usage: $0 [options]

Installs __NAME__ __VERSION__

    -b           run install in batch mode (without manual intervention),
                 it is expected the license terms are agreed upon
    -f           no error if install prefix already exists
    -h           print this help message and exit
    -p PREFIX    install prefix, defaults to $PREFIX
    -s           skip running pre/post-link/install scripts
    -u           update an existing installation
"
            exit 2
            ;;
        b)
            BATCH=1
            ;;
        f)
            FORCE=1
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
        ?)
            echo "Error: did not recognize option, please try -h"
            exit 1
            ;;
    esac
done

bzip2 --help &>/dev/null
if (( $? )); then
    echo "WARNING:
    bzip2 does not appear to be installed this may cause problems below." >&2
fi

# verify the size of the installer
wc -c "$THIS_PATH" | grep @SIZE_BYTES@ >/dev/null
if (( $? )); then
    echo "ERROR: size of $THIS_FILE should be @SIZE_BYTES@ bytes" >&2
    exit 1
fi

if [[ $BATCH == 0 ]] # interactive mode
then
#if x86 and not x86_64
    if [[ `uname -m` == 'x86_64' ]]; then
        echo -n "WARNING:
    Your system is x86_64, but you are trying to install an x86 (32-bit)
    version of __NAME__.  Unless you have the necessary 32-bit libraries
    installed, __NAME__ will not work.
    We STRONGLY recommend installing the x86_64 version of __NAME__ on
    an x86_64 system.
    Are sure you want to continue the installation? [yes|no]
[no] >>> "
        read ans
        if [[ ($ans != "yes") && ($ans != "Yes") && ($ans != "YES") &&
              ($ans != "y") && ($ans != "Y") ]]
        then
            echo "Aborting installation"
            exit 2
        fi
    fi
#endif

#if x86_64
    if [[ `uname -m` != 'x86_64' ]]; then
        echo -n "WARNING:
    Your operating system appears not to be 64-bit, but you are trying to
    install a 64-bit version of __NAME__.
    Are sure you want to continue the installation? [yes|no]
[no] >>> "
        read ans
        if [[ ($ans != "yes") && ($ans != "Yes") && ($ans != "YES") &&
              ($ans != "y") && ($ans != "Y") ]]
        then
            echo "Aborting installation"
            exit 2
        fi
    fi
#endif

    echo "
Welcome to __NAME__ __VERSION__"
#if has_readme
    echo "About __NAME__ __VERSION__:"
    more <<EOF
__README__
EOF
#endif
#if has_license
    echo -n "
In order to continue the installation process, please review the license
agreement.
Please, press ENTER to continue
>>> "
    read dummy
    more <<EOF
__LICENSE__
EOF
    echo -n "
Do you approve the license terms? [yes|no]
[no] >>> "
    read ans
    while [[ ($ans != "yes") && ($ans != "Yes") && ($ans != "YES") &&
             ($ans != "no") && ($ans != "No") && ($ans != "NO") ]]
    do
        echo -n "Please answer 'yes' or 'no':
>>> "
        read ans
    done
    if [[ ($ans != "yes") && ($ans != "Yes") && ($ans != "YES") ]]
    then
        echo "The license agreement wasn't approved, aborting installation."
        exit 2
    fi
#endif

    echo -n "
__NAME__ will now be installed into this location:
$PREFIX

  - Press ENTER to confirm the location
  - Press CTRL-C to abort the installation
  - Or specify a different location below

[$PREFIX] >>> "
    read user_prefix
    if [[ $user_prefix != "" ]]; then
        case "$user_prefix" in
            *\ * )
                echo "ERROR: Cannot install into directories with spaces" >&2
                exit 1
                ;;
            *)
                eval PREFIX="$user_prefix"
                ;;
        esac
    fi
fi # !BATCH

case "$PREFIX" in
    *\ * )
        echo "ERROR: Cannot install into directories with spaces" >&2
        exit 1
        ;;
esac

if [[ ($FORCE == 0) && (-e $PREFIX) ]]; then
    echo "ERROR: File or directory already exists: $PREFIX
If you want to update an existing installation, use the -u option." >&2
    exit 1
fi

mkdir -p $PREFIX
if (( $? )); then
    echo "ERROR: Could not create directory: $PREFIX" >&2
    exit 1
fi

PREFIX=$(cd $PREFIX; pwd)
export PREFIX

echo "PREFIX=$PREFIX"

# verify the MD5 sum of the tarball appended to this header
#if osx
MD5=$(tail -n +@LINES@ $THIS_PATH | md5)
#else
MD5=$(tail -n +@LINES@ $THIS_PATH | md5sum -)
#endif
echo $MD5 | grep __MD5__ >/dev/null
if (( $? )); then
    echo "WARNING: md5sum mismatch of tar archive
expected: __MD5__
     got: $MD5" >&2
fi

# extract the tarball appended to this header, this creates the *.tar.bz2 files
# for all the packages which get installed below
cd $PREFIX

tail -n +@LINES@ $THIS_PATH | tar xf -
if (( $? )); then
    echo "ERROR: could not extract tar starting at line @LINES@" >&2
    exit 1
fi

#if has_pre_install
if [[ $SKIP_SCRIPTS == 1 ]]; then
    export INST_OPT='--skip-scripts'
    echo "WARNING: skipping pre_install.sh by user request"
else
    export INST_OPT=''
    bash "$PREFIX/pkgs/pre_install.sh"
    if (( $? )); then
        echo "ERROR: executing pre_install.sh failed"
        exit 1
    fi
fi
#endif

PYTHON="$PREFIX/bin/python"
MSGS=$PREFIX/.messages.txt
touch $MSGS
export FORCE

install_dist()
{
    # This function installs a conda package into prefix, but without linking
    # the conda packages.  It untars the package and calls a simple script
    # which does the post extract steps (update prefix files, run 'post-link',
    # and creates the conda metadata).  Note that this is all done without
    # conda.
    echo "installing: $1 ..."
    PKG=$PREFIX/pkgs/$1.tar.bz2
    tar xjf $PKG -C $PREFIX --no-same-owner || exit 1
    if [[ $1 == '__DIST0__' ]]; then
        $PYTHON -E -V
        if (( $? )); then
            echo "ERROR:
cannot execute native __PLAT__ binary, output from 'uname -a' is:" >&2
            uname -a
            exit 1
        fi
    fi
    $PYTHON -E -s $PREFIX/pkgs/.install.py $INST_OPT || exit 1
#if not keep_pkgs
    rm $PKG
#endif
}

__INSTALL_COMMANDS__

if [[ $FORCE == 1 ]]; then
    $PYTHON -E -s $PREFIX/pkgs/.install.py --rm-dup || exit 1
fi

#if has_post_install
if [[ $SKIP_SCRIPTS == 1 ]]; then
    echo "WARNING: skipping post_install.sh by user request"
else
    bash "$PREFIX/pkgs/post_install.sh"
    if (( $? )); then
        echo "ERROR: executing post_install.sh failed"
        exit 1
    fi
fi
#endif

cat $MSGS
rm -f $MSGS
#if not keep_pkgs
rm -rf $PREFIX/pkgs
#endif

echo "installation finished."

if [[ $BATCH == 0 ]] # interactive mode
then
#if osx
    BASH_RC=$HOME/.bash_profile
    DEFAULT=yes
#else
    BASH_RC=$HOME/.bashrc
    DEFAULT=no
#endif
#if add_to_path_default is True
    DEFAULT=yes
#endif
#if add_to_path_default is False
    DEFAULT=no
#endif

    echo -n "Do you wish the installer to prepend the __NAME__ install location
to PATH in your $BASH_RC ? [yes|no]
[$DEFAULT] >>> "
    read ans
    if [[ $ans == "" ]]; then
        ans=$DEFAULT
    fi
    if [[ ($ans != "yes") && ($ans != "Yes") && ($ans != "YES") &&
                ($ans != "y") && ($ans != "Y") ]]
    then
        echo "
You may wish to edit your .bashrc or prepend the __NAME__ install location:

$ export PATH=$PREFIX/bin:\$PATH
"
    else
        if [ -f $BASH_RC ]; then
            echo "
Prepending PATH=$PREFIX/bin to PATH in $BASH_RC
A backup will be made to: ${BASH_RC}-__name__.bak
"
            cp $BASH_RC ${BASH_RC}-__name__.bak
        else
            echo "
Prepending PATH=$PREFIX/bin to PATH in
newly created $BASH_RC"
        fi
        echo "
For this change to become active, you have to open a new terminal.
"
        echo "
# added by __NAME__ installer
export PATH=\"$PREFIX/bin:\$PATH\"" >>$BASH_RC
    fi

    echo "Thank you for installing __NAME__!"
fi # !BATCH

exit 0
@@END_HEADER@@
