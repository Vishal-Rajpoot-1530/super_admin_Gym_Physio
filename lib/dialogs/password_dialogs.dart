import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class PasswordDialog extends StatefulWidget {
  /// Optional: dikhane ke liye ki kis user ka password reset ho raha hai.
  final AppUser? user;

  const PasswordDialog({super.key, this.user});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();

    super.dispose();
  }

  // Validation pehle jaisi hi hai: minimum 4 characters.
  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }

    if (value.length < 4) {
      return 'Minimum 4 characters required';
    }

    return null;
  }

  void _resetPassword() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(context, _passwordController.text);
  }

  // ------------------------------------------------------------
  // Complexity meter (sirf visual guide, validation nahi badli)
  // ------------------------------------------------------------

  bool get _hasMin4 => _passwordController.text.length >= 4;
  bool get _hasMin8 => _passwordController.text.length >= 8;
  bool get _hasNumber => RegExp(r'\d').hasMatch(_passwordController.text);
  bool get _hasSymbol =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text);

  _Strength get _strength {
    final text = _passwordController.text;

    if (text.isEmpty) {
      return const _Strength('Awaiting input', 0.0, AppColors.muted);
    }

    if (!_hasMin4) {
      return const _Strength('Too short', 0.12, AppColors.danger);
    }

    final extra = [_hasMin8, _hasNumber, _hasSymbol].where((e) => e).length;

    switch (extra) {
      case 0:
        return const _Strength('Weak', 0.35, AppColors.warning);
      case 1:
        return const _Strength('Fair', 0.6, AppColors.accent);
      case 2:
        return const _Strength('Good', 0.8, AppColors.primary);
      default:
        return const _Strength('Strong', 1.0, AppColors.primaryDark);
    }
  }

  Widget _rule(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.circle_outlined,
            size: 15,
            color: ok ? AppColors.primary : AppColors.muted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: ok ? AppColors.primary : AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    final user = widget.user;

    return DialogFrame(
      icon: Icons.lock_reset,
      title: 'Reset User Password',
      subtitle: 'Issue new portal credentials',
      width: 480,
      onClose: () => Navigator.pop(context),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _resetPassword,
          icon: const Icon(Icons.verified_outlined, size: 20),
          label: const Text('Reset Password'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '(${user.email})',
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            const FieldLabel('New Password'),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter strong password...',
                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                suffixIcon: IconButton(
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
              validator: _passwordValidator,
              onChanged: (_) {
                setState(() {});
              },
              onFieldSubmitted: (_) {
                _resetPassword();
              },
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Eyebrow('Complexity meter')),
                      Text(
                        strength.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: strength.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: strength.value,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: strength.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _rule('Min 4 chars (required)', _hasMin4),
                      _rule('8+ chars', _hasMin8),
                      _rule('1 number', _hasNumber),
                      _rule('1 symbol', _hasSymbol),
                    ],
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

class _Strength {
  final String label;
  final double value;
  final Color color;

  const _Strength(this.label, this.value, this.color);
}
