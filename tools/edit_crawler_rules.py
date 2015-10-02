#!/usr/bin/env python
# # coding=utf_8

import os
import sys
import simplejson as json
import psycopg2
import psycopg2.extras
psycopg2.extras.register_uuid()
psycopg2.extensions.register_adapter(dict, psycopg2.extras.Json)
#psycopg2.extras.register_default_json()
import uuid
import tempfile
import codecs

"""
Use this script edit the crawler_rules for a site.
Supply the testrun_uid and the site name.

Example:

% edit_crawler_rules.py '4b237224-039e-47a5-99a2-cb2dd12634d9' eiii.eu
…
UPDATE 1
commit

%
"""

def edit(f):
    if "EDITOR" in os.environ:
        editor = os.environ["EDITOR"]
    else:
        editor = "vi"
    os.system(editor + " " + f.name)

if __name__ == "__main__":
    testrun_uid = uuid.UUID(sys.argv[1])
    site_name   = sys.argv[2]

    conn=psycopg2.connect("dbname=eiii")
    cur=conn.cursor()

    cur.execute("""SELECT site_result_uid,
                          crawler_rules
                   FROM recent_site_results
                   WHERE testrun_uid=%s
                   AND site_name=%s
                   """,
                (testrun_uid,site_name))

    if cur.rowcount is 0:
        print("Found no site matching those parameters.")
        exit(1);

    # There will be just one result
    site_result_uid,crawler_rules = cur.fetchone() # : json

    tmp = tempfile.NamedTemporaryFile(delete=False)
    tmp.write(json.dumps(crawler_rules, sort_keys=True, indent='  '))
    tmp.close()
    edit(tmp)
    tmp = codecs.open(tmp.name, 'r', 'utf_8')
    crawler_rules_new = json.loads(tmp.read())
    tmp.close()
    os.unlink(tmp.name)
    if crawler_rules == crawler_rules_new:
        print("no change.")
        sys.exit(0)

    cur.execute("""UPDATE site_results
                    SET crawler_rules=%s
                    WHERE site_result_uid=%s""",
                (crawler_rules_new,site_result_uid))
    print(cur.statusmessage)

    # sanity check and commit
    if cur.statusmessage == 'UPDATE 1':
        print('commit.')
        conn.commit()
    else:
        print('rollback.')
        conn.rollback()
    cur.close()
    conn.close()

