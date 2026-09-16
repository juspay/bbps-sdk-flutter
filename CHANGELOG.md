## 0.0.4

### Breaking Changes
- Event stream and method-call responses now emit decoded maps directly instead of JSON strings or `{event, payload}` envelopes
- `BbpsEvent` no longer wraps responses, new fields `requestId`, `service`, `errorCode`, and `errorMessage` added, and `error` is now a `String?`

### Native Changes
- **Android**: Added `toStandardTypes()` to convert `JSONObject`/`JSONArray` payloads into standard Dart types (maps/lists), removed `set_txn_status` helper and simplified `process_result` to read the `event` from the inner payload
- **iOS**: Event sink now forwards the native response dictionary as-is instead of re-wrapping it in an `{event, payload}` envelope

## 0.0.3

- Lowered minimum Dart SDK requirement from `^3.11.5` to `^3.9.0`
- Raised minimum Flutter SDK requirement from `>=3.3.0` to `>=3.35.0` to align with Dart 3.9.0
- Lowered `flutter_lints` from `^6.0.0` to `^5.0.0` for wider compatibility

## 0.0.2

### Breaking Changes
- Unified API signatures: `createService`, `initiate`, `process` now accept a single optional `params` map instead of individual named parameters
- `process()` no longer takes `action` as a positional argument; include it in `params` instead
- `initiate()` no longer injects `action` and `clientId` on the native side; these must now be included in the Dart `params` map

### Native Changes
- **Android**: Updated BBPS SDK from `0.1.9` to `0.1.10`; fixed `do_payment` override modifier
- **iOS**: Aligned `initiate` and `process` to accept direct params map consistently (removed legacy `{params: {...}}` support)
- Both platforms: `initiate` now forwards params dynamically without injecting any defaults

### Fixes
- Aligned Dart and iOS method channel signatures for `initiate` and `process`
- Updated tests to reflect new API signatures

## 0.0.1

* First Release of bbps_sdk_flutter
