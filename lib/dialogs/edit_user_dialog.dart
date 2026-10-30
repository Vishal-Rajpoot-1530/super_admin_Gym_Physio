import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/common.dart';

class EditUserDialog extends StatefulWidget {
  final AppUser user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  late String _type;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.user.name);

    _emailController = TextEditingController(text: widget.user.email);

    _phoneController = TextEditingController(text: widget.user.phone);

    _type = widget.user.module==Module.gym?'online':widget.user.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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

    if (!value.contains('@')) {
      return 'Enter a valid email';
    }

    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ApiService.updateUser(
        widget.user.module,
        widget.user.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        type: _type,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));

      setState(() {
        _saving = false;
      });
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DialogFrame(
      icon: Icons.edit_outlined,
      title: 'Edit User',
      subtitle: 'Profile & contact info',
      width: 460,
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
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              label: 'Name',
              controller: _nameController,
              validator: _requiredValidator,
            ),
            _field(
              label: 'Email',
              controller: _emailController,
              validator: _emailValidator,
              keyboardType: TextInputType.emailAddress,
            ),
            _field(
              label: 'Mobile Number',
              controller: _phoneController,
              validator: _requiredValidator,
              keyboardType: TextInputType.phone,
            ),

            const FieldLabel('User Type'),
            DropdownButtonFormField<String>(
              value: _type,
              items: [
                if(widget.user.module!=Module.gym) const DropdownMenuItem(value:'offline',child:Text('Offline')),
                const DropdownMenuItem(value:'online',child:Text('Online')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _type = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
