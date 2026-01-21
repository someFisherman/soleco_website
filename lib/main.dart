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

  StreamSubscription<ConnectivityResult>? _connSub;

  @override
  void initState() {
    super.initState();

    // Initialer Online/Offline Check
    Connectivity().checkConnectivity().then((r) {
      if (!mounted) return;
      setState(() => _isOfflineOverlay = (r == ConnectivityResult.none));
    });

    // Live Monitoring
    _connSub = Connectivity().onConnectivityChanged.listen((r) async {
      final offline = (r == ConnectivityResult.none);
      if (!mounted) return;

      setState(() => _isOfflineOverlay = offline);

      // wenn wieder online: reload
      if (!offline) {
        await _controller?.reload();
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  bool _isAllowed(Uri uri) {
    final host = uri.host.toLowerCase();
    return AppConfig.allowedHosts.contains(host);
  }

  NavigationActionPolicy _handleUrl(Uri uri) {
    // Nur http/https erlauben
    final scheme = uri.scheme.toLowerCase();
    if (scheme != "http" && scheme != "https") {
      return NavigationActionPolicy.CANCEL;
    }

    // Domain Lock
    if (_isAllowed(uri)) {
      return NavigationActionPolicy.ALLOW;
    }

    // Externe Links: BLOCKIERT (maximale Sperre)
    // Wenn du statt blockieren -> Safari öffnen willst, sag "Safari öffnen".
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Android Back Button: erst WebView zurück, dann App exit
      onWillPop: () async {
        if (_controller == null) return true;
        final canGoBack = await _controller!.canGoBack();
        if (canGoBack) {
          await _controller!.goBack();
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
                initialUrlRequest: URLRequest(
                  url: WebUri(AppConfig.startUrl),
                ),
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
                onLoadStart: (_, __) {
                  setState(() => _isLoading = true);
                },
                onLoadStop: (_, __) {
                  setState(() => _isLoading = false);
                },
                onReceivedError: (_, __, ___) {
                  setState(() => _isOfflineOverlay = true);
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
                                setState(() => _isOfflineOverlay = false);
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
