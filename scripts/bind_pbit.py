#!/usr/bin/env python3
"""
Bind the five Snowflake connection parameters inside a Power BI template (.pbit)
so that Semantic View Autopilot can map its tables to Snowflake.

Why: the Tasty Bytes template ships with Server / Warehouse / Role / Database /
Schema parameters set to null. Autopilot drops any table whose parameters are
blank (UNBOUND_PARAMETERS). The normal route is: open the .pbit in Power BI
Desktop, enter the values, then File > Export > Power BI template. This script
is the no-Desktop shortcut - it writes the values straight into the template's
data model so the file is ready to upload.

Usage:
  python3 scripts/bind_pbit.py \
      --server  myorg-myaccount.snowflakecomputing.com \
      --warehouse TB_PBI_WH --role TB_PBI_ANALYST \
      --database TB_PBI_DEMO --schema POWERBI

Only the Python standard library is needed.
"""
import argparse, json, re, sys, zipfile
from pathlib import Path

PARAMS = {  # parameter name in the template -> CLI attribute
    "Snowflake Server": "server",
    "Snowflake Warehouse": "warehouse",
    "Snowflake Role": "role",
    "Snowflake Database": "database",
    "Snowflake Schema": "schema",
}
META = 'meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]'
NULL_RE = re.compile(r'^null\s+meta \[IsParameterQuery=true')


def bound(value):
    return '"%s" %s' % (value.replace('"', '""'), META)


def patch_schema(raw, values):
    doc = json.loads(raw.decode("utf-16-le"))
    done = []
    for expr in doc["model"]["expressions"]:
        key = PARAMS.get(expr["name"])
        if key:
            expr["expression"] = bound(values[key])
            done.append(expr["name"])
    return json.dumps(doc, separators=(",", ":")).encode("utf-16-le"), done


def patch_unapplied(raw, values):
    doc = json.loads(raw.decode("utf-16-le"))
    for q in doc.get("queries", []):
        key = PARAMS.get(q.get("name"))
        if key and q.get("text") and NULL_RE.match(q["text"][0]):
            q["text"] = [bound(values[key])]
    return json.dumps(doc, separators=(",", ":")).encode("utf-16-le")


def main():
    here = Path(__file__).resolve().parent.parent / "powerbi"
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--server", required=True, help="e.g. myorg-myaccount.snowflakecomputing.com")
    ap.add_argument("--warehouse", default="TB_PBI_WH")
    ap.add_argument("--role", default="TB_PBI_ANALYST")
    ap.add_argument("--database", default="TB_PBI_DEMO")
    ap.add_argument("--schema", default="POWERBI")
    ap.add_argument("--src", default=str(here / "Tasty Bytes Direct Query Quickstart.pbit"))
    ap.add_argument("--out", default=str(here / "TastyBytes_bound.pbit"))
    a = ap.parse_args()
    values = vars(a)

    with zipfile.ZipFile(a.src) as zin, zipfile.ZipFile(a.out, "w", zipfile.ZIP_DEFLATED) as zout:
        done = []
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "DataModelSchema":
                data, done = patch_schema(data, values)
            elif item.filename == "UnappliedChanges":
                data = patch_unapplied(data, values)
            zout.writestr(item, data)

    missing = set(PARAMS) - set(done)
    if missing:
        sys.exit("ERROR: parameters not found in template: %s" % sorted(missing))
    print("Wrote %s" % a.out)
    for name, key in PARAMS.items():
        print("  %-20s = %s" % (name, values[key]))


if __name__ == "__main__":
    main()
