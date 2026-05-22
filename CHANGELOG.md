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
