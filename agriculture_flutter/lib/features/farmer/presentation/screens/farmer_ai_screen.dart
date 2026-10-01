import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../widgets/farmer_glass.dart';

import '../../data/models/farm_model.dart';
import '../../data/services/farm_ai_service.dart';
import '../../data/services/farm_service.dart';

class FarmerAiScreen extends StatefulWidget {
  const FarmerAiScreen({super.key});

  @override
  State<FarmerAiScreen> createState() => _FarmerAiScreenState();
}

class _FarmerAiScreenState extends State<FarmerAiScreen> {
  final _form = GlobalKey<FormState>();

  final _objective = TextEditingController(
    text: 'Suggest crops suitable for my soil and planting month',
  );

  final _temperature = TextEditingController();
  final _ph = TextEditingController();
  final _elevation = TextEditingController();
  final _rainfall = TextEditingController();
  final _humidity = TextEditingController();

  final _api = FarmAiService.instance;
  final _excluded = <String>{};

  List<FarmModel> _farms = [];
  FarmModel? _farm;

  int _month = DateTime.now().month;
  int _drainage = -1;
  int _wetZone = -1;

  bool _loadingFarms = true;
  bool _busy = false;
  String? _farmError;
  String? _error;

  // Retain the exact body for a network retry.
  Map<String, dynamic>? _pendingRequest;
  Map<String, dynamic>? _analysis;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void dispose() {
    for (final controller in [
      _objective,
      _temperature,
      _ph,
      _elevation,
      _rainfall,
      _humidity,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFarms() async {
    setState(() {
      _loadingFarms = true;
      _farmError = null;
    });

    try {
      final farms = await FarmService.instance.list();

      if (!mounted) return;

      setState(() {
        _farms = farms.where((farm) => farm.isActive).toList();
        _farm = _farms.isEmpty ? null : _farms.first;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _farmError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingFarms = false);
      }
    }
  }

  double? _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  bool? _boolean(int value) => value == -1 ? null : value == 1;

  Map<String, dynamic> _request() {
    final excluded = _excluded.toList()..sort();

    return {
      'requestId': FarmAiService.newRequestId(),
      'farmId': _farm!.id,
      'objective': _objective.text.trim(),
      'plantingMonth': _month,
      'wellDrained': _boolean(_drainage),
      'temperatureC': _number(_temperature),
      'soilPh': _number(_ph),
      'elevationM': _number(_elevation),
      'upcountryWetZone': _boolean(_wetZone),
      'rainfallMmMonth': _number(_rainfall),
      'humidityPercent': _number(_humidity),
      'excludedCropIds': excluded,
    };
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_pendingRequest == null) {
      if (!(_form.currentState?.validate() ?? false)) return;

      final farm = _farm;
      if (farm == null) return;

      if ((farm.soilType ?? '').trim().isEmpty ||
          (farm.irrigationType ?? '').trim().isEmpty) {
        setState(() {
          _error =
              'Update this farm’s soil and irrigation details '
              'in My Farms first.';
        });
        return;
      }

      _pendingRequest = _request();
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await _api.analyze(_pendingRequest!);

      if (!mounted) return;

      setState(() {
        _analysis = response;

        // Keep the request while processing so retries replay it.
        if (response['status'] != 'PROCESSING') {
          _pendingRequest = null;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _editInputs() {
    setState(() {
      _pendingRequest = null;
      _analysis = null;
      _error = null;
    });
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.65),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    double minimum,
    double maximum,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: _decoration('$label (optional)'),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        validator: (text) {
          final value = (text ?? '').trim();
          if (value.isEmpty) return null;

          final number = double.tryParse(value);
          if (number == null ||
              !number.isFinite ||
              number < minimum ||
              number > maximum) {
            return 'Enter a number between $minimum and $maximum.';
          }

          return null;
        },
      ),
    );
  }

  Widget _booleanField(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: _decoration(label),
        items: const [
          DropdownMenuItem(value: -1, child: Text('Unknown')),
          DropdownMenuItem(value: 1, child: Text('Yes')),
          DropdownMenuItem(value: 0, child: Text('No')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => onChanged(value));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _pendingRequest != null;

    return PopScope(
      canPop: !_busy,
      child: FarmerGlassPage(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Farmer AI'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Analysis history',
                icon: const Icon(Icons.history),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const _HistoryScreen(),
                        ),
                      ),
              ),
            ],
          ),
          body: _loadingFarms
              ? const Center(child: CircularProgressIndicator())
              : _farmError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_farmError!),
                        TextButton(
                          onPressed: _loadFarms,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _farms.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Add an active farm in My Farms first. '
                      'You can still view previous analyses '
                      'using the history button.',
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const FarmerGlassHero(
                      eyebrow: 'Farmer AI',
                      title: 'Find suitable crops',
                      subtitle:
                          'Compare chilli, okra and brinjal using '
                          'your farm details. Leave values unknown '
                          'when you have not measured them.',
                      icon: Icons.auto_awesome_outlined,
                    ),
                    const SizedBox(height: 22),
                    FarmerGlassCard(
                      emphasized: true,
                      padding: const EdgeInsets.all(18),
                      child: AbsorbPointer(
                        absorbing: locked,
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<int>(
                                initialValue: _farm?.id,
                                isExpanded: true,
                                decoration: _decoration('Farm'),
                                items: [
                                  for (final farm in _farms)
                                    DropdownMenuItem(
                                      value: farm.id,
                                      child: Text(
                                        farm.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (id) {
                                  if (id == null) return;
                                  setState(() {
                                    _farm = _farms.firstWhere(
                                      (farm) => farm.id == id,
                                    );
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Soil: ${_farm?.soilType ?? "Not set"}\n'
                                'Irrigation: '
                                '${_farm?.irrigationType ?? "Not set"}',
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _objective,
                                maxLength: 500,
                                minLines: 2,
                                maxLines: 4,
                                decoration: _decoration('Your objective'),
                                validator: (value) {
                                  if ((value ?? '').trim().length < 3) {
                                    return 'Enter at least 3 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int>(
                                initialValue: _month,
                                decoration: _decoration('Planting month'),
                                items: [
                                  for (var i = 0; i < 12; i++)
                                    DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(_months[i]),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _month = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _booleanField(
                                'Is the soil well drained?',
                                _drainage,
                                (value) => _drainage = value,
                              ),
                              _booleanField(
                                'Is the farm in the upcountry wet zone?',
                                _wetZone,
                                (value) => _wetZone = value,
                              ),
                              _numberField(
                                _temperature,
                                'Temperature °C',
                                -10,
                                60,
                              ),
                              _numberField(_ph, 'Soil pH', 0, 14),
                              _numberField(
                                _elevation,
                                'Elevation in metres',
                                0,
                                9000,
                              ),
                              _numberField(
                                _rainfall,
                                'Monthly rainfall in mm',
                                0,
                                3000,
                              ),
                              _numberField(_humidity, 'Humidity %', 0, 100),
                              const Text('Exclude crops'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final crop in [
                                    'chilli',
                                    'okra',
                                    'brinjal',
                                  ])
                                    FilterChip(
                                      label: Text(crop),
                                      selected: _excluded.contains(crop),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _excluded.add(crop);
                                          } else {
                                            _excluded.remove(crop);
                                          }
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        _busy
                            ? 'Analyzing…'
                            : _pendingRequest != null
                            ? 'Retry / check same request'
                            : 'Analyze farm',
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text(
                        'This may take a few minutes. '
                        'Please keep this screen open.',
                      ),
                    ],
                    if (_pendingRequest != null && !_busy) ...[
                      TextButton(
                        onPressed: _editInputs,
                        child: const Text('Edit inputs for a new request'),
                      ),
                      const Text(
                        'The previous request may still finish. '
                        'Check History before starting another.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                    if (_analysis != null) ...[
                      const SizedBox(height: 24),
                      _AnalysisResult(data: _analysis!),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _AnalysisResult extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AnalysisResult({required this.data});

  Widget _list(String title, dynamic value) {
    if (value is! List || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final item in value)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawResult = data['result'];
    final result = rawResult is Map
        ? Map<String, dynamic>.from(rawResult)
        : <String, dynamic>{};

    final status = data['status']?.toString() ?? 'UNKNOWN';
    final rawCrops = result['recommendations'];
    final crops = rawCrops is List ? rawCrops : const [];

    final description = switch (status) {
      'COMPLETED' =>
        'These crops are conditionally suitable. Review the checks below.',
      'NEEDS_INPUT' =>
        'More information is required. Update the form and analyze again.',
      'NO_MATCH' => 'No crop matched the supplied conditions and exclusions.',
      'FAILED' => 'The analysis failed. You can submit a new analysis.',
      'PROCESSING' =>
        'The analysis is still running. Check this request again shortly.',
      _ => 'Review the analysis details.',
    };

    return FarmerGlassCard(
      emphasized: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data['farmName']?.toString() ?? 'Farm analysis',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(description),
          if (data['errorCode'] != null)
            Text(
              'Error: ${data['errorCode']}',
              style: const TextStyle(color: Colors.red),
            ),
          _list('Required information', result['missing_fields']),
          if (status == 'COMPLETED')
            for (final raw in crops.whereType<Map>())
              FarmerGlassCard(
                emphasized: true,
                margin: const EdgeInsets.only(top: 14),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${raw['name'] ?? raw['crop_id']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${raw['suitability'] ?? ''}'),
                      _list('Why this crop', raw['reasons']),
                      _list('Checks needed', raw['checks_needed']),
                      if (raw['season_note'] != null) ...[
                        const SizedBox(height: 12),
                        Text('${raw['season_note']}'),
                      ],
                    ],
                  ),
                ),
              ),
          _list('Limitations', result['limitations']),
        ],
      ),
    );
  }
}

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen();

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  final _api = FarmAiService.instance;

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api.history(page);
      if (!mounted) return;

      setState(() {
        _items = items;
        _page = page;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '';

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FarmerGlassPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Analysis history'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _loading ? null : () => _load(_page),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(child: Text('No analyses on this page.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final row = _items[index];

                              return FarmerGlassCard(
                                emphasized: true,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: const Icon(Icons.eco_outlined),
                                  title: Text('${row['farmName']}'),
                                  subtitle: Text(
                                    '${row['status']} • '
                                    '${_date(row['createdAt'])}\n'
                                    '${row['objective']}',
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => _AnalysisDetailsScreen(
                                        id: '${row['id']}',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _page > 1 ? () => _load(_page - 1) : null,
                          child: const Text('Previous'),
                        ),
                        Text('Page $_page'),
                        TextButton(
                          onPressed: _items.length == 20
                              ? () => _load(_page + 1)
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AnalysisDetailsScreen extends StatefulWidget {
  final String id;

  const _AnalysisDetailsScreen({required this.id});

  @override
  State<_AnalysisDetailsScreen> createState() => _AnalysisDetailsScreenState();
}

class _AnalysisDetailsScreenState extends State<_AnalysisDetailsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = FarmAiService.instance.get(widget.id);
  }

  void _refresh() {
    setState(() {
      _future = FarmAiService.instance.get(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FarmerGlassPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Analysis details'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snapshot.error}'),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [_AnalysisResult(data: snapshot.requireData)],
            );
          },
        ),
      ),
    );
  }
}
