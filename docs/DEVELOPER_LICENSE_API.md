# Developer license API

This document defines the external API contract used by the Flutter client.
The API may store data in PostgreSQL, Firebase, or another server-side
database. The Flutter app must never receive database credentials.

## Authentication

`POST /developer/auth/login`

```json
{
  "email": "developer@example.com",
  "password": "********"
}
```

Successful response:

```json
{
  "accessToken": "jwt-or-opaque-token",
  "developerName": "Support Developer"
}
```

Use a short-lived access token, HTTPS, rate limiting, password hashing, and a
developer role check. Return `401` for invalid credentials and `403` for a
valid user without the developer permission.

## Extend an owner's license

`POST /developer/licenses/extend`

```http
Authorization: Bearer <developer-access-token>
Content-Type: application/json
```

```json
{
  "licenseKey": "POS-XXXX-XXXX-XXXX",
  "days": 30
}
```

Successful response:

```json
{
  "licenseKey": "POS-XXXX-XXXX-XXXX",
  "licenseExpiresAt": "2026-10-10T00:00:00.000Z"
}
```

The server owns the expiry calculation and should extend from the later of
`now` and the current expiry. Validate `days` between `1` and `3650`, write an
audit record containing the developer, license, previous expiry, new expiry,
and timestamp, and return `404` when the license does not exist.

## Client configuration

Set the API URL in `app_config.json` next to the desktop executable or through
`POS_API_BASE_URL`. Do not put PostgreSQL connection strings, Firebase service
account JSON, or developer credentials in this repository or in the Flutter
binary.
