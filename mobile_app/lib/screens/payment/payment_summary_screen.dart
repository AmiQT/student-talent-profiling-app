import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../models/profile_model.dart';
import '../../services/toyyibpay_service.dart';
import '../../services/profile_service.dart';
import '../../config/supabase_config.dart';
import '../../utils/app_theme.dart';
import 'payment_webview_screen.dart';

class PaymentSummaryScreen extends StatefulWidget {
  final EventModel event;

  const PaymentSummaryScreen({
    super.key,
    required this.event,
  });

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  final ToyyibPayService _paymentService = ToyyibPayService();
  final ProfileService _profileService = ProfileService();

  bool _isLoading = false;
  ProfileModel? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId != null) {
      final profile = await _profileService.getProfileByUserId(userId);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    }
  }

  Future<void> _proceedToPayment() async {
    debugPrint('========================================');
    debugPrint('🔵 PAY BUTTON CLICKED');
    debugPrint('🔵 _userProfile: ${_userProfile?.fullName ?? "NULL"}');
    debugPrint(
        '🔵 Platform: ${kIsWeb ? "Web (via backend proxy)" : "Mobile (direct)"}');
    debugPrint('========================================');

    if (_userProfile == null) {
      debugPrint('❌ _userProfile is null! Cannot proceed.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile not loaded. Please try again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Create Bill
      debugPrint('📞 Calling ToyyibPay API...');
      debugPrint('📞 Bill Name: ${widget.event.title}');
      debugPrint('📞 Bill Amount: ${widget.event.price}');
      debugPrint('📞 User Email: ${SupabaseConfig.auth.currentUser?.email}');
      debugPrint('📞 User Phone: ${_userProfile?.phoneNumber}');
      debugPrint('📞 User Name: ${_userProfile?.fullName}');

      final billCode = await _paymentService.createBill(
        billName: widget.event.title,
        billDescription: 'Registration for ${widget.event.title}',
        billAmount: widget.event.price ?? 0.0,
        userEmail: SupabaseConfig.auth.currentUser?.email ?? 'user@example.com',
        userPhone: _userProfile?.phoneNumber ?? '0123456789',
        userName: _userProfile?.fullName ?? 'Student',
      );

      debugPrint('📞 ToyyibPay Response: billCode = $billCode');

      if (billCode != null) {
        // 2. Get Payment URL
        final paymentUrl = _paymentService.getPaymentUrl(billCode);

        if (mounted) {
          // On web, open in new tab (WebView doesn't work on web)
          if (kIsWeb) {
            await launchUrl(Uri.parse(paymentUrl),
                mode: LaunchMode.externalApplication);
            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Payment page opened in new tab. Complete payment there.'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            }
          } else {
            // 3. Open WebView (mobile only)
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentWebViewScreen(
                  paymentUrl: paymentUrl,
                  title: 'Payment Gateway',
                ),
              ),
            );

            // 4. Handle Result
            if (mounted && result == true) {
              Navigator.pop(context, true); // Return success to previous screen
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment failed or cancelled.'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initialize payment. Please try again.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Summary'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppTheme.spaceXl),
                  _buildDetails(),
                  const Spacer(),
                  _buildTotal(),
                  const SizedBox(height: AppTheme.spaceMd),
                  _buildPayButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 64, color: AppTheme.primaryColor),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'Order Summary',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color:
            theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          _buildRow('Event', widget.event.title),
          Divider(color: theme.dividerColor),
          _buildRow('Date',
              widget.event.eventDate?.toString().split(' ')[0] ?? 'TBA'),
          Divider(color: theme.dividerColor),
          _buildRow('Ref ID', '#${widget.event.id.substring(0, 8)}'),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total Amount',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          'RM ${(widget.event.price ?? 0).toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        onPressed: _proceedToPayment,
        child: const Text(
          'Pay with ToyyibPay (FPX)',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
