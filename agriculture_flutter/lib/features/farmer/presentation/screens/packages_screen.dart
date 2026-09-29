import 'package:flutter/material.dart';
import '../widgets/farmer_ui.dart';
import '../widgets/farmer_glass.dart';
import '../widgets/package_images.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/package_models.dart';
import '../../data/services/package_service.dart';

Future<bool?> showFarmerPackageBooking(BuildContext context, Package package) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      useSafeArea: true,
      builder: (_) => FarmerPage(child: _BookingSheet(package: package)),
    );

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  static const _categories = [null, 'MACHINERY', 'INPUTS', 'TRANSPORT'];
  String? _category;

  late Future<List<Package>> _packagesFuture;
  late Future<List<PackageBooking>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _packagesFuture = PackageService.instance.list();
    _bookingsFuture = Future.value([]);
    _tab.addListener(() {
      if (_tab.index == 1 && !_tab.indexIsChanging) _loadBookings();
    });
  }

  void _loadPackages() {
    if (!mounted) return;
    setState(() {
      _packagesFuture = PackageService.instance.list(category: _category);
    });
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    setState(() => _bookingsFuture = PackageService.instance.myBookings());
    try {
      await _bookingsFuture;
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _openBooking(Package package) async {
    final booked = await showFarmerPackageBooking(context, package);

    if (booked == true) _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    return FarmerGlassPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Packages'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          bottom: TabBar(
            controller: _tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Browse'),
              Tab(text: 'My bookings'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [_browseTab(), _bookingsTab()],
        ),
      ),
    );
  }

  Widget _browseTab() {
    return Column(
      children: [
        SizedBox(
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: _categories
                .map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        value == null
                            ? 'All services'
                            : {
                                'MACHINERY': 'Machinery',
                                'INPUTS': 'Seeds & fertilizer',
                                'TRANSPORT': 'Transport',
                              }[value]!,
                      ),
                      selected: _category == value,
                      selectedColor: AppColors.soft,
                      labelStyle: TextStyle(
                        color: _category == value
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) {
                        setState(() => _category = value);
                        _loadPackages();
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Package>>(
            future: _packagesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _Message(error: snapshot.error, onRetry: _loadPackages);
              }

              final packages = snapshot.data ?? [];

              if (packages.isEmpty) {
                return const _Message(
                  message: 'No packages are available right now.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  _loadPackages();
                  try {
                    await _packagesFuture;
                  } catch (_) {}
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const FarmerGlassHero(
                      eyebrow: 'Support for every season',
                      title: 'A helping hand.\nA better harvest.',
                      subtitle:
                          'Find the right machinery, inputs and transport for your farm.',
                      icon: Icons.agriculture_outlined,
                    ),
                    FarmerSection(
                      'Available services',
                      subtitle:
                          '${packages.length} packages to support your next step.',
                    ),
                    ...packages.map(
                      (package) => _PackageCard(
                        package: package,
                        onTap: () => _openBooking(package),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _bookingsTab() {
    return FutureBuilder<List<PackageBooking>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _Message(error: snapshot.error, onRetry: _loadBookings);
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return const _Message(message: 'You have not booked anything yet.');
        }

        return RefreshIndicator(
          onRefresh: _loadBookings,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const FarmerHero(
                eyebrow: 'Your service requests',
                title: 'Every booking, in view.',
                subtitle: 'Follow your requests from review to completion.',
                icon: Icons.event_note_outlined,
              ),
              FarmerSection(
                'My bookings',
                subtitle: '${bookings.length} service requests',
              ),
              ...bookings.map((b) => _BookingTile(booking: b)),
            ],
          ),
        );
      },
    );
  }
}

IconData _serviceIcon(String category) => switch (category) {
  'MACHINERY' => Icons.agriculture_outlined,
  'INPUTS' => Icons.eco_outlined,
  _ => Icons.local_shipping_outlined,
};

class _PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback onTap;
  const _PackageCard({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) => FarmerGlassCard(
    margin: const EdgeInsets.only(bottom: 18),
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: PackageCoverImage(package: package),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0DE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    package.categoryLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  package.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  package.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  package.rateLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                if (package.minimumCharge != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Minimum charge: Rs. ${package.minimumCharge!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View details & estimate'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BookingSheet extends StatefulWidget {
  final Package package;

  const _BookingSheet({required this.package});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _acres = TextEditingController();
  final _distance = TextEditingController();
  final _load = TextEditingController();
  final _notes = TextEditingController();

  PackageQuote? _quote;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [_acres, _distance, _load]) {
      controller.addListener(_invalidateQuote);
    }
  }

  void _invalidateQuote() {
    if (_quote != null) setState(() => _quote = null);
  }

  @override
  void dispose() {
    _acres.dispose();
    _distance.dispose();
    _load.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _getQuote() async {
    setState(() {
      _error = null;
      _quote = null;
    });

    final acres = double.tryParse(_acres.text.trim());
    final distance = double.tryParse(_distance.text.trim());
    final load = double.tryParse(_load.text.trim());

    final quantity = widget.package.isTransport ? distance : acres;
    if (quantity == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        (widget.package.isTransport &&
            _load.text.trim().isNotEmpty &&
            (load == null || !load.isFinite || load < 0))) {
      setState(
        () => _error =
            'Enter a valid positive size or distance, and a valid load weight.',
      );
      return;
    }
    setState(() => _busy = true);

    try {
      final quote = await PackageService.instance.quote(
        packageId: widget.package.id,
        landSizeAcres: widget.package.isTransport ? null : acres,
        distanceKm: widget.package.isTransport ? distance : null,
        loadWeightKg: widget.package.isTransport ? load : null,
      );

      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _book() async {
    if (_quote == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final acres = double.tryParse(_acres.text.trim());
    final distance = double.tryParse(_distance.text.trim());
    final load = double.tryParse(_load.text.trim());

    try {
      await PackageService.instance.book(
        packageId: widget.package.id,
        landSizeAcres: widget.package.isTransport ? null : acres,
        distanceKm: widget.package.isTransport ? distance : null,
        loadWeightKg: widget.package.isTransport ? load : null,
        notes: _notes.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking sent. You will be notified once reviewed.'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Icon(_serviceIcon(package.category), color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    package.categoryLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (package.images.isNotEmpty) ...[
              PackageImageGallery(package: package),
              const SizedBox(height: 18),
            ],
            Text(
              package.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              package.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const FarmerSection(
              '01  Service details',
              subtitle: 'Enter your requirements to calculate the price.',
            ),
            Text(
              package.rateLabel,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (!package.isTransport)
              TextField(
                controller: _acres,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Land size (acres)',
                ),
                enabled: !_busy,
              ),
            if (package.isTransport) ...[
              TextField(
                controller: _distance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Distance (km)'),
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _load,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Load weight (kg, optional)',
                  helperText: package.maxLoadKg == null
                      ? null
                      : '${package.maxLoadKg!.toStringAsFixed(0)} kg included free',
                ),
                enabled: !_busy,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _getQuote,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text(
                'Calculate estimate',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            if (_quote != null) ...[
              const FarmerSection('02  Your estimate'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_quote!.calculatedQuantity.toStringAsFixed(2)} ${_quote!.quantityUnit}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      'Total: Rs. ${_quote!.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_busy || _quote == null) ? null : _book,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm booking request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final PackageBooking booking;

  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (booking.status) {
      'CONFIRMED' => ('Confirmed', const Color(0xFF2E7D46)),
      'REJECTED' => ('Rejected', AppColors.error),
      'COMPLETED' => ('Completed', AppColors.textSecondary),
      _ => ('Pending', const Color(0xFFB8860B)),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.packageName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Booking #${booking.id} | ${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs. ${booking.totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (booking.adminNote != null && booking.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Admin note: ${booking.adminNote}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final Object? error;
  final String message;
  final VoidCallback? onRetry;

  const _Message({
    this.error,
    this.message = 'Something went wrong.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final problem = error;
    final text = problem is PackageException ? problem.message : message;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      children: [
        FarmerEmpty(
          icon: error == null
              ? Icons.agriculture_outlined
              : Icons.cloud_off_outlined,
          title: error == null ? 'Nothing here yet' : 'Unable to load services',
          message: text,
          onAction: onRetry,
        ),
      ],
    );
  }
}
