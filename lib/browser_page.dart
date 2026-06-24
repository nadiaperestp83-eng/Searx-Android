import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrowserPage extends StatefulWidget {
  final String url;
  const BrowserPage({Key? key, required this.url}) : super(key: key);

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late MethodChannel _channel;
  int? _viewId;

  String _currentUrl = '';
  String _pageTitle = '';
  int _progress = 0;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    _channel = MethodChannel('searxgo/browser_$id');
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPageStarted':
        setState(() {
          _isLoading = true;
          _currentUrl = call.arguments as String;
        });
        break;
      case 'onPageFinished':
        setState(() {
          _isLoading = false;
          _currentUrl = call.arguments as String;
        });
        _refreshNavState();
        break;
      case 'onProgress':
        setState(() => _progress = call.arguments as int);
        break;
      case 'onError':
        setState(() => _isLoading = false);
        break;
    }
  }

  Future<void> _refreshNavState() async {
    // não há canGoBack direto via channel nesse fluxo; 
    // usamos loadUrl para rastrear
  }

  Future<void> _goBack() async {
    await _channel.invokeMethod('goBack');
  }

  Future<void> _goForward() async {
    await _channel.invokeMethod('goForward');
  }

  Future<void> _reload() async {
    await _channel.invokeMethod('reload');
  }

  Future<void> _clearAndClose() async {
    await _channel.invokeMethod('clearData');
    if (mounted) Navigator.pop(context);
  }

  String _displayUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);
      return host;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF5f6368)),
          onPressed: _clearAndClose,
          tooltip: 'Fechar e limpar dados',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, size: 13, color: Color(0xFF188038)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _displayUrl(_currentUrl),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF202124),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF5f6368)),
            onPressed: _reload,
            tooltip: 'Recarregar',
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress > 0 && _progress < 100
                      ? _progress / 100
                      : null,
                  color: const Color(0xFF4285F4),
                  backgroundColor: const Color(0xFFe8eaed),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: AndroidView(
              viewType: 'searxgo/private_browser',
              creationParams: {'url': widget.url},
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
            ),
          ),

          // Barra de navegação inferior
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFe8eaed), width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 20, color: Color(0xFF5f6368)),
                    onPressed: _goBack,
                    tooltip: 'Voltar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        size: 20, color: Color(0xFF5f6368)),
                    onPressed: _goForward,
                    tooltip: 'Avançar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.shield,
                        size: 20, color: Color(0xFF188038)),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => _buildPrivacySheet(),
                      );
                    },
                    tooltip: 'Privacidade',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Color(0xFF5f6368)),
                    onPressed: _clearAndClose,
                    tooltip: 'Limpar e fechar',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySheet() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield, color: Color(0xFF188038), size: 22),
              SizedBox(width: 8),
              Text(
                'Proteção ativa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1a1a1a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _privacyItem(Icons.block, 'Trackers bloqueados', 'Google, Facebook, Meta, Criteo e mais'),
          _privacyItem(Icons.cookie, 'Banners de cookie', 'Removidos automaticamente'),
          _privacyItem(Icons.location_off, 'Geolocalização', 'Desativada'),
          _privacyItem(Icons.fingerprint, 'Fingerprinting', 'User-Agent neutro'),
          _privacyItem(Icons.storage, 'Dados locais', 'Limpos ao fechar'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _privacyItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4285F4)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1a1a1a))),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}
