import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SolecoWebsiteApp());
}

class SolecoWebsiteApp extends StatelessWidget {
  const SolecoWebsiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SolecoWebWrapperScreen(),
    );
  }
}

class SolecoWebWrapperScreen extends StatefulWidget {
  const SolecoWebWrapperScreen({super.key});

  @override
  State<SolecoWebWrapperScreen> createState() => _SolecoWebWrapperScreenState();
}

class _SolecoWebWrapperScreenState extends State<SolecoWebWrapperScreen> {
  InAppWebViewController? _controller;

  bool _isLoading = true;
  bool _isOfflineOverlay = false;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _setupConnectivityMonitoring();
  }

  Future<void> _setupConnectivityMonitoring() async {
    // Kein initialer "offline" state aus connectivity_plus setzen.
    // iOS liefert hier manchmal false negatives. Wir lassen die WebView entscheiden.
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final offline = results.contains(ConnectivityResult.none);
      if (!mounted) return;

      // Wenn wieder online -> Overlay weg + reload
      if (!offline) {
        setState(() => _isOfflineOverlay = false);
        await _controller?.reload();
      }
      // Wenn offline -> NICHT sofort Overlay zeigen.
      // Das macht onReceivedError zuverlässig, wenn ein Load wirklich scheitert.
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  bool _isAllowed(Uri uri) {
    final host = uri.host.toLowerCase();
    return AppConfig.allowedHosts.any((h) => host == h || host.endsWith('.$h'));
  }

  NavigationActionPolicy _handleUrl(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    // Nur http/https erlauben
    if (scheme != "http" && scheme != "https") {
      return NavigationActionPolicy.CANCEL;
    }

    // Domain Lock: nur erlaubte Hosts in-app laden
    if (_isAllowed(uri)) {
      return NavigationActionPolicy.ALLOW;
    }

    // Externe Links: BLOCKIERT
    // (Wenn du externe Links in Safari öffnen willst, sag "Safari öffnen".)
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Android Back Button: erst WebView zurück, dann App exit
      onWillPop: () async {
        final controller = _controller;
        if (controller == null) return true;

        final canGoBack = await controller.canGoBack();
        if (canGoBack) {
          await controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(AppConfig.startUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,

                  // kein "Browser Feel"
                  supportZoom: false,
                  verticalScrollBarEnabled: true,
                  horizontalScrollBarEnabled: false,

                  // verhindert popups / neue Fenster
                  javaScriptCanOpenWindowsAutomatically: false,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },

                onLoadStart: (_, url) {
                  if (!mounted) return;
                  setState(() {
                    _isLoading = true;
                    // sobald ein Load startet, Overlay aus (wir geben der Seite eine Chance)
                    _isOfflineOverlay = false;
                  });

                  // Optional Debug:
                  // debugPrint("Load start: $url");
                },

                onLoadStop: (_, url) {
                  if (!mounted) return;
                  setState(() {
                    _isLoading = false;
                    _isOfflineOverlay = false;
                  });

                  // Optional Debug:
                  // debugPrint("Load stop: $url");
                },

                onReceivedError: (_, __, error) {
                  // Nur bei echten Ladefehlern Offline Overlay zeigen
                  if (!mounted) return;
                  setState(() {
                    _isLoading = false;
                    _isOfflineOverlay = true;
                  });

                  // Optional Debug:
                  // debugPrint("WebView error: ${error.description}");
                },

                shouldOverrideUrlLoading: (_, action) async {
                  final uri = action.request.url?.uriValue;
                  if (uri == null) return NavigationActionPolicy.CANCEL;
                  return _handleUrl(uri);
                },
              ),

              // Loading Overlay
              if (_isLoading)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),

              // Offline Overlay
              if (_isOfflineOverlay)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              "Keine Internetverbindung",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Bitte prüfe deine Verbindung und versuche es erneut.",
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                if (!mounted) return;
                                setState(() {
                                  _isOfflineOverlay = false;
                                  _isLoading = true;
                                });
                                await _controller?.reload();
                              },
                              child: const Text("Neu laden"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
