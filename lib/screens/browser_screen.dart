import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class BrowserScreen extends StatefulWidget {
  final String url;
  final String title;

  const BrowserScreen({super.key, required this.url, required this.title});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();

    _initController();
  }

  void _initController() {
    String finalUrl = widget.url;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            bool isCritical = false;
            String desc = error.description.toLowerCase();
            if (desc.contains("net::err_internet_disconnected") ||
                desc.contains("net::err_name_not_resolved") ||
                desc.contains("net::err_connection_refused")) {
              isCritical = true;
            }

            if (isCritical && mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = "Bağlantı Hatası: İnternetinizi kontrol edin.";
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (url.startsWith('https://') || url.startsWith('http://')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final dynamic androidController = controller.platform;
      try {
        androidController.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (String origin, bool isRetain) async {
            debugPrint("Konum izni istendi: $origin");
            return const GeolocationPermissionsResponse(
              allow: true,
              retain: false,
            );
          },
        );
      } catch (e) {
        debugPrint("Android WebView ayar hatası: $e");
      }
    }

    _controller = controller;
    _controller.loadRequest(Uri.parse(finalUrl));
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    //TEMA AYARLARI
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    _controller.setBackgroundColor(scaffoldBg);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(color: textColor, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.url,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          backgroundColor: cardColor,
          elevation: 1,
          iconTheme: IconThemeData(color: textColor),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  _controller.goBack();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("İlk sayfadasınız"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _controller.reload();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),

            // Hata Ekranı
            if (_hasError)
              Container(
                color: scaffoldBg,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 60, color: Colors.red),
                    const SizedBox(height: 20),
                    Text(
                      "Bağlantı Kurulamadı",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isLoading = true;
                        });
                        _controller.reload();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066CC),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Tekrar Dene"),
                    ),
                  ],
                ),
              ),

            // Yükleniyor
            if (_isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  color: Color(0xFF0066CC),
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
