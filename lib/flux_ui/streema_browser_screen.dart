import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../flux_engine/playback_controller.dart';

class StreemaBrowserScreen extends StatefulWidget {
  final String url;

  const StreemaBrowserScreen({super.key, required this.url});

  @override
  State<StreemaBrowserScreen> createState() => _StreemaBrowserScreenState();
}

class _StreemaBrowserScreenState extends State<StreemaBrowserScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..addJavaScriptChannel(
        'FluxPlayer',
        onMessageReceived: (JavaScriptMessage message) {
          final parts = message.message.split('|');
          if (parts.length >= 2) {
            final url = parts[0];
            final name = parts[1];
            context.read<PlaybackController>().playStream(url, name);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playing $name from Streema'),
                backgroundColor: Theme.of(context).primaryColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectInterceptor();
            _cleanUI();
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _cleanUI() {
    _controller.runJavaScript("""
      (function() {
        var style = document.createElement('style');
        style.innerHTML = `
          header, footer, nav, .navbar, .site-footer, .app-banner, .social-links, .ads, .sidebar, #branding, .streema-branding, .download-app-link, .nav-tabs, .breadcrumb, .page-header, .ad-container, .promo-banner, .login-prompt, .signup-prompt, div[class*="branding"], div[class*="footer"], div[class*="header"], div[class*="ad-"] { display: none !important; }
          body { padding-top: 0 !important; margin-top: 0 !important; }
          .main-container, .container { padding-top: 10px !important; margin-top: 0 !important; width: 100% !important; max-width: 100% !important; }
          .item, .station-item { border-bottom: 1px solid rgba(255,255,255,0.15) !important; padding: 12px !important; border-radius: 8px !important; }
        `;
        document.head.appendChild(style);
      })();
    """);
  }

  void _injectInterceptor() {
    _controller.runJavaScript("""
      (function() {
        // More robust station name extraction
        function getStationName() {
          var h1 = document.querySelector('h1');
          if (h1) return h1.innerText.trim();
          
          var breadcrumb = document.querySelector('.breadcrumb .active');
          if (breadcrumb) return breadcrumb.innerText.trim();

          var metaTitle = document.querySelector('meta[property="og:title"]');
          if (metaTitle) return metaTitle.getAttribute('content').split('|')[0].trim();
          
          return document.title.split('|')[0].trim();
        }

        // Intercept play button clicks with improved detection
        document.addEventListener('click', function(e) {
           var btn = e.target.closest('button, a, .play-button, [class*="play"], [id*="play"]');
           if (btn) {
              // Longer wait for some slower stream resolutions
              var attempts = 0;
              var checkAudio = setInterval(function() {
                var audio = document.querySelector('audio');
                if (audio && audio.src && !audio.paused) {
                   clearInterval(checkAudio);
                   var name = getStationName();
                   FluxPlayer.postMessage(audio.src + '|' + name);
                   audio.pause(); 
                }
                if (++attempts > 10) clearInterval(checkAudio);
              }, 500);
           }
        }, true);

        // Periodically check for playing audio as a fallback
        setInterval(function() {
          var audios = document.getElementsByTagName('audio');
          for (var i = 0; i < audios.length; i++) {
            if (audios[i].src && !audios[i].paused && audios[i].src.indexOf('blob:') !== 0) {
               var name = getStationName();
               FluxPlayer.postMessage(audios[i].src + '|' + name);
               audios[i].pause(); 
            }
          }
        }, 1000);

        // Handle direct source updates in existing audio elements
        var observer = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            if (mutation.type === 'attributes' && mutation.attributeName === 'src') {
              var audio = mutation.target;
              if (audio.tagName === 'AUDIO' && audio.src && !audio.paused) {
                var name = getStationName();
                FluxPlayer.postMessage(audio.src + '|' + name);
                audio.pause();
              }
            }
          });
        });

        document.querySelectorAll('audio').forEach(function(audio) {
          observer.observe(audio, { attributes: true });
        });
      })();
    """);
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
    final encodedQuery = Uri.encodeComponent(query);
    final searchUrl = 'https://streema.com/radios/search/?q=$encodedQuery';
    _controller.loadRequest(Uri.parse(searchUrl));
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching 
          ? Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search Streema...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
                onSubmitted: _performSearch,
              ),
            )
          : const Text('Streema Global'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: _isSearching ? theme.colorScheme.error : theme.colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller.reload(),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          if (_isLoading)
            Container(
              color: theme.scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: theme.primaryColor,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading Directory...',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }
}
