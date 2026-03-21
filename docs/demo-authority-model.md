# Demo authority model

## Purpose

This document fixes the evaluation-access model for `cnp-boundary`.

The public demonstration path must prove the boundary with a small number of real server-side runs without exposing unrestricted ongoing use.

## Rule of access

The demonstration authority may be used exactly three times.

Those three runs must prove three distinct outcomes:

1. verified allow
2. verified deny
3. verified fail-closed behavior

After the third successful demonstration run, further use must be closed and available only under paid access.

## Commercial boundary

The free path is proof access, not free ongoing use.

The product is the external authority surface, not the local client wrapper.

## Isolation requirements

The demonstration authority must be isolated from paid production authority surfaces.

It must use:

- separate authority endpoint
- separate key material
- separate public key
- separate quota and metering layer
- separate monitoring and abuse controls

The demonstration authority must never share production custody material.

## Metering requirements

The usage counter must be enforced on the server side only.

Client-side counters are not trusted.

The authority must bind metering to an evaluation identity surface such as:

- issued demo credential
- token
- repo-bound identifier
- account-bound identifier
- token plus rate-limit envelope

## Response model

The authority must return low-information responses.

It may disclose the decision and a compact reason code, but it must not reveal internal policy structure or sensitive evaluation detail.

Recommended outward result classes:

- allow
- deny
- verification_failed
- demo_limit_reached
- commercial_license_required

## Abuse controls

The demonstration authority must include:

- rate limiting
- burst limiting
- replay resistance where applicable
- malformed input handling
- uniform fail-closed behavior on verification failure

## Security objective

A public evaluator must be able to prove that the boundary is real.

A non-paying user must not be able to turn the demonstration authority into a free general-use service.

## Non-goals

The demonstration authority is not the full commercial product surface.

It is a proof-of-boundary access layer.

## Release consequence

No public demo release is complete until the three-run limit is technically enforced by the authority itself.