import 'package:flutter/material.dart';

import '../../../core/validation/validators.dart';
import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Manage responders & admins": create invite rows for both
/// orgs, deactivate/reactivate accounts.
class PeopleTab extends StatefulWidget {
  const PeopleTab({super.key});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> with SingleTickerProviderStateMixin {
  final _repository = AdminRepository();
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _respondersFuture;
  late Future<List<Map<String, dynamic>>> _adminsFuture;
  late Future<List<Map<String, dynamic>>> _zonesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  void _refresh() {
    setState(() {
      _respondersFuture = _repository.fetchResponders();
      _adminsFuture = _repository.fetchAdmins();
      _zonesFuture = _repository.fetchZones();
    });
  }

  Future<void> _openInviteResponder() async {
    final zones = await _zonesFuture;
    if (!mounted) return;
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String organization = 'nmu_campus_security';
    String? coverageZoneId = zones.isNotEmpty ? zones.first['zone_id'] as String : null;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite a responder'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => requiredValidator(v, field: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: emailValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: (v) => phoneValidator(v, required: true),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: organization,
                    decoration: const InputDecoration(labelText: 'Organization'),
                    items: const [
                      DropdownMenuItem(
                        value: 'nmu_campus_security',
                        child: Text('NMU Campus Security'),
                      ),
                      DropdownMenuItem(
                        value: 'security_company',
                        child: Text('Security Company'),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => organization = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: coverageZoneId,
                    decoration: const InputDecoration(labelText: 'Coverage zone'),
                    items: [
                      for (final zone in zones)
                        DropdownMenuItem(
                          value: zone['zone_id'] as String,
                          child: Text(zone['name'] as String),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => coverageZoneId = v),
                  ),
                ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await _repository.inviteResponder(
                  email: emailController.text.trim(),
                  fullName: nameController.text.trim(),
                  phone: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  organization: organization,
                  coverageZoneId: coverageZoneId,
                );
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('Create invite'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invite created. They can now activate it from Create Account.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openInviteAdmin() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite an admin'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => requiredValidator(v, field: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: emailValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (v) => phoneValidator(v, required: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _repository.inviteAdmin(
                email: emailController.text.trim(),
                fullName: nameController.text.trim(),
                phone: phoneController.text.trim(),
              );
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Create invite'),
          ),
        ],
      ),
    );

    if (created == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invite created. They can now activate it from Create Account.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [Tab(text: 'Responders'), Tab(text: 'Admins')],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildResponders(), _buildAdmins()],
          ),
        ),
      ],
    );
  }

  Widget _buildResponders() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _respondersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
        }
        final responders = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _openInviteResponder,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Invite responder'),
              ),
            ),
            const SizedBox(height: 16),
            if (responders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No responders yet.'),
              ),
            for (final r in responders)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (r['status'] == 'active')
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.shield_outlined,
                      color: r['status'] == 'active' ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(r['full_name'] as String? ?? r['email'] as String),
                  subtitle: Text(
                    '${orgLabel(r['organization'] as String)} · '
                    '${(r['zones'] as Map?)?['name'] ?? 'No zone'} · '
                    '${r['email']}\n'
                    'Account: ${r['activation_status']} · Duty: ${r['status']}',
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: r['status'] == 'active',
                    onChanged: (v) async {
                      await _repository.setResponderDutyStatus(
                        r['responder_id'] as String,
                        v ? 'active' : 'inactive',
                      );
                      _refresh();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAdmins() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
        }
        final admins = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _openInviteAdmin,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Invite admin'),
              ),
            ),
            const SizedBox(height: 16),
            for (final a in admins)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings_outlined)),
                  title: Text(a['full_name'] as String? ?? a['email'] as String),
                  subtitle: Text(
                    '${a['email']}${a['phone'] != null ? ' · ${a['phone']}' : ''}\n'
                    'Account: ${a['activation_status']}',
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: a['is_active'] as bool? ?? true,
                    onChanged: (v) async {
                      await _repository.setAdminActive(a['admin_id'] as String, v);
                      _refresh();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
