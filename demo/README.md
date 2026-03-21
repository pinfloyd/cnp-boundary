Three proofs demo

This folder contains the packaged public boundary demonstration.

Proofs
1. Proof 1 — proven replay against the live authority
2. Proof 2 — deny-path rejection for a forbidden pattern
3. Proof 3 — validation rejection for malformed input

Run
From the repository root, run:
.\demo\three-proofs-demo.ps1

Expected result
The script creates an out_YYYYMMDD_HHMMSS folder under demo\

It should print:
PROOF1_HTTP=200
PROOF2_HTTP=400
PROOF3_HTTP=400

If AB_VERIFY_EXE is already set in your shell, the script also attempts optional local verification closure for Proof 1.