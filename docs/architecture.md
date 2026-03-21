# Architecture

## Boundary model

A client extracts the proposed change and submits it to an external authority.

The authority evaluates the proposed change against policy and returns a signed decision.

The client verifies the returned decision and enforces the result fail-closed.

## Flow

1. Proposed change is converted into an intent payload.
2. Intent is sent to the authority.
3. Authority returns admit or deny with a signed record.
4. Client verifies signature and record integrity.
5. Workflow passes only on verified admit.

## Security meaning

The admission decision is externalized.

This avoids local self-attestation and makes the control plane separable from the repository being checked.