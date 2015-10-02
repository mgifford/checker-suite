#!/usr/bin/env bash

CABAL=`which cabal`
GHC_VERSION="7.8.3"
# Some flags
NO_CONFIRM=0
FRESH_INSTALL=1
INSTALL_PREREQS=0
KEEP_PY_SANDBOX=0
KEEP_HA_SANDBOX=0
KEEP_HA_LOCAL=0
NO_HA_UPDATE=0
UPGRADE_CABAL=0

function read_input()
{
    if [ $NO_CONFIRM -eq 1 ]; then
        echo "y"
    else
        read ANS
        echo $ANS
    fi
}

function find_cabal_command()
{
    # Cabal defaults to /usr/bin/cabal . However a cabal update
    # seems to install it to ~/.cabal/bin/ folder. So this might
    # be what we want if the standard cabal binary doesn't provide
    # sandbox support.

    sandbox=`check_sandbox_support`
    if [ $sandbox="NO" ]; then
        # Try $HOME/.cabal/bin/cabal
        if [ -f "$HOME/.cabal/bin/cabal" ]; then
            CABAL=$HOME/.cabal/bin/cabal
            echo "Setting cabal binary to $CABAL . Please change your PATH accordingly later."
        fi
    fi
}

function check_dependencies() {
    echo "Checking dependencies..."

    for prog in python2 virtualenv pip2 cabal pkg-config; do
        command -v $prog >/dev/null 2>&1 \
            || { echo >&2  "$prog is required but cannot be found.\
          \nPlease install it and try again.\
          \nYou can re-run this script with the argument --install-prereqs.
          \n\n
          \nNote that you may also need the following libs:
          \n    libzm3q-dev (zmq.h) (actually zmq 4)
          \n    libpq-dev   (postgresql)"
            exit 1
        }
    done

    [[ -f "/usr/include/python2.7/pyconfig.h" ]] || {
        echo >&2 "python-dev is required."
        echo >&2 "You can re-run this script with the argument --install-prereqs."
        exit 1
    }
}

function check_sandbox_support()
{
    # Check sandbox support for cabal command
    $CABAL --help | grep sandbox >& /dev/null
    if [ $? -eq 0 ]; then
        echo "YES"
    else
        echo "NO"
    fi
}

function install_prereqs()
{
echo "Installing pre-requisite packages..."

# For debian
if which dpkg &> /dev/null; then
    echo "Debian system detected."
    sudo apt-get install cabal-install python-virtualenv python-pip python-dev libzmq3-dev libpq-dev gcc g++ -y
    [[ $? != 0 ]] && {
        echo "apt-get failed."
        exit 1
    }
    echo "Note: ghc in the repos is too old"
    echo "Instead, we're installing the binary distribution from http://www.haskell.org to /usr/local"
    DIR=${PWD}
    cd $(mktemp -d)
    ARCH=$(arch)
    GHC_ARCHIVE="ghc-${GHC_VERSION}-${ARCH}-unknown-linux-deb7.tar.xz"
    wget "https://www.haskell.org/ghc/dist/${GHC_VERSION}/${GHC_ARCHIVE}"
    tar xf ${GHC_ARCHIVE}
    cd ghc-${GHC_VERSION}
    ./configure
    sudo make install
    cd ${DIR}
fi

# For Arch
if which pacman &> /dev/null; then
    echo "ArchLinux detected."
    sudo pacman -S python2-virtualenv python2-pip zeromq cabal-install
fi

}

function upgrade_cabal()
{

sandbox=`check_sandbox_support`

if [ $sandbox="NO" ]; then
    echo "*** ERROR - Your cabal installation has no sandbox support!!! Trying to upgrade Cabal..."

    $CABAL install cabal

    if [ $? -eq 0 ]; then
        echo "Upgrade successful."
        # Set cabal $HOME/.cabal/bin/cabal
        #if [ -f "$HOME/.cabal/bin/cabal" ]; then
        #    CABAL=$HOME/.cabal/bin/cabal
        #    echo "Setting cabal binary to $CABAL . Please change your $PATH accordingly later."
        #fi
    else
        echo "Cabal upgrade failed. Please upgrade manually."
        exit 1
    fi
else
    echo "Your cabal installation is up to date.";
fi

}

function install_python_sandbox()
{

echo "### Doing sandbox for Python parts"
echo "### Deleting old sandbox"
rm -r .python-sandbox/
echo "### Creating new sandbox"
virtualenv -p /usr/bin/python2 .python-sandbox
source .python-sandbox/bin/activate
echo "### Done with initializing sandbox."

echo "### Installing py-ttrpc"
pip2 install ./py-ttrpc
echo "### Done with py-ttrpc."
echo "### Installing eiii-crawler"
pip2 install ./eiii-crawler
echo "### Done with eiii-crawler"

}

function install_haskell_sandbox()
{

## Haskell stuff

echo "### Doing sandbox for Haskell parts"
echo "### Deleting old sandbox"
$CABAL sandbox delete
echo "### Creating new sandbox"
$CABAL sandbox init
echo "### Adding library sources to sandbox"
$CABAL sandbox add-source ./hs-checker-common
$CABAL sandbox add-source ./hs-ttrpc
$CABAL sandbox add-source ./lib/html5parser
$CABAL sandbox add-source ./lib/iso639-language-codes
$CABAL sandbox add-source ./lib/msgpack-haskell/msgpack
$CABAL sandbox add-source ./lib/http-server
$CABAL sandbox add-source ./sampler
$CABAL sandbox add-source ./logging
echo "### Done with initializing sandbox."

}

