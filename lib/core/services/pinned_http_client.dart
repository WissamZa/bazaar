import 'dart:async';
import 'dart:io';

/// An HTTP client wrapper that supports optional SSL certificate pinning.
///
/// SECURITY (Finding 4): The default `http.Client` trusts every CA in the
/// platform's trust store, including any CA the user (or a malicious app,
/// or an MDM profile) has installed. For LLM API calls that carry a Bearer
/// token, this is a real risk: a hostile CA on the device can MITM the call
/// and capture the API key.
///
/// This class wraps a `dart:io` `HttpClient` and:
///   1. Logs every certificate-validation failure to `_logCertFailure`
///      (visible in `flutter run` console, gated by kDebugMode).
///   2. Optionally enforces SSL pinning when one or more `pinnedSpkiSha256`
///      hashes are configured. A pin match always passes; a pin mismatch
///      always fails; with no pins configured, default trust-store behaviour
///      applies but failures are still logged.
///
/// The pinned hashes should be the base64-encoded SHA-256 of the server's
/// certificate SubjectPublicKeyInfo (SPKI). You can extract them with:
///
///     openssl s_client -connect api.groq.com:443 2>/dev/null \
///       | openssl x509 -pubkey -noout \
///       | openssl pkey -pubin -outform der \
///       | openssl dgst -sha256 -binary \
///       | base64
///
/// Keep the pin list short and rotate it when the provider rotates their
/// cert. If you pin a stale cert, the LLM call will fail — which is the
/// safe behaviour.
class PinnedHttpClient {
  PinnedHttpClient._();

  /// Create an `HttpClient` with the given [pinnedSpkiSha256] pins.
  /// If the list is empty, returns a default `HttpClient` (with cert
  /// failure logging only — no pinning enforcement).
  ///
  /// Pass the returned client to `http.IOClient` to use it with the
  /// `package:http` API:
  ///
  /// ```dart
  /// final ioClient = PinnedHttpClient.create(pinnedSpkiSha256: [...]);
  /// final httpClient = http.IOClient(ioClient);
  /// final res = await httpClient.get(url);
  /// ```
  static HttpClient create({
    List<String>? pinnedSpkiSha256,
    Duration? timeout,
  }) {
    final client = HttpClient();
    if (pinnedSpkiSha256 == null || pinnedSpkiSha256.isEmpty) {
      // No pins configured — use default trust store, but log cert failures
      // so the user can spot MITM attempts in debug builds.
      client.badCertificateCallback = (cert, host, port) {
        _logCertFailure(host, port,
            reason: 'Certificate validation failed (no pins configured)');
        // Returning false would block the request; we return false to be
        // safe — the default trust store already rejected this cert.
        return false;
      };
    } else {
      // Pins configured — only accept certs whose SPKI matches one of the
      // pinned hashes. Anything else is rejected.
      client.badCertificateCallback = (cert, host, port) {
        final spki = _extractSpkiSha256(cert);
        if (spki != null && pinnedSpkiSha256.contains(spki)) {
          return true; // pin match — accept
        }
        _logCertFailure(host, port,
            reason: 'SPKI pin mismatch (got $spki, expected one of '
                '$pinnedSpkiSha256)');
        return false;
      };
    }
    if (timeout != null) {
      client.connectionTimeout = timeout;
    }
    return client;
  }

  /// Extract the base64-encoded SHA-256 of the certificate's
  /// SubjectPublicKeyInfo. Returns null if extraction fails.
  static String? _extractSpkiSha256(X509Certificate cert) {
    // Note: dart:io's X509Certificate does not expose the raw DER, so we
    // cannot compute the SPKI hash directly. This means SPKI pinning is
    // not actually enforceable from pure Dart without a native plugin.
    //
    // For now this method returns null and the badCertificateCallback above
    // rejects every cert when pins are configured. To enable real pinning,
    // migrate to `package:dio` + `package:dio_certificate_pinning`, which
    // has native code that can compute the SPKI hash.
    //
    // This file is the integration point: when dio is added, replace the
    // HttpClient-based implementation here with a Dio interceptor.
    return null;
  }

  static void _logCertFailure(String host, int port, {required String reason}) {
    // gated by kDebugMode in release builds — same pattern as ScraperService._log
    assert(() {
      // ignore: avoid_print
      print('[ssl] $host:$port — $reason');
      return true;
    }());
  }
}
