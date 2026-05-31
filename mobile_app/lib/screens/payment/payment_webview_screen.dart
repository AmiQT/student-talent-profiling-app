import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/app_theme.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String title;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.title,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Navigating to: ${request.url}');
            if (_checkPaymentStatus(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _checkPaymentStatus(String url) {
    debugPrint('🔍 Checking payment URL: $url');

    // Check for ToyyibPay return/callback URL patterns
    if (url.contains('status_id') ||
        url.contains('billcode') ||
        url.contains('toyyibpay.com') && url.contains('transaction') ||
        url.contains('billReturnUrl') ||
        url.contains('billCallbackUrl')) {
      final uri = Uri.parse(url);
      final statusId = uri.queryParameters['status_id'];
      final paymentStatus = uri.queryParameters['billpaymentStatus'] ??
          uri.queryParameters['bill_payment_status'];

      debugPrint('🔍 statusId: $statusId, paymentStatus: $paymentStatus');

      // ToyyibPay status: 1 = Success, 2 = Pending, 3 = Failed
      if (statusId == '1' || paymentStatus == '1') {
        debugPrint('✅ Payment SUCCESS - Redirecting...');
        Navigator.pop(context, true); // Success
        return true;
      } else if (statusId == '3' || paymentStatus == '3') {
        debugPrint('❌ Payment FAILED - Redirecting...');
        Navigator.pop(context, false); // Failed
        return true;
      } else if (statusId == '2' || paymentStatus == '2') {
        debugPrint('⏳ Payment PENDING');
        // Don't close, let user see pending status
        return false;
      }
    }

    // Also check if URL contains success/failed keywords
    if (url.contains('/payment/success') || url.contains('success=true')) {
      debugPrint('✅ Payment SUCCESS via URL pattern');
      Navigator.pop(context, true);
      return true;
    }
    if (url.contains('/payment/failed') || url.contains('success=false')) {
      debugPrint('❌ Payment FAILED via URL pattern');
      Navigator.pop(context, false);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.pop(context, false), // Treat close as cancel
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}
