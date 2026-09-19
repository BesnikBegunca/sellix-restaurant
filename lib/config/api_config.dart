/// Production SelliX web — licenses, owner portal, and sales sync.
const String kSellixWebBaseUrl =
    'https://sellixweb-production.up.railway.app';

/// Localhost fallback kept for reference only — not used at runtime.
///
/// The active base URL is resolved by [RuntimeConfigService] from
/// `app_config.json` beside the executable, the `POS_API_BASE_URL` env var,
/// or [kSellixWebBaseUrl].
const String kApiBaseUrl = kSellixWebBaseUrl;

const String kHeaderLicenseKey = 'x-license-key';

// ── SelliX web endpoints ──────────────────────────────────────────────────

/// POST {licenseKey, deviceId, deviceName?} → business + license
const String kEndpointLicenseActivate = '/api/license/activate';

/// POST {licenseKey, deviceId} → business + license (must already be bound)
const String kEndpointLicenseCheck = '/api/license/check';

/// POST {deviceId, sales: [...]} — owner-portal takings + table totals
const String kEndpointSalesSync = '/api/sales/sync';

// ── Legacy NestJS paths (unused against SelliX web) ───────────────────────

/// POST {activationKey} → [ActivationValidateResponse]
const String kEndpointValidateKey = '/activation/validate-key';

/// POST {activationKey, branchCode, deviceUuid, deviceName, platform}
/// → [ActivationResponse]
const String kEndpointActivateDesktop = '/activation/desktop';

/// GET — Bearer token required; 200 = valid, 401 = expired/revoked.
const String kEndpointVerifyActivation = '/activation/verify';

/// POST {refreshToken} — no auth header required; 200 = {accessToken, refreshToken, licenseExpiresAt}.
const String kEndpointRefreshToken = '/activation/refresh';

/// POST {events: [...outbox rows with decoded payloadJson]}
/// → {accepted: [uuid], duplicates: [uuid], rejected: [{uuid, reason}]}
const String kEndpointSyncPush = '/sync/push';

/// GET ?since=[ISO-8601 cursor]&limit=[int]
/// → {serverTime, cursor, entities: {categories, products, shifts, sales, ...}}
const String kEndpointSyncPull = '/sync/pull';

/// POST {licenseId, oldDeviceId?, oldDeviceName?, newDeviceFingerprint, newDeviceName, reason}
/// → [DeviceTransferResponse]
///
/// Called when activation fails with [requiresTransferApproval] == true.
/// A 409 response means a pending request already exists — treat as success.
const String kEndpointRequestTransfer = '/licenses/request-transfer';

/// PATCH — revoke a device record (pos_api: **SuperAdmin only** today).
///
/// Desktop activation tokens cannot call this until the API allows device
/// self-revoke. See [ActivationService.revokeDeviceOnServer].
String deviceRevokeEndpoint(String deviceId) =>
    '/devices/${Uri.encodeComponent(deviceId)}/revoke';
