#!/usr/bin/env python

import fileinput
import json
import sys

data = {}

def main():
    for line0 in fileinput.input(sys.argv[1:]):
        line = line0.strip()
        if len(line) < 2 or line0[0] != '{' or line[-1] != '}':
            #print(f"[skipping line] {line}")
            continue

        try:
            j = json.loads(line)
        except json.JSONDecodeError as e:
            print(f"barf on {line0}")
            print(e)
            #raise

        when, evt, eid, rna, rid = (
            j["occurred"],
            j["event"],
            j["id"],
            j["resource"]["prefect.resource.name"],
            j["resource"]["prefect.resource.id"],
        )

        if not evt.startswith("prefect.flow-run") and not evt.startswith("prefect.task-run"):
            continue

        evt_type = evt.split(".")[1]

        def last(x):
            return x.split(".")[-1]

        rid = last(rid)
        evt = last(evt)

        if rna not in data:
            data[rna] = {}
        if rid not in data[rna]:
            data[rna][rid] = {"type": evt_type, "events": []}

        data[rna][rid]["events"].append(evt)

    err = 0
    for k in data.keys():
        for k0 in data[k].keys():
            if data[k][k0]["events"] != ["Pending", "Running", "Completed"]:
                err += 1
                print(k, k0, data[k][k0])

    print(len(data.keys()), err)

if __name__ == "__main__":
    main()
