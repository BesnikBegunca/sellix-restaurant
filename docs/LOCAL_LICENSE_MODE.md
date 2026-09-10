# Local license mode

The POS application is intentionally self-contained. It does not call an
external API during startup, activation, license verification, or normal POS
use.

## Developer flow

1. Select **Developer access / Hyrje developer**.
2. Enter the owner or business name.
3. Enter the license duration in days (`1`–`3650`).
4. Generate and copy the signed license code.
5. Give the code to the owner.

## Owner flow

1. Paste the code into the activation screen.
2. Select **Verifiko çelësin**.
3. Enter a branch code.
4. Select **Aktivizo terminalin**.

The code contains an expiry date and a signed identifier. It is validated
locally and cannot be changed without invalidating the signature. The active
license key is stored in local SQLite metadata; activation tokens are stored
using the platform secure storage provider.

This mode is suitable for an installation where the developer and owner
exchange the generated code manually. It does not provide central revocation
or cross-device synchronization because those require a server.
