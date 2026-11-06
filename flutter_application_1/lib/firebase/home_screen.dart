import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'crud/firestore_service.dart';
import 'crud/measurement.dart';
import 'crud/edit_measurement.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirestoreService();
  final _auth = AuthService();

  // Controllers untuk form tambah data (tab 3)
  final _kwhController = TextEditingController();
  final _teganganController = TextEditingController();
  final _arusController = TextEditingController();
  final _perangkatController = TextEditingController();
  String _status = 'normal';

  // Filter untuk tab Dashboard
  String? _dashboardStatus; // null = semua
  late DateTime _dashboardStartDate;
  late DateTime _dashboardEndDate;

  // Filter untuk tab Riwayat
  String? _selectedStatus; // null = semua
  DateTime? _startDate;
  DateTime? _endDate;

  DateTime get _firstDayOfCurrentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _lastDayOfCurrentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  bool get _isDashboardDefaultMonth {
    final start = _firstDayOfCurrentMonth;
    final end = _lastDayOfCurrentMonth;
    return _dashboardStatus == null &&
        _dashboardStartDate.year == start.year &&
        _dashboardStartDate.month == start.month &&
        _dashboardStartDate.day == start.day &&
        _dashboardEndDate.year == end.year &&
        _dashboardEndDate.month == end.month &&
        _dashboardEndDate.day == end.day;
  }

  bool get _hasActiveDashboardFilter => !_isDashboardDefaultMonth || _dashboardStatus != null;

  bool get _hasActiveFilter => _selectedStatus != null || _startDate != null || _endDate != null;

  String get _filterSummary {
    final parts = <String>[];
    if (_selectedStatus != null) {
      parts.add(_selectedStatus!.toUpperCase());
    }
    if (_startDate != null || _endDate != null) {
      parts.add('Periode');
    }
    return parts.isEmpty ? 'Semua Data' : parts.join(' • ');
  }

  String get _dashboardFilterSummary {
    final parts = <String>[];
    if (_dashboardStatus != null) {
      parts.add(_dashboardStatus!.toUpperCase());
    }

    final startText = DateFormat('dd MMM yyyy').format(_dashboardStartDate);
    final endText = DateFormat('dd MMM yyyy').format(_dashboardEndDate);
    parts.add(_isDashboardDefaultMonth ? 'Bulan Ini' : '$startText - $endText');

    return parts.join(' • ');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dashboardStartDate = _firstDayOfCurrentMonth;
    _dashboardEndDate = _lastDayOfCurrentMonth;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kwhController.dispose();
    _teganganController.dispose();
    _arusController.dispose();
    _perangkatController.dispose();
    super.dispose();
  }

  Future<void> _addMeasurement() async {
    final now = DateTime.now();
    final measurement = Measurement(
      userId: _auth.currentUser!.uid,
      tanggal: now,
      kwh: double.tryParse(_kwhController.text) ?? 0,
      tegangan: double.tryParse(_teganganController.text) ?? 0,
      arus: double.tryParse(_arusController.text) ?? 0,
      status: _status,
      perangkat: _perangkatController.text,
    );

    try {
      await _firestore.addMeasurement(measurement);
      _clearForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil ditambahkan')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambah data: $e')),
      );
    }
  }

  void _clearForm() {
    _kwhController.clear();
    _teganganController.clear();
    _arusController.clear();
    _perangkatController.clear();
    setState(() => _status = 'normal');
  }

  void _resetDashboardToCurrentMonth() {
    setState(() {
      _dashboardStatus = null;
      _dashboardStartDate = _firstDayOfCurrentMonth;
      _dashboardEndDate = _lastDayOfCurrentMonth;
    });
  }

  List<Measurement> _applyDashboardFilter(List<Measurement> data) {
    final start = DateTime(
      _dashboardStartDate.year,
      _dashboardStartDate.month,
      _dashboardStartDate.day,
    );
    final end = DateTime(
      _dashboardEndDate.year,
      _dashboardEndDate.month,
      _dashboardEndDate.day,
      23,
      59,
      59,
    );

    var filtered = data.where((m) {
      final isInDateRange = !m.tanggal.isBefore(start) && !m.tanggal.isAfter(end);
      final isStatusMatch = _dashboardStatus == null || m.status == _dashboardStatus;
      return isInDateRange && isStatusMatch;
    }).toList();

    filtered.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return filtered;
  }

  void _showDashboardFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? tempStatus = _dashboardStatus;
        DateTime tempStart = _dashboardStartDate;
        DateTime tempEnd = _dashboardEndDate;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickStartDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: tempStart,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setModalState(() {
                  tempStart = DateTime(picked.year, picked.month, picked.day);
                  if (tempStart.isAfter(tempEnd)) {
                    tempEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: tempEnd,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setModalState(() {
                  tempEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                  if (tempEnd.isBefore(tempStart)) {
                    tempStart = DateTime(picked.year, picked.month, picked.day);
                  }
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Dashboard',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: tempStatus == null,
                        onSelected: (_) => setModalState(() => tempStatus = null),
                      ),
                      ChoiceChip(
                        label: const Text('Normal'),
                        selected: tempStatus == 'normal',
                        backgroundColor: Colors.green[100],
                        selectedColor: Colors.green[300],
                        onSelected: (_) => setModalState(() => tempStatus = 'normal'),
                      ),
                      ChoiceChip(
                        label: const Text('Warning'),
                        selected: tempStatus == 'warning',
                        backgroundColor: Colors.orange[100],
                        selectedColor: Colors.orange[300],
                        onSelected: (_) => setModalState(() => tempStatus = 'warning'),
                      ),
                      ChoiceChip(
                        label: const Text('Error'),
                        selected: tempStatus == 'error',
                        backgroundColor: Colors.red[100],
                        selectedColor: Colors.red[300],
                        onSelected: (_) => setModalState(() => tempStatus = 'error'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Periode', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: pickStartDate,
                          child: Text(DateFormat('dd MMM yyyy').format(tempStart)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('–'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: pickEndDate,
                          child: Text(DateFormat('dd MMM yyyy').format(tempEnd)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatus = null;
                            tempStart = _firstDayOfCurrentMonth;
                            tempEnd = _lastDayOfCurrentMonth;
                          });
                        },
                        child: const Text('Reset bulan ini'),
                      ),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _dashboardStatus = tempStatus;
                            _dashboardStartDate = tempStart;
                            _dashboardEndDate = tempEnd;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Terapkan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = null;
      _startDate = null;
      _endDate = null;
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String? tempStatus = _selectedStatus;
        DateTime? tempStart = _startDate;
        DateTime? tempEnd = _endDate;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Riwayat',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Status Filter
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: tempStatus == null,
                        onSelected: (_) => setModalState(() => tempStatus = null),
                      ),
                      ChoiceChip(
                        label: const Text('Normal'),
                        selected: tempStatus == 'normal',
                        backgroundColor: Colors.green[100],
                        selectedColor: Colors.green[300],
                        onSelected: (_) => setModalState(() => tempStatus = 'normal'),
                      ),
                      ChoiceChip(
                        label: const Text('Warning'),
                        selected: tempStatus == 'warning',
                        backgroundColor: Colors.orange[100],
                        selectedColor: Colors.orange[300],
                        onSelected: (_) => setModalState(() => tempStatus = 'warning'),
                      ),
                      ChoiceChip(
                        label: const Text('Error'),
                        selected: tempStatus == 'error',
                        backgroundColor: Colors.red[100],
                        selectedColor: Colors.red[300],
                        onSelected: (_) => setModalState(() => tempStatus = 'error'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Periode Tanggal
                  const Text('Periode', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempStart ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() => tempStart = picked);
                            }
                          },
                          child: Text(
                            tempStart == null
                                ? 'Mulai'
                                : DateFormat('dd MMM yyyy').format(tempStart!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('–'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempEnd ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (picked != null) {
                              setModalState(() => tempEnd = picked);
                            }
                          },
                          child: Text(
                            tempEnd == null
                                ? 'Selesai'
                                : DateFormat('dd MMM yyyy').format(tempEnd!),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatus = null;
                            tempStart = null;
                            tempEnd = null;
                          });
                        },
                        child: const Text('Reset di sini'),
                      ),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatus = tempStatus;
                            _startDate = tempStart;
                            _endDate = tempEnd;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Terapkan'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elektro Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.history), text: 'Riwayat'),
            Tab(icon: Icon(Icons.add_circle), text: 'Tambah'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Keluar?'),
                  content: const Text('Anda akan keluar dari akun.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) await _auth.signOut();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildRiwayatTab(),
          _buildTambahTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Dashboard ($_dashboardFilterSummary)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_hasActiveDashboardFilter)
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 18, color: Colors.redAccent),
                  label: const Text('Bulan Ini', style: TextStyle(color: Colors.redAccent)),
                  onPressed: _resetDashboardToCurrentMonth,
                ),
              TextButton.icon(
                icon: const Icon(Icons.filter_list, size: 20),
                label: const Text('Filter'),
                onPressed: _showDashboardFilterBottomSheet,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Measurement>>(
            stream: _firestore.getMeasurements(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Terjadi kesalahan: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final measurements = _applyDashboardFilter(snapshot.data ?? []);

              if (measurements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.insights_outlined, size: 72, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada data untuk dashboard',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _dashboardFilterSummary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                );
              }

              final totalKwh = measurements.fold<double>(0, (sum, m) => sum + m.kwh);
              final averageVoltage = measurements.fold<double>(0, (sum, m) => sum + m.tegangan) / measurements.length;
              final averageCurrent = measurements.fold<double>(0, (sum, m) => sum + m.arus) / measurements.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ringkasan Pemakaian',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dashboardFilterSummary,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildSummaryTile(
                                  title: 'Total kWh',
                                  value: '${totalKwh.toStringAsFixed(2)} kWh',
                                  icon: Icons.bolt,
                                ),
                                _buildSummaryTile(
                                  title: 'Rata-rata Tegangan',
                                  value: '${averageVoltage.toStringAsFixed(1)} V',
                                  icon: Icons.electric_meter,
                                ),
                                _buildSummaryTile(
                                  title: 'Rata-rata Arus',
                                  value: '${averageCurrent.toStringAsFixed(2)} A',
                                  icon: Icons.power,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grafik Pemakaian kWh',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Data ditampilkan sesuai filter dashboard.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: true),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: measurements.length > 8 ? (measurements.length / 6).ceilToDouble() : 1,
                                        getTitlesWidget: (value, meta) {
                                          final index = value.toInt();
                                          if (index < 0 || index >= measurements.length) return const Text('');
                                          final date = measurements[index].tanggal;
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                              DateFormat('dd/MM').format(date),
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                          );
                                        },
                                        reservedSize: 32,
                                      ),
                                    ),
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: measurements.asMap().entries.map((e) {
                                        return FlSpot(e.key.toDouble(), e.value.kwh);
                                      }).toList(),
                                      isCurved: true,
                                      color: Colors.amber,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: true),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSummaryTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.amber.withOpacity(0.10),
          border: Border.all(color: Colors.amber.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.amber[800]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatTab() {
  return Column(
    children: [
      // Header filter – SELALU TAMPIL
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Riwayat ($_filterSummary)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_hasActiveFilter)
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 18, color: Colors.redAccent),
                label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                onPressed: _clearAllFilters,
              ),
            TextButton.icon(
              icon: const Icon(Icons.filter_list, size: 20),
              label: const Text('Filter'),
              onPressed: _showFilterBottomSheet,
            ),
          ],
        ),
      ),

      // Isi daftar atau pesan kosong
      Expanded(
        child: StreamBuilder<List<Measurement>>(
          stream: _firestore.getMeasurements(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Terjadi kesalahan: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            }

            var measurements = snapshot.data ?? [];

            // Terapkan filter
            if (_selectedStatus != null) {
              measurements = measurements.where((m) => m.status == _selectedStatus).toList();
            }
            if (_startDate != null) {
              final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
              measurements = measurements.where((m) => !m.tanggal.isBefore(start)).toList();
            }
            if (_endDate != null) {
              final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
              measurements = measurements.where((m) => !m.tanggal.isAfter(end)).toList();
            }

            // Urutkan terbaru ke terlama
            measurements.sort((a, b) => b.tanggal.compareTo(a.tanggal));

            if (measurements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.filter_list_off,
                      size: 72,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada data sesuai filter',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _filterSummary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    if (!_hasActiveFilter) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '(Belum ada pengukuran yang tercatat sama sekali)',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: measurements.length,
              itemBuilder: (context, index) {
                final m = measurements[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m.status == 'normal'
                          ? Colors.green
                          : m.status == 'warning'
                              ? Colors.orange
                              : Colors.red,
                      child: Text(m.status[0].toUpperCase()),
                    ),
                    title: Text('${m.perangkat} - ${m.kwh.toStringAsFixed(2)} kWh'),
                    subtitle: Text(DateFormat('dd MMM yyyy • HH:mm').format(m.tanggal)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => EditMeasurementDialog(
                                measurement: m,
                                onSave: (updated) async {
                                  await _firestore.updateMeasurement(m.id!, updated);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Data berhasil diupdate')),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Hapus?'),
                                content: const Text('Data ini akan dihapus permanen.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Batal'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _firestore.deleteMeasurement(m.id!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Data dihapus')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

  Widget _buildTambahTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.electric_meter_rounded, size: 100, color: Colors.amber),
          const SizedBox(height: 24),
          Text(
            'Tambah Pengukuran Baru',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _kwhController,
            decoration: const InputDecoration(labelText: 'kWh', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _teganganController,
            decoration: const InputDecoration(labelText: 'Tegangan (V)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _arusController,
            decoration: const InputDecoration(labelText: 'Arus (A)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _perangkatController,
            decoration: const InputDecoration(labelText: 'Nama Perangkat', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'warning', child: Text('Peringatan')),
              DropdownMenuItem(value: 'error', child: Text('Error')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Simpan Pengukuran'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _addMeasurement,
          ),
        ],
      ),
    );
  }
}