/// Localhost fallback kept for reference only — not used at runtime.
///
/// The active base URL is resolved by [RuntimeConfigService] from
/// `app_config.json` beside the executable, the `POS_API_BASE_URL` env var,
/// or this fallback, and applied via [ApiClient.configureBaseUrl] at startup.
const String kApiBaseUrl = 'http://127.0.0.1:3000';

// ── Endpoint paths (relative to [kApiBaseUrl]) ────────────────────────────

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

/// PATCH — revoke a device record (pos_api: **SuperAdmin only** today).
///
/// Desktop activation tokens cannot call this until the API allows device
/// self-revoke. See [ActivationService.revokeDeviceOnServer].
String deviceRevokeEndpoint(String deviceId) =>
    '/devices/${Uri.encodeComponent(deviceId)}/revoke';
