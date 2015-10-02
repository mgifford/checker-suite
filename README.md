# EIII checker suite

This is the main source code repository in the EIII checker suite. It pulls in
the various components of the EIII checker suite of tools. A
[Supervisor](http://supervisord.org/) configuration for launching the suite is provided.

The checker suite has been tested on Linux only.

## Installation

See [INSTALL](INSTALL.md).

## Running

The checker suite is configured in [checker-suite.conf](checker-suite.conf), and started by running `./checker-suite`.

## Main capabilities and functions 

There are three main capabilities available for use.

- Check a single web page
- Check a single web site
- Check multiple web sites

### Check a single web page

Using the command line interface, a check of a single web page can be accomplished with the ` ./checkerctl wam-check` command. For example,

    ./checkerctl wam-check http://www.example.com

will run a page check of [example.com](http://www.example.com) and return the results on stdout in YAML format.

This can be done through the HTTP interface as well. For instance, using cURL, if 'httpctl' is configured to listen on `localhost:9014` (the default):

    curl localhost:9014/wam-check?url=http://www.example.com&type=raw

This returns the checker result in JSON format.

### Checking a web site

When you start a check of  a web site, it will first be crawled and then a selection of the found URLs will be checked.

Using the HTTP interface, submit a POST request like so

    curl -XPOST localhost:9014/start-site-check?url=http://example.com

while the equivalent 'checkerctl' command is

    ./checkerctl start-site-check http://www.example.com

This generates some default crawler, sampler, and checker rules and starts the site check. It returns a UUID, the identifier for the eventual site result.

You can fetch the site result immediately, but will not contain complete information until the site check has completed. The way to get the result is as follows: 

#### HTTP:

    curl localhost:9014/site-result/<UUID>

#### CMD

    ./checkerctl get-site-result <UUID>

where `<UUID>` is the UUID of the site result. These commands return only the site result itself; for the complete result set  including page results, replace 'site-result' with site-page-results' in the commands above. This will return the tuple (site result, list of page results); be advised that the returned data may be very large.

### Check multiple web sites

It is also possible to perform checks on many sites in one go. This is termed a testrun. 

In order to start a testrun, it must first be defined. Examples in JSON and YAML format are provided.

Having defined the testrun, the file can be used in order to create a set of testrun rules in the database. This ruleset will be given a unique identifier which can be used in order to start a testrun with those rules.

Here is how to do this with the supplied example files. The CMD interface uses YAML while the HTTP interface uses JSON.

#### CMD

    # First we upload the testrun definition to the database.
    # When successful, the command returns a UUID.
    % ./checkerctl create-testrun example-testrun-rules.yml \
        example-testrun-sites.yml
    c1b69974-6839-11e5-82ef-2f129eb1698d # this is the UUID that was generated for us
    # Using the UUID for the testrun ruleset, we can start the testrun.
    # Again this returns a UUID, which identifies the testrun result.
    % ./checkerctl start-stored-testrun c1b69974-6839-11e5-82ef-2f129eb1698d
    cc0e0065-29b0-4eac-88dc-6ac8fc66c4b8

#### HTTP

    % curl -XPOST 'localhost:9014/create-testrun' -d@example-testrun.json
    6fba2dce-683a-11e5-82ef-b77119365d34
    % curl -XPOST 'localhost:9014/start-testrun/6fba2dce-683a-11e5-82ef-b77119365d34'
    fab0fbf2-c52a-4e1c-ba9d-b4751b0036ca

## What are the provided components and what do they do?

What follows are short descriptions of some of the components that make up the EIII suite.

- **Databus** -- The central hub in the checker suite. It orchestrates the things to do. It is backed by the PostgreSQL database.
  - **httpctl** -- Provides a HTTP interface to the bus.
  - **checkerctl** -- Provides a command-line interface to the bus.
- **EIII Crawler** -- This component performs the crawling of sites
- **Sampler**  -- Given a set of sampler rules and tuples (Content-Type,URL), this component selects which URLs to check.
- **WAM** -- Also known as webpage-wam, or simply “checker”, this is the component performing the actual accessibility checks.
- **{py-,hs-}TTRPC** -- The RPC implementation used for communication across the bus.
- **Supervisor** -- A process control system used to control the starting up of the suite.
- **Selenium and PhantomJS** -- In order to download web pages, the WAM uses the headless browser PhantomJS. The Selenium server is employed in order to serve up multiple instances of PhantomJS.

## Notes on working with sandboxes

### Haskell (cabal sandbox)
If you make changes to a Haskell component you can reinstall it by using
`cabal install`. For instance, if you've modified 'databus', then reinstall it
using `cabal install ./databus`.

### Python (virtualenv)
If you make changes to a Python component you can reinstall it by using
`pip install --upgrade` after having activated the virtualenv.

For instance, if you've modified 'eiii-crawler', then
reinstall it by issuing the following two commands

    source .python-sandbox/bin/activate
    pip install --upgrade ./eiii-crawler


## Licensing

The source code published here is subject to the BSD3 license. For more info, see [LICENSE](LICENSE).

