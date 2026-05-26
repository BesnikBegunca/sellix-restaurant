# 82 — Desktop Device Transfer Request Flow

When a desktop POS tries to activate using a license key that is already bound
to another device, the system must NOT fail with a generic error. Instead it
submits a transfer request to the API and shows the user a clear pending-
approval message.

---

## Activation Failure Flow

```
User enters key → ActivationScreen._activate()
  └─ ActivationService.activateDesktop()
       └─ POST /activation/desktop
            ├─ 200 OK  { businessId, ... }          → persist & enter app
            └─ response contains requiresTransferApproval == true
                 └─ ActivationService.requestDeviceTransfer()
                      └─ POST /licenses/request-transfer
                           ├─ 201 Created { id, status: "pending", ... }
                           │    → throw DeviceTransferRequiredException
                           └─ 409 Conflict (request already exists)
                                → return DeviceTransferResponse(isDuplicate: true)
                                → throw DeviceTransferRequiredException

ActivationScreen catches DeviceTransferRequiredException
  └─ _showTransferPendingDialog(isDuplicate: ...)
```

The `requiresTransferApproval` field may appear in:
- a 200 OK body from `/activation/desktop`
- a 4xx error body from `/activation/desktop`

Both paths are handled.

---

## API Contract

### POST /activation/desktop — transfer required response

```json
{
  "requiresTransferApproval": true,
  "licenseId": "lic-abc-123",
  "message": "License already activated on another device",
  "oldDeviceId": "dev-server-id",
  "oldDeviceName": "OfficePC"
}
```

`oldDeviceId` and `oldDeviceName` are optional; the desktop forwards them to
the transfer request when present.

### POST /licenses/request-transfer

**Request body:**

```json
{
  "licenseId": "lic-abc-123",
  "oldDeviceId": "dev-server-id",
  "oldDeviceName": "OfficePC",
  "newDeviceFingerprint": "<current device UUID from syncDeviceId()>",
  "newDeviceName": "<Platform.localHostname>",
  "reason": "Device replacement requested from desktop POS"
}
```

`oldDeviceId` and `oldDeviceName` are omitted when not supplied by the
activation response.

**Success (201):**

```json
{
  "id": "tr-001",
  "status": "pending",
  "businessId": "biz-1",
  "licenseId": "lic-abc-123",
  "requestedAt": "2026-05-26T10:00:00Z"
}
```

**Duplicate (409):**  
A pending request already exists. Treated as success — `isDuplicate = true`.

---

## UI Messages

### Dialog shown after transfer request

**Title:** `Kërkohet aprovim nga SuperAdmin`

**Body (new request):**
> Kjo licencë është përdorur më parë në një pajisje tjetër. Kërkesa për
> transferim u dërgua te SuperAdmin. Pas aprovimit, provo aktivizimin përsëri.

**Body (duplicate request):**
> Kërkesa ekziston dhe është në pritje të aprovimit.

**Buttons:** "Në rregull" | "Provo përsëri"

### Inline banner (stays on screen after dialog dismissed)

> Kërkesa për transferim u dërgua te SuperAdmin. Pas aprovimit, provo
> aktivizimin përsëri.

---

## Transfer Request Error Messages

| HTTP status | Albanian message |
|-------------|-----------------|
| 401 / 403   | Kërkesa nuk u lejua. Kontaktoni administratorin. |
| 404         | Licenca nuk u gjet. Kontrolloni çelësin e aktivizimit. |
| 409         | Kërkesa ekziston dhe është në pritje të aprovimit. |
| Network     | Nuk ka lidhje me serverin. Kontrolloni internetin dhe provoni përsëri. |
| Other       | Kërkesa për transferim dështoi (HTTP …). |

---

## Security Rules

- Activation tokens are **never persisted** when `requiresTransferApproval` is
  detected — `_persistActivation` is not called.
- The desktop does **not** mark itself as activated locally.
- The desktop does **not** cache transfer approval — approval must come from the
  server via a subsequent successful `/activation/desktop` call.
- The license key is **not** reused locally.
- Duplicate transfer requests (409) are silently treated as pending, not errors.

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/models/device_transfer_required_response.dart` | Parses `requiresTransferApproval` body |
| `lib/models/device_transfer_response.dart` | Parses `/licenses/request-transfer` response |
| `lib/services/device_transfer_exception.dart` | Exception thrown by `activateDesktop` |
| `lib/services/activation_service.dart` | `activateDesktop` + `requestDeviceTransfer` |
| `lib/screens/activation_screen.dart` | Dialog + inline banner |
| `lib/services/activation_error_message.dart` | `transferRequestErrorMessage` |
| `lib/config/api_config.dart` | `kEndpointRequestTransfer` constant |
| `test/device_transfer_test.dart` | Unit tests |

---

## Manual QA Checklist

1. **Happy path — fresh transfer request**
   - [ ] Activate device A with license key K. Works normally.
   - [ ] On device B, enter the same key K and click "Aktivizo terminalin".
   - [ ] Device B shows dialog: "Kërkohet aprovim nga SuperAdmin".
   - [ ] Device B shows inline orange banner after dismissing.
   - [ ] No activation tokens are stored on device B.
   - [ ] SuperAdmin mobile shows pending transfer request.
   - [ ] SuperAdmin approves.
   - [ ] Device B clicks "Provo përsëri" → activation succeeds.
   - [ ] Device A's license is revoked / blocked by the server.

2. **Duplicate request**
   - [ ] Repeat step 1 before approval — device B shows
         "Kërkesa ekziston dhe është në pritje të aprovimit."
   - [ ] No duplicate request created in SuperAdmin mobile.

3. **Network failure during transfer request**
   - [ ] Disconnect network before activation.
   - [ ] Error message: "Nuk ka lidhje me serverin…" is shown.
   - [ ] Activation screen remains usable (no crash, no token saved).

4. **SuperAdmin rejects transfer**
   - [ ] SuperAdmin rejects the request.
   - [ ] Device B clicks "Provo përsëri" → activation fails with appropriate
         server message (not a transfer-required loop).

---

## Rollback Notes

To disable this flow without reverting code, the API simply stops returning
`requiresTransferApproval: true` — the desktop falls back to the existing
DioException/error path as before. No local feature flag is needed.