function update_hackage()
{
    echo "### Updating Hackage DB"
    $CABAL update
}

function install_haskell_local()
{

# Install local haskell dependencies.

echo "### Installing databus"
## install all at once to get consistent resolution of dependencies.
$CABAL install ./databus ./accountability-proxy ./wam

}

function fresh_install()
{
    if [ $INSTALL_PREREQS -eq 1 ]; then
        install_prereqs;
    else
        # Only check dependencies and exit if not satisfied
        check_dependencies
    fi

    if [ $UPGRADE_CABAL -eq 1 ]; then
        upgrade_cabal
    fi

    # Fresh installation - Will ignore rest of the flags
    install_python_sandbox
    install_haskell_sandbox
    update_hackage
    install_haskell_local
    echo "### All done."
}

function main()
{
    # Find cabal command
    find_cabal_command

    if [ $FRESH_INSTALL -eq 1 ]; then
        echo -n "Going to do a new installation. Please confirm [y/n]: "
        ans=`read_input`

        if [ $ans == "y" -o $ans == "Y" ]; then
            fresh_install
            exit 0
        else
            echo "Aborting."
            exit 1
        fi
    fi

    echo "Doing a custom install with the following flags ..."
    echo "INSTALL_PREREQS=$INSTALL_PREREQS, KEEP_PY_SANDBOX=$KEEP_PY_SANDBOX, KEEP_HA_SANDBOX=$KEEP_HA_SANDBOX, KEEP_HA_LOCAL=$KEEP_HA_LOCAL, NO_HA_UPDATE=$NO_HA_UPDATE, UPGRADE_CABAL=$UPGRADE_CABAL"
    echo -n "Proceed [y/n]: "
    ans=`read_input`

    if [ $ans = "n" -o $ans = "N" ]; then
        echo "Aborting"
        exit 1
    fi

    # Other options
    if [ $INSTALL_PREREQS -eq 1 ]; then
        install_prereqs;
    fi

    if [ $UPGRADE_CABAL -eq 1 ]; then
        upgrade_cabal;
    fi

    if [ $KEEP_PY_SANDBOX -eq 0 ]; then
        install_python_sandbox;
    elif [ -d ".python-sandbox/" ]; then
        echo "Keeping current Python sandbox."
    else
        echo "No Python sandbox found!"
        install_python_sandbox;
    fi

    if [ $KEEP_HA_SANDBOX -eq 0 ]; then
        install_haskell_sandbox;
    else
        echo "Keeping current Haskell sandbox."
    fi

    if [ $NO_HA_UPDATE -eq 0 ]; then
        update_hackage;
    else
        echo "Not updating Hackage DB"
    fi

    if [ $KEEP_HA_LOCAL -eq 0 ]; then
        install_haskell_local;
    else
        echo "Not updating local Haskell parts"
    fi

    echo "### All done.";

}

function usage()
{

echo "sandboxes-init.sh [OPTIONS]";
echo
echo "[OPTIONS]";
echo
echo "  --fresh-install   - Do a fresh install. This is the default action.";
echo "                      This will install a new sandbox,install haskell dependencies";
echo "                      and try to insall all local packages.";
echo
echo "  --no-confirm        Assume YES for all questins. No interactive confirmation";
echo "  --install-prereqs - Will try to install pre-requisite software.";
echo "  --upgrade-cabal   - Will try to ugrade cabal if it is found to be old.";
echo "  --keep-py-sandbox - Won't try to delete and reinstall the existing Python sandbox.";
echo "  --keep-ha-sandbox - Won't try to delete and reinstall the existing Haskell sandbox.";
echo "  --keep-ha-local   - Won't try to delete and reinstall the existing local Haskell parts";
echo "  --no-ha-update    - Won't try to update the local Haskell packages.";

exit 0
}

TEMP=`getopt -l no-confirm,install-prereqs,keep-py-sandbox,keep-ha-sandbox,keep-ha-local,fresh-install,no-ha-update,upgrade-cabal,perform-action ":h" "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        --no-confirm)
            echo "Will assume YES for all"
            NO_CONFIRM=1
            shift 1
        ;;
        --fresh-install)
            echo "Doing a fresh install, some options would be ignored"
            FRESH_INSTALL=1
            shift 1
        ;;
        --install-prereqs)
            echo "Will try to install prereqs."
            INSTALL_PREREQS=1
            FRESH_INSTALL=0
            shift 1
        ;;
        --keep-py-sandbox)
            echo "Will not delete existing Python sandbox if any."
            KEEP_PY_SANDBOX=1
            FRESH_INSTALL=0
            shift 1
        ;;
        --keep-ha-sandbox)
            echo "Will not delete existing Haskell sandbox if any."
            KEEP_HA_SANDBOX=1
            FRESH_INSTALL=0
            shift 1

        ;;
        --keep-ha-local)
            echo "Will not attempt to reinstall local Haskell packages."
            KEEP_HA_LOCAL=1
            FRESH_INSTALL=0
            shift 1
        ;;
        --upgrade-cabal)
            echo "Will try to upgrade cabal"
            UPGRADE_CABAL=1
            FRESH_INSTALL=0
            shift 1
        ;;
        --no-ha-update)
            echo "Will not attempt to update Haskell packages"
            NO_HA_UPDATE=1
            FRESH_INSTALL=0
            shift 1
        ;;
        --perform-action)
            shift 2
            action="$1"
            echo "Peforming the action \"$action\" ..."
            find_cabal_command
            $action
            exit 0
        ;;
        -h )
            usage; exit 1
        ;;
        *)
            break
        ;;
    esac
done;

# Run it!
main
