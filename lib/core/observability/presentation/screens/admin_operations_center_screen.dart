import 'package:flutter/material.dart';
import '../../domain/entities/system_metrics_snapshot.dart';
import '../../domain/entities/system_health_report.dart';
import '../../domain/entities/incident_record.dart';
import '../../domain/entities/driver_live_operations_view.dart';
import '../../domain/entities/operational_audit_record.dart';
import '../../domain/enums/observability_enums.dart';
import '../../../security/entities/security_event.dart';

/// غرفة العمليات والتحكم الإداري الموحدة (MADAR Admin Operations Center Screen)
class AdminOperationsCenterScreen extends StatefulWidget {
  final SystemMetricsSnapshot? initialMetrics;
  final SystemHealthReport? initialHealth;
  final List<IncidentRecord> initialIncidents;
  final List<DriverLiveOperationsView> liveDrivers;
  final List<OperationalAuditRecord> auditLogs;
  final List<SecurityEventRecord> initialSecurityEvents;
  final double securityScore;

  const AdminOperationsCenterScreen({
    super.key,
    this.initialMetrics,
    this.initialHealth,
    this.initialIncidents = const [],
    this.liveDrivers = const [],
    this.auditLogs = const [],
    this.initialSecurityEvents = const [],
    this.securityScore = 100.0,
  });

  @override
  State<AdminOperationsCenterScreen> createState() => _AdminOperationsCenterScreenState();
}

class _AdminOperationsCenterScreenState extends State<AdminOperationsCenterScreen> {
  int _selectedTab = 0; // 0: Overview, 1: Live Drivers, 2: Incidents, 3: Audit Log, 4: Security & Zero-Trust

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.hub, color: Color(0xFF38BDF8), size: 24),
              const SizedBox(width: 10),
              const Text(
                'MADAR OPERATIONS CENTER',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildKpiRibbon(),
            _buildTabSelector(),
            Expanded(
              child: _buildSelectedTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRibbon() {
    final metrics = widget.initialMetrics;
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1E293B).withAlpha(180),
      child: Row(
        children: [
          _buildKpiCard('Online Drivers', '${metrics?.onlineDrivers ?? 0}', Icons.directions_car, Colors.blue),
          const SizedBox(width: 8),
          _buildKpiCard('Active Rides', '${metrics?.activeRides ?? 0}', Icons.local_taxi, Colors.cyan),
          const SizedBox(width: 8),
          _buildKpiCard('Active Deliveries', '${metrics?.activeDeliveries ?? 0}', Icons.inventory_2, Colors.orange),
          const SizedBox(width: 8),
          _buildKpiCard('Incidents', '${widget.initialIncidents.length}', Icons.warning_amber, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          _buildTabButton('System Overview', 0),
          _buildTabButton('Driver Telemetry & Risk', 1),
          _buildTabButton('Active Incidents (${widget.initialIncidents.length})', 2),
          _buildTabButton('Audit Log', 3),
          _buildTabButton('Security & Zero-Trust', 4),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF38BDF8) : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildSystemOverview();
      case 1:
        return _buildDriverTelemetry();
      case 2:
        return _buildIncidentsList();
      case 3:
        return _buildAuditLogList();
      case 4:
        return _buildSecurityTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSystemOverview() {
    final health = widget.initialHealth;
    final services = health?.services.values.toList() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Core Services Health Grid',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: services.length,
          itemBuilder: (context, idx) {
            final s = services[idx];
            final color = s.status == HealthStatus.healthy
                ? Colors.green
                : (s.status == HealthStatus.degraded ? Colors.amber : Colors.red);

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withAlpha(100)),
              ),
              child: Row(
                children: [
                  Icon(Icons.dns, color: color, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.service.key.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          '${s.status.name.toUpperCase()} • ${s.latencyMs}ms',
                          style: TextStyle(color: color, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDriverTelemetry() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.liveDrivers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = widget.liveDrivers[index];
        final riskColor = d.riskScore >= 80
            ? Colors.red
            : (d.riskScore >= 40 ? Colors.amber : Colors.green);

        return Card(
          color: const Color(0xFF1E293B),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: riskColor.withAlpha(40),
              child: Icon(Icons.person, color: riskColor),
            ),
            title: Text('Driver #${d.driverId} • ${d.presenceStatus.key.toUpperCase()}'),
            subtitle: Text(
              'GPS: ${d.gpsHealth.name.toUpperCase()} | Heartbeat: ${d.lastHeartbeatAgeSeconds}s ago | Conn: ${d.connectionQuality}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: riskColor),
              ),
              child: Text(
                'Risk: ${d.riskScore}',
                style: TextStyle(color: riskColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIncidentsList() {
    if (widget.initialIncidents.isEmpty) {
      return const Center(child: Text('No active incidents. System operating normally.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.initialIncidents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final inc = widget.initialIncidents[index];
        return Card(
          color: const Color(0xFF1E293B),
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.redAccent),
            title: Text('${inc.title} [${inc.severity.name.toUpperCase()}]'),
            subtitle: Text('Service: ${inc.affectedService.key} • Status: ${inc.status.name.toUpperCase()}'),
            trailing: Text(
              '${inc.firstSeenAt.hour}:${inc.firstSeenAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.auditLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = widget.auditLogs[index];
        return Card(
          color: const Color(0xFF1E293B),
          child: ListTile(
            leading: const Icon(Icons.security, color: Color(0xFF38BDF8)),
            title: Text('${a.actorId} -> ${a.action.key} on ${a.targetEntityType} #${a.targetEntityId}'),
            subtitle: Text('Reason: ${a.reason} | Hash: ${a.immutableHash.substring(0, 12)}...'),
          ),
        );
      },
    );
  }

  Widget _buildSecurityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 36),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Zero-Trust Security Score', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    '${widget.securityScore.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text('ZERO-TRUST ACTIVE', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Security Events & Threat Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (widget.initialSecurityEvents.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No active security violations or threats detected.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.initialSecurityEvents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ev = widget.initialSecurityEvents[index];
              return Card(
                color: const Color(0xFF1E293B),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  title: Text('${ev.eventType.key} [${ev.severity.key.toUpperCase()}]'),
                  subtitle: Text('Actor: ${ev.actorUserId} | ${ev.description}'),
                  trailing: Text(
                    '${ev.timestamp.hour}:${ev.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
