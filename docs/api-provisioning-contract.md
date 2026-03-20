# API Provisioning Sender — Flutter Client Contract

**Service:** API Provisioning Sender Worker
**Base URL:** `https://api-provisioning-sender.example.com`
**Version:** 1.0
**Last Updated:** 2026-03-20

---

## Overview

The Sender Worker provides three core operations for Flutter clients:
1. **User Signup** — create a new account with email/password
2. **User Signin** — authenticate with email/password, receive JWT
3. **API Key Provisioning** — use JWT to request an API key for accessing observability APIs

All requests must include `Content-Type: application/json` header. Responses are JSON with error details on failure.

---

## CORS & Preflight

**Preflight requests:** OPTIONS requests to any endpoint return 200 with CORS headers.

```
OPTIONS /signup
200 OK

Headers:
  access-control-allow-methods: POST, OPTIONS
  access-control-allow-headers: Content-Type
  access-control-allow-origin: {CORS_ORIGIN from env}
  access-control-max-age: 86400
```

**Client-side:** Most HTTP clients (including Flutter's `http` package) automatically handle preflight.

---

## Endpoints

### 1. Health Check

**Endpoint:** `GET /health`

**Description:** Service liveness check.

**Request:**
```
GET /health HTTP/1.1
Host: api-provisioning-sender.example.com
Content-Type: application/json
```

**Response (200 OK):**
```json
{
  "ok": true,
  "service": "api-provisioning-sender",
  "version": "1.0.0",
  "timestamp": "2026-03-20T10:15:30.000Z"
}
```

**Use case:** Pre-request health check or periodic monitoring from Flutter app.

---

### 2. Signup

**Endpoint:** `POST /signup`

**Description:** Create a new user account. Returns JWT token for authenticated requests.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Headers:**
```
Content-Type: application/json
```

**Email Format Validation:**
- Must match pattern: `^[^\s@]+@[^\s@]+\.[^\s@]+$`
- No spaces, valid domain
- Invalid format returns 400 MISSING_FIELDS

**Password Requirements:**
- Enforced by Supabase (typically 6+ chars, but implementation may vary)
- Weak passwords return error from Supabase

**Response (201 Created):**
```json
{
  "jwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com"
}
```

**Error Responses:**

| Status | Code | Reason |
|--------|------|--------|
| 400 | MISSING_FIELDS | email or password missing, or invalid email format |
| 400 | JSON_PARSE_ERROR | request body is not valid JSON |
| 500 | INTERNAL_ERROR | signup failed (Supabase auth error) |

**Flutter Example:**
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> signup(String email, String password) async {
  final response = await http.post(
    Uri.parse('https://api-provisioning-sender.example.com/signup'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode == 201) {
    return json.decode(response.body) as Map<String, dynamic>;
  } else {
    final error = json.decode(response.body);
    throw Exception('Signup failed: ${error['error']} (${error['code']})');
  }
}
```

---

### 3. Signin

**Endpoint:** `POST /signin`

**Description:** Authenticate with email/password. Returns a fresh JWT token.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Headers:**
```
Content-Type: application/json
```

**Email & Password Validation:**
- Same as signup (email format validated client-side)
- Invalid credentials return 500 INTERNAL_ERROR (Supabase will reject)

**Response (200 OK):**
```json
{
  "jwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com"
}
```

**Error Responses:**

| Status | Code | Reason |
|--------|------|--------|
| 400 | MISSING_FIELDS | email or password missing, or invalid email format |
| 400 | JSON_PARSE_ERROR | request body is not valid JSON |
| 500 | INTERNAL_ERROR | signin failed (invalid credentials or Supabase error) |

**Flutter Example:**
```dart
Future<Map<String, dynamic>> signin(String email, String password) async {
  final response = await http.post(
    Uri.parse('https://api-provisioning-sender.example.com/signin'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode == 200) {
    return json.decode(response.body) as Map<String, dynamic>;
  } else {
    final error = json.decode(response.body);
    throw Exception('Signin failed: ${error['error']} (${error['code']})');
  }
}
```

---

### 4. Send (Provision API Key)

**Endpoint:** `POST /send`

**Description:** Forward a provisioning request to the Receiver Worker. Currently supports `provision_api_key` action to request an API key token.

**Request:**
```json
{
  "action": "provision_api_key",
  "jwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "name": "flutter-mobile-app",
  "tier": "new",
  "sentAt": "2026-03-20T10:15:30.000Z"
}
```

**Headers:**
```
Content-Type: application/json
```

**Fields:**
- **action** (string, required): Action type. Currently only `"provision_api_key"` is supported.
- **jwt** (string, required): User's JWT token from signup/signin.
- **name** (string, required): Friendly name for the API key (e.g., "flutter-mobile-app").
- **tier** (string, required): API tier: `"new"` or `"pro"`. Determines rate limits and features.
- **sentAt** (string, optional): ISO 8601 timestamp when request was sent. For audit/replay-protection.

**JWT Validation:**
- JWT must be valid and not expired
- JWT is validated by the Receiver before forwarding to edge function
- Invalid/expired JWT returns 500 PROVISION_ERROR

**Response (200 OK):**
```json
{
  "ok": true,
  "token": "obtk_abc123def456...",
  "keyId": "550e8400-e29b-41d4-a716-446655440000",
  "prefix": "obtk_abc",
  "tier": "new"
}
```

**Token Format:**
- **token**: Full API key token (store securely in Flutter app, e.g., Flutter Secure Storage)
- **keyId**: Unique ID of the key (for rotation/revocation later)
- **prefix**: First 8 characters (safe to log for debugging)
- **tier**: Echoed back; matches request

**Error Responses:**

| Status | Code | Reason |
|--------|------|--------|
| 400 | MISSING_FIELDS | action, jwt, name, or tier missing |
| 400 | UNKNOWN_ACTION | action is not recognized (only `provision_api_key` supported) |
| 400 | JSON_PARSE_ERROR | request body is not valid JSON |
| 500 | PROVISION_ERROR | Edge function failed (JWT invalid, tier unknown, etc.) |
| 500 | RECEIVER_ERROR | Receiver Worker returned non-200 status |
| 500 | INTERNAL_ERROR | Unexpected error in Sender Worker |

**Flutter Example:**
```dart
Future<Map<String, dynamic>> provisionApiKey(
  String jwt,
  {String name = "flutter-app", String tier = "new"}
) async {
  final response = await http.post(
    Uri.parse('https://api-provisioning-sender.example.com/send'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'action': 'provision_api_key',
      'jwt': jwt,
      'name': name,
      'tier': tier,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  if (response.statusCode == 200) {
    return json.decode(response.body) as Map<String, dynamic>;
  } else {
    final error = json.decode(response.body);
    throw Exception('Provision failed: ${error['error']} (${error['code']})');
  }
}
```

---

## Error Response Format

All error responses follow this schema:

```json
{
  "error": "human-readable error message",
  "code": "ERROR_CODE_CONSTANT"
}
```

**Example:**
```json
{
  "error": "invalid email format",
  "code": "MISSING_FIELDS"
}
```

**Error Codes (complete list):**
- `MISSING_FIELDS` — required field is missing or invalid
- `JSON_PARSE_ERROR` — request body is not valid JSON
- `UNKNOWN_ACTION` — action field is not recognized
- `RECEIVER_ERROR` — Receiver Worker returned error
- `INTERNAL_ERROR` — unexpected server error
- `NOT_FOUND` — endpoint does not exist

---

## Security Considerations

### 1. HTTPS Only
All requests MUST use HTTPS. The Sender Worker will be served over TLS.

### 2. JWT Storage
- **DO:** Store JWT in secure storage (Flutter Secure Storage, Keychain/Keystore)
- **DON'T:** Store JWT in SharedPreferences, local files, or logs
- **Expiry:** JWT tokens expire. Implement refresh logic with Supabase (not implemented here yet)

### 3. API Key Token Storage
- **DO:** Store API key token in Flutter Secure Storage
- **DON'T:** Log or transmit over unencrypted channels
- **Rotation:** API keys can be rotated via separate endpoint (future work)

### 4. Email Validation
- Client-side validation is recommended for UX
- Server-side validation enforces format: `^[^\s@]+@[^\s@]+\.[^\s@]+$`

### 5. CORS
- Origin header is set by the Sender Worker from environment configuration
- Wildcard CORS (`*`) is NOT used; only specific origins allowed
- See [CORS & Preflight](#cors--preflight) section above

---

## Flutter Integration Guide

### 1. Add HTTP dependency

**pubspec.yaml:**
```yaml
dependencies:
  http: ^1.1.0
  flutter_secure_storage: ^9.0.0
```

### 2. Create a client class

```dart
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class ProvisioningClient {
  static const String baseUrl = 'https://api-provisioning-sender.example.com';
  static const String _jwtKey = 'provisioning_jwt';
  static const String _tokenKey = 'api_key_token';

  final _storage = const FlutterSecureStorage();

  Future<void> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode != 201) {
      final error = json.decode(response.body);
      throw Exception('${error['error']} (${error['code']})');
    }

    final result = json.decode(response.body) as Map<String, dynamic>;
    await _storage.write(key: _jwtKey, value: result['jwt']);
  }

  Future<void> signin(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signin'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception('${error['error']} (${error['code']})');
    }

    final result = json.decode(response.body) as Map<String, dynamic>;
    await _storage.write(key: _jwtKey, value: result['jwt']);
  }

  Future<String> getApiKey({String name = "flutter-app"}) async {
    final jwt = await _storage.read(key: _jwtKey);
    if (jwt == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'provision_api_key',
        'jwt': jwt,
        'name': name,
        'tier': 'new',
        'sentAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception('${error['error']} (${error['code']})');
    }

    final result = json.decode(response.body) as Map<String, dynamic>;
    final token = result['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    return token;
  }

  Future<String?> getStoredApiKey() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> logout() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _tokenKey);
  }
}
```

### 3. Usage in Widget

```dart
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _client = ProvisioningClient();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignin() async {
    setState(() => _isLoading = true);
    try {
      await _client.signin(
        _emailController.text,
        _passwordController.text,
      );
      // Provision API key
      final apiKey = await _client.getApiKey(name: 'flutter-mobile');
      print('API Key provisioned: ${apiKey.substring(0, 8)}...');
      // Navigate to home
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(label: Text('Email')),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(label: Text('Password')),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignin,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

---

## Status Codes Reference

| Status | Meaning |
|--------|---------|
| 200 | OK — request succeeded |
| 201 | Created — resource created successfully |
| 400 | Bad Request — validation error (missing fields, invalid JSON, unknown action) |
| 500 | Internal Server Error — server-side error (Supabase error, Receiver error, provision error) |
| 404 | Not Found — endpoint does not exist |
| 405 | Method Not Allowed — wrong HTTP method (e.g., GET instead of POST) |

---

## Common Workflows

### Workflow 1: First-Time User (Signup + Provision)

```
1. POST /signup (email, password)
   → returns jwt, userId, email
   → store jwt securely

2. POST /send (action: provision_api_key, jwt, name, tier)
   → returns token, keyId, prefix
   → store token in Flutter Secure Storage

3. User can now make authenticated requests to API using token
```

### Workflow 2: Returning User (Signin + Provision)

```
1. POST /signin (email, password)
   → returns jwt, userId, email
   → store jwt securely (refresh)

2. POST /send (action: provision_api_key, jwt, name, tier)
   → returns token, keyId, prefix
   → store token in Flutter Secure Storage (refresh)

3. User can now make authenticated requests to API
```

### Workflow 3: Use Stored Token

```
1. Retrieve jwt from secure storage
2. Retrieve api_token from secure storage
3. Make authenticated requests to API using Bearer {api_token}
4. On token expiry (401), re-run Workflow 2 to refresh
```

---

## Rate Limiting & Throttling

Currently no rate limiting is enforced by the Sender Worker. Future versions may add:
- Per-IP request throttling
- Per-user provisioning quotas (e.g., max 5 keys per user)

Implement client-side backoff for transient errors (5xx responses).

---

## Testing & Debugging

### Health Check
```bash
curl https://api-provisioning-sender.example.com/health
```

### Signup Test
```bash
curl -X POST https://api-provisioning-sender.example.com/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test+'"$(date +%s)"'@example.com","password":"TestPass123"}'
```

### Signin Test
```bash
curl -X POST https://api-provisioning-sender.example.com/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"TestPass123"}'
```

### Provision Test
```bash
curl -X POST https://api-provisioning-sender.example.com/send \
  -H "Content-Type: application/json" \
  -d '{"action":"provision_api_key","jwt":"YOUR_JWT_HERE","name":"test","tier":"new"}'
```

---

## Support & Issues

For API contract issues or questions:
- Check error code and message for debugging
- Verify request format matches examples above
- Ensure JWT and tokens are stored/passed correctly
- Check CORS preflight succeeds before failing on POST

See [api-provisioning.md](api-provisioning.md) for architecture details and implementation status.
