import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF000000),
    systemNavigationBarColor: Color(0xFF000000),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const AplikasiYamada());
}

class AplikasiYamada extends StatelessWidget {
  const AplikasiYamada({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YamadaVerse',
      theme: ThemeData.dark(),
      home: const HalamanWeb(),
    );
  }
}

class HalamanWeb extends StatefulWidget {
  const HalamanWeb({super.key});

  @override
  State<HalamanWeb> createState() => _StatusHalamanWeb();
}

class _StatusHalamanWeb extends State<HalamanWeb> {
  static const String _urlBeranda = 'https://www.yamadaverse.xyz';
  static const String _pemilikRepo = String.fromEnvironment('REPO_PEMILIK', defaultValue: '');
  static const String _namaRepo = String.fromEnvironment('REPO_NAMA', defaultValue: '');

  late final WebViewController _pengendaliWeb;
  bool _sedangCekRilis = false;
  bool _infoLoginGoogleDitampilkan = false;

  @override
  void initState() {
    super.initState();

    final pengendali = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (permintaanNavigasi) async {
            final tautan = permintaanNavigasi.url;
            if (_harusBlokirLoginGoogle(tautan)) {
              _tampilkanInfoLoginManual();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_urlBeranda));

    if (pengendali.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      final pengendaliAndroid = pengendali.platform as AndroidWebViewController;
      pengendaliAndroid.setMediaPlaybackRequiresUserGesture(false);
      pengendaliAndroid.setVerticalScrollBarEnabled(false);
      pengendaliAndroid.setHorizontalScrollBarEnabled(false);
      pengendaliAndroid.setOverScrollMode(WebViewOverScrollMode.never);
      pengendaliAndroid.setTextZoom(100);
      pengendaliAndroid.setUseWideViewPort(true);
    }

    _pengendaliWeb = pengendali;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cekRilisTerbaru();
    });
  }

  Future<void> _cekRilisTerbaru() async {
    if (_sedangCekRilis) return;
    if (_pemilikRepo.isEmpty || _namaRepo.isEmpty) return;
    _sedangCekRilis = true;

    try {
      final infoAplikasi = await PackageInfo.fromPlatform();
      final versiSaatIni = infoAplikasi.version.trim();
      final uriRilis = Uri.parse(
        'https://api.github.com/repos/$_pemilikRepo/$_namaRepo/releases/latest',
      );

      final klienHttp = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final permintaanHttp = await klienHttp.getUrl(uriRilis);
      permintaanHttp.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final responsHttp = await permintaanHttp.close();
      if (responsHttp.statusCode < 200 || responsHttp.statusCode >= 300) {
        klienHttp.close(force: true);
        return;
      }

      final isiRespons = await responsHttp.transform(utf8.decoder).join();
      klienHttp.close(force: true);
      final dataJson = jsonDecode(isiRespons);

      final tagRilis = (dataJson['tag_name'] ?? '').toString();
      final versiRilis = _normalisasiVersi(tagRilis);
      if (versiRilis.isEmpty) return;

      if (_bandingkanVersi(versiRilis, versiSaatIni) <= 0) return;
      if (!mounted) return;

      final urlRilis = (dataJson['html_url'] ?? '').toString();
      final namaRilis = (dataJson['name'] ?? tagRilis).toString();
      await _tampilkanDialogPembaruan(
        versiSaatIni: versiSaatIni,
        versiRilis: versiRilis,
        namaRilis: namaRilis,
        urlRilis: urlRilis,
      );
    } catch (_) {
      return;
    } finally {
      _sedangCekRilis = false;
    }
  }

  String _normalisasiVersi(String nilai) {
    var hasil = nilai.trim();
    if (hasil.startsWith('v') || hasil.startsWith('V')) {
      hasil = hasil.substring(1);
    }
    final bagian = hasil.split('+').first.trim();
    return bagian;
  }

  int _bandingkanVersi(String kiri, String kanan) {
    final daftarKiri = kiri.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final daftarKanan = kanan.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final panjang = daftarKiri.length > daftarKanan.length ? daftarKiri.length : daftarKanan.length;
    for (var i = 0; i < panjang; i++) {
      final angkaKiri = i < daftarKiri.length ? daftarKiri[i] : 0;
      final angkaKanan = i < daftarKanan.length ? daftarKanan[i] : 0;
      if (angkaKiri > angkaKanan) return 1;
      if (angkaKiri < angkaKanan) return -1;
    }
    return 0;
  }

  Future<void> _tampilkanDialogPembaruan({
    required String versiSaatIni,
    required String versiRilis,
    required String namaRilis,
    required String urlRilis,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (konteksDialog) {
        return AlertDialog(
          title: const Text('Update Tersedia'),
          content: Text(
            'Versi baru tersedia.\n\nVersi sekarang: $versiSaatIni\nVersi terbaru: $versiRilis\nRilis: $namaRilis',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(konteksDialog).pop();
              },
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(konteksDialog);
                if (urlRilis.isNotEmpty) {
                  await launchUrl(
                    Uri.parse(urlRilis),
                    mode: LaunchMode.externalApplication,
                  );
                }
                if (navigator.mounted) navigator.pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _tanganiKembali() async {
    if (await _pengendaliWeb.canGoBack()) {
      await _pengendaliWeb.goBack();
      return false;
    }
    return true;
  }

  bool _harusBlokirLoginGoogle(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host.contains('accounts.google.com')) return true;
    if (host.contains('supabase.co') &&
        uri.path.toLowerCase().contains('/auth/v1/authorize') &&
        (uri.queryParameters['provider'] ?? '').toLowerCase() == 'google') {
      return true;
    }
    return false;
  }

  void _tampilkanInfoLoginManual() {
    if (!mounted) return;
    if (_infoLoginGoogleDitampilkan) return;
    _infoLoginGoogleDitampilkan = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Login Google dinonaktifkan di aplikasi. Silakan gunakan login manual (email/password).',
        ),
        duration: Duration(seconds: 4),
      ),
    );

    Future<void>.delayed(const Duration(seconds: 5), () {
      if (mounted) _infoLoginGoogleDitampilkan = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parameterWidgetDasar = PlatformWebViewWidgetCreationParams(
      controller: _pengendaliWeb.platform,
    );
    final parameterWidgetAndroid =
        AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
      parameterWidgetDasar,
      displayWithHybridComposition: false,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final bolehKeluar = await _tanganiKembali();
        if (bolehKeluar) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: WebViewWidget.fromPlatformCreationParams(
            params: parameterWidgetAndroid,
          ),
        ),
      ),
    );
  }
}
