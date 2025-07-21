import 'package:controller/routes/settings_routes.dart';
import 'package:controller/src/widgets/buttons/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:controller/src/controllers/auth/auth_controller.dart';
import 'package:controller/src/widgets/backround_blur.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _countryCodeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataUser();
      context.read<AuthController>().addListener(_loadDataUser);
    });
  }

  @override
  void dispose() {
    context.read<AuthController>().removeListener(_loadDataUser);
    _nameController.dispose();
    _countryCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadDataUser() {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (auth.userInfo != null) {
      _nameController.text = auth.userInfo!.name ?? '';
      _countryCodeController.text = (auth.userInfo!.countryCode ?? '').replaceAll('+', '');
      _phoneController.text = auth.userInfo!.phoneNumber ?? '';
    }
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final auth = context.read<AuthController>();

    try {
      final nameChanged = _nameController.text.trim() != auth.userInfo!.name;
      final phoneChanged = _countryCodeController.text.trim() != (auth.userInfo!.countryCode ?? '').replaceAll('+', '') ||
          _phoneController.text.trim() != auth.userInfo!.phoneNumber;

      if (nameChanged) {
        await auth.changeName(_nameController.text.trim(), context);
      }

      if (phoneChanged && _countryCodeController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
        if(mounted) {
          await auth.updatePhoneNumber(_countryCodeController.text.trim(), _phoneController.text.trim(), context);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final localizations = AppLocalizations.of(context)!;

    return BackgroundBlur(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizations.profile),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _ProfileCard(
                        nameController: _nameController,
                        countryCodeController: _countryCodeController,
                        phoneController: _phoneController,
                        email: auth.userInfo?.email ?? 'N/A',
                      ),
                      const SizedBox(height: 24),
                      _DeleteAccountButton(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          // --- SOLUCIÓN DEFINITIVA: Usamos RoundedButton que sí tiene `isLoading` ---
          child: RoundedButton(
            text: localizations.save,
            onPressed: _onSave,
            isLoading: _isSaving,
            padding: false, // El padding ya está en el widget padre
          ),
        ),
      ),
    );
  }
}

// --- El resto de los widgets se mantienen exactamente igual ---

class _ProfileCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController countryCodeController;
  final TextEditingController phoneController;
  final String email;

  const _ProfileCard({
    required this.nameController,
    required this.countryCodeController,
    required this.phoneController,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 45,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Icon(Iconsax.user, size: 40, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 20),
          _InfoField(
            label: localizations.name,
            controller: nameController,
            icon: Iconsax.user_edit,
            validator: (value) => (value == null || value.trim().isEmpty) ? localizations.enterUsernameValidation : null,
          ),
          const _Divider(),
          _PhoneField(
            countryCodeController: countryCodeController,
            phoneController: phoneController,
          ),
          const _Divider(),
          _InfoTile(
            label: localizations.email,
            value: email,
            icon: Iconsax.direct_inbox,
          ),
          const _Divider(),
          _InfoTile(
            label: localizations.password,
            value: '********',
            icon: Iconsax.key,
            trailing: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/account/change-password'),
              child: Text(localizations.changePassword),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?) validator;

  const _InfoField({required this.label, required this.controller, required this.icon, required this.validator});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        validator: validator,
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController countryCodeController;
  final TextEditingController phoneController;

  const _PhoneField({required this.countryCodeController, required this.phoneController});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Iconsax.call),
      title: Row(
        children: [
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: countryCodeController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Code', border: InputBorder.none, prefixText: '+'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.phoneNumber, border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;

  const _InfoTile({required this.label, required this.value, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      trailing: trailing,
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushNamed(SettingsRoutes.deleteAccount);
      },
      icon: Icon(Iconsax.trash, color: Colors.red.shade400, size: 20),
      label: Text(
        AppLocalizations.of(context)!.deleteAccount,
        style: TextStyle(fontSize: 16, color: Colors.red.shade400),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}