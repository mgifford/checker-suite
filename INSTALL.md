# Installing the EIII checker suite

## Dependencies

First, make sure that you have the required dependencies installed. Different
operating system distributions provide these in packages with different names.

Here is the list of dependencies:
 - ghc >=7.10
 - cabal
 - logrotate
 - phantomjs 2
 - postgresql 9.4
 - python 2
 - virtualenv 2
 - pip 2
 - zeromq 4
 - python-psycopg 2

For Debian, most of these can be installed with `apt-get`:

    sudo apt-get install  python-virtualenv python-pip python-dev libzmq3-dev\
      libpq-dev gcc g++ happy python-psycopg2 postgresql


The GHC and Cabal packages available in the Debian repositories is too old; get the source
distributions from [](http://www.haskell.org/) and install them manually
([See here for instructions](https://gist.github.com/yantonov/10083524); ignore the *stack* parts).

## Installation

Yes, this could be automated. That wouldn't be half as fun, now would it?

1. Clone the master repository and submodules

        git clone --recursive git@gitlab.tingtun.no:eiii_source/checker-suite
        cd checker-suite

2. Get Selenium-server-standalone

        cd selenium
        ./getsel.sh
        cd ..

3. Create and activate Python sandbox

        virtualenv2 -p/usr/bin/python2 .python-sandbox
        source .python-sandbox/bin/activate

4. Install Python dependencies

        pip install superlance supervisor

5. Install crawler

        pip install --allow-unverified sgmlop ./py-ttrpc ./eiii-crawler

6. Create Haskell sandbox

         cabal update
         cabal sandbox init --sandbox=.cabal-sandbox
         cabal sandbox add-source ./hs-checker-common \
           ./lib/{html5parser,iso639-language-codes,msgpack-haskell/msgpack} \
           ./sampler ./logging ./hs-ttrpc ./wam ./databus

7. Install Haskell packages (grab a cup of tea)

         cabal install ./databus ./wam

8. Create database and schema

        cd databus
        export username=$(whoami)
        export dbname=eiii
        sudo -u postgres createuser $username --createdb
        sudo -u postgres createdb -U $username $dbname
        sudo -u postgres psql -c "
            create extension if not exists \"tablefunc\";
            create extension if not exists \"uuid-ossp\";
            create language plpythonu;
            create role dba with superuser noinherit;
            grant dba to $username;
          "
        sudo -u $username psql -d$dbname -f schema.sql
        cd ..

If all the steps completed successfully, the installation of the checker suite
is now complete.


## Running the checker suite

- Update configuration in `checker-suite.conf`.
- To start the checker suite, run `./checker-suite`.

