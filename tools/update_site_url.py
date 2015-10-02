#!/usr/bin/env python
# # coding=utf_8

import os
import sys
import psycopg2
import psycopg2.extras
psycopg2.extras.register_uuid()
psycopg2.extensions.register_adapter(dict, psycopg2.extras.Json)
import uuid
import tempfile
import codecs
import re
import string

"""
Use this script to update the site_name (the URL) for a site.
Supply the testrun_uid, the old URL and the new URL.

Example:

% update_site_url.py '4b237224-039e-47a5-99a2-cb2dd12634d9' eiii.tingtun.no eiii.eu
…
UPDATE 1
commit

%
"""

if __name__ == "__main__":
    testrun_uid = uuid.UUID(sys.argv[1])
    site_name   = sys.argv[2]
    new_site_name   = sys.argv[3]

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

    if crawler_rules["seeds"]:
        print("updating \"seeds\"")
        seeds=[]
        for url in crawler_rules["seeds"]:
            new_url = string.replace(url,site_name,new_site_name,maxreplace=1)
            seeds.append(new_url)
            print("  \"%s\" ⇒ \"%s\"".decode('utf-8') % (url, new_url))
        crawler_rules["seeds"] = seeds

    if crawler_rules["scoping-rules"]:
        print("updating \"scoping-rules\"")
        scoping_rules=[]
        for rule in crawler_rules["scoping-rules"]:
            new_url = string.replace(rule[1],site_name,new_site_name,maxreplace=1)
            scoping_rules.append([rule[0], new_url])
        print("  %s \"%s\" ⇒ \"%s\"".decode('utf-8') % (rule[0], rule[1], new_url))
        crawler_rules["scoping-rules"] = scoping_rules

    cur.execute("""UPDATE site_results
                    SET crawler_rules=%s,site_name=%s
                    WHERE site_result_uid=%s""",
                (crawler_rules,new_site_name,site_result_uid))
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

