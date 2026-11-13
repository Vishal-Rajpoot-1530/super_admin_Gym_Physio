import 'dart:convert';

import 'package:flutter/material.dart';

import '../pages/api_connection_page.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class CreateUserDialog extends StatefulWidget {
  final Module module;

  const CreateUserDialog({super.key, required this.module});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _type = 'offline';

  Plan _selectedPlan = Plan.quarterly;

  bool _saving = false;
  AppUser? _createdClinicUser;
  String? _error;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.module == Module.gym) {
      _type = 'online';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Enter a valid email';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 4) {
      return 'Minimum 4 characters required';
    }

    if (widget.module == Module.gym && utf8.encode(value).length > 72) {
      return 'Maximum 72 UTF-8 bytes allowed';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final type = _type;
    final plan = _selectedPlan;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user =
          _createdClinicUser ??
          await ApiService.signUp(
            module: widget.module,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            phone: _phoneController.text.trim(),
            type: type,
            plan: plan,
          );
      // Gym creation now includes subscription in ONE server transaction.
      // Keep the clinic contract unchanged; retry its second step without recreating its account.
      if (widget.module == Module.clinic) {
        _createdClinicUser = user;
        if (type == 'online') {
          await ApiService.assignPlan(widget.module, user.id, plan);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '${_createdClinicUser != null ? 'Account already exists. Subscription setup failed; retry to assign the plan only. ' : ''}$e',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signInAndRetry() async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ApiConnectionPage(initialModule: widget.module),
      ),
    );
    if (signedIn == true && mounted) await _submit();
  }

  String get _moduleLabel {
    if (widget.module == Module.clinic) {
      return 'Physio Clinic';
    }

    return 'Gym Management';
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          TextFormField(
            controller: controller,
            enabled: !_saving && _createdClinicUser == null,
            keyboardType: keyboardType,
            obscureText: obscure,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
            validator: validator,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: DialogFrame(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Create User',
        subtitle: 'Add a new account to $_moduleLabel',
        width: 480,
        onClose: _saving ? null : () => Navigator.pop(context),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    Navigator.pop(context);
                  },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      if (widget.module == Module.gym &&
                          (_error!.contains('not signed in') ||
                              _error!.contains('sign in again')))
                        TextButton.icon(
                          onPressed: _saving ? null : _signInAndRetry,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in and retry'),
                        ),
                    ],
                  ),
                ),
              _field(
                label: 'Name',
                controller: _nameController,
                validator: _requiredValidator,
                hint: 'Full name',
              ),
              _field(
                label: 'Email',
                controller: _emailController,
                validator: _emailValidator,
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              _field(
                label: 'Password',
                controller: _passwordController,
                validator: _passwordValidator,
                hint: 'Enter password',
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              _field(
                label: 'Mobile Number',
                controller: _phoneController,
                validator: _requiredValidator,
                hint: '+91 00000 00000',
                keyboardType: TextInputType.phone,
              ),

              const FieldLabel('User Type'),
              DropdownButtonFormField<String>(
                value: _type,
                items: widget.module == Module.gym
                    ? const [
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('Online'),
                        ),
                      ]
                    : const [
                        DropdownMenuItem(
                          value: 'offline',
                          child: Text('Offline'),
                        ),
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('Online'),
                        ),
                      ],
                onChanged: _saving || _createdClinicUser != null
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _type = value;
                        });
                      },
              ),

              // Plan is shown only for ONLINE user.
              if (_type == 'online') ...[
                const SizedBox(height: 22),
                const FieldLabel('Select Subscription Plan', required: false),
                ...Plan.purchaseOptions.map((plan) {
                  return PlanOption(
                    plan: plan,
                    selected: _selectedPlan == plan,
                    onTap: () {
                      if (_saving) return;
                      setState(() {
                        _selectedPlan = plan;
                      });
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
