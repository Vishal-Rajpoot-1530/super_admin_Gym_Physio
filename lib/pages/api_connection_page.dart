import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ApiConnectionPage extends StatefulWidget {
  final Module initialModule;
  const ApiConnectionPage({super.key, this.initialModule = Module.gym});
  @override
  State<ApiConnectionPage> createState() => _ApiConnectionState();
}

class _ApiConnectionState extends State<ApiConnectionPage> {
  late Module module = widget.initialModule;
  final url = TextEditingController();
  late final Map<Module, TextEditingController> _emailInputs = {
    Module.gym: TextEditingController(
      text: const String.fromEnvironment(
        'PANEL_ADMIN_EMAIL',
        defaultValue: 'panel-admin@local.test',
      ),
    ),
    Module.clinic: TextEditingController(
      text: const String.fromEnvironment(
        'PHYSIO_PANEL_ADMIN_EMAIL',
        defaultValue: 'panel-admin@local.test',
      ),
    ),
  };
  final Map<Module, TextEditingController> _passwordInputs = {
    for (final module in Module.values) module: TextEditingController(),
  };
  TextEditingController get emailInput => _emailInputs[module]!;
  TextEditingController get passwordInput => _passwordInputs[module]!;
  bool busy = false, hidden = true, changed = false;
  String? message;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    fill();
  }

  void fill() {
    final c = ApiConfig.forModule(module);
    url.text = c.baseUrl;
    message = null;
  }

  @override
  void dispose() {
    url.dispose();
    for (final controller in _emailInputs.values) {
      controller.dispose();
    }
    for (final controller in _passwordInputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> check({required bool save}) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final count = await ApiService.testConnection(
        module,
        url.text,
        email: emailInput.text,
        password: passwordInput.text,
      );
      if (save) {
        await ApiConfig.save(module, url.text);
        final token = count.panelToken;
        if (token != null) {
          await ApiConfig.savePanelToken(module, token);
        }
        changed = true;
      }
      if (save && mounted) {
        Navigator.pop(context, true);
        return;
      }
      if (mounted) {
        setState(() {
          message = save
              ? 'Connection verified and saved. ${count.userCount} users found.'
              : 'Connection successful. ${count.userCount} users found. Tap Verify & Save to apply.';
          failed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = '$e';
          failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('API Connection'),
        leading: IconButton(
          onPressed: busy ? null : () => Navigator.pop(context, changed),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<Module>(
                initialValue: module,
                decoration: const InputDecoration(labelText: 'Module'),
                items: Module.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m == Module.gym ? 'Gym Management' : 'Physio Clinic',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (m) => setState(() {
                        module = m!;
                        fill();
                      }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: url,
                enabled: !busy,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  helperText: 'Gym uses its own backend on port 3001; Physio uses its own backend on port 3002.',
                  hintText: 'http://localhost:3001/api/v1',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailInput,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText:
                      '${module == Module.gym ? 'Gym' : 'Physio'} panel administrator email',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordInput,
                enabled: !busy,
                obscureText: hidden,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText:
                      '${module == Module.gym ? 'Gym' : 'Physio'} panel administrator password',
                  helperText:
                      'Configured separately in that backend’s .env file.',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Android emulator: http://10.0.2.2:${module == Module.gym ? 3001 : 3002}/api/v1\nWindows / browser on this computer: http://localhost:${module == Module.gym ? 3001 : 3002}/api/v1\nUSB Android: run adb reverse tcp:${module == Module.gym ? 3001 : 3002} tcp:${module == Module.gym ? 3001 : 3002}, then use http://127.0.0.1:${module == Module.gym ? 3001 : 3002}/api/v1\nWi-Fi phone: use your computer’s LAN IP; the selected backend must allow LAN connections.\nProduction: use that backend’s HTTPS API URL.',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 14),
              const Text(
                'Flutter Web also requires your web origin in backend CORS_ORIGIN. Gym web uses port 5501, Physio web uses 5502, and Super Admin uses 5503. A manager account is created in admins, not in the gym members table.',
              ),
              const SizedBox(height: 20),
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    message!,
                    style: TextStyle(color: failed ? Colors.red : Colors.green),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: busy ? null : () => check(save: false),
                    child: const Text('Test Connection'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => check(save: true),
                    child: const Text('Verify & Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Gym and Physio use separate panel credentials and short-lived JWT sessions. Passwords are never stored; each backend session is stored separately in secure storage.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
