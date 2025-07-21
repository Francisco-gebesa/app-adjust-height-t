import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:controller/src/controllers/user/user_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/settings/measurement_controller.dart';
import '../../widgets/backround_blur.dart';
import '../../widgets/buttons/buttons.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DeskSettingsScreen extends StatefulWidget {
  const DeskSettingsScreen({super.key});

  @override
  State<DeskSettingsScreen> createState() => _DeskSettingsScreenState();
}

class _DeskSettingsScreenState extends State<DeskSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhysicalData();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _loadPhysicalData() async {
    final measurementController = context.read<MeasurementController>();
    await measurementController.loadPreferences();

    final prefs = await SharedPreferences.getInstance();
    final height = prefs.getDouble('height') ?? 0.0;
    final weight = prefs.getDouble('weight') ?? 0.0;

    if (mounted) {
      _heightController.text = height > 0 ? height.toStringAsFixed(2) : '';
      _weightController.text = weight > 0 ? weight.toStringAsFixed(2) : '';
      setState(() {});
    }
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userController = context.read<UserController>();
    final height = double.tryParse(_heightController.text) ?? 0.0;
    final weight = double.tryParse(_weightController.text) ?? 0.0;

    try {
      await userController.savePhysicalData(height, weight, context);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BackgroundBlur(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizations.physicalSettings),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _UnitSettingsCard(onTap: () {
                        Navigator.pushNamed(context, '/settings/measurements')
                            .then((_) => _loadPhysicalData());
                      }),
                      const SizedBox(height: 16),
                      _PhysicalDataCard(
                        heightController: _heightController,
                        weightController: _weightController,
                      ),
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
          child: RoundedButton(
            text: localizations.save,
            onPressed: _onSave,
            isLoading: _isLoading,
            padding: false,
          ),
        ),
      ),
    );
  }
}

// --- WIDGETS DE UI ---

class _BaseCard extends StatelessWidget {
  final Widget child;
  const _BaseCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

class _UnitSettingsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _UnitSettingsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _BaseCard(
        child: ListTile(
          leading: Icon(Iconsax.convert_3d_cube, color: Theme.of(context).primaryColor),
          title: Text(
            AppLocalizations.of(context)!.changeMeasure,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(Iconsax.arrow_right_3, size: 18),
        ),
      ),
    );
  }
}

class _PhysicalDataCard extends StatelessWidget {
  final TextEditingController heightController;
  final TextEditingController weightController;

  const _PhysicalDataCard({
    required this.heightController,
    required this.weightController,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MeasurementController>(
      builder: (context, measurementController, child) {
        return _BaseCard(
          child: Column(
            children: [
              _DataInputTile(
                icon: Iconsax.ruler,
                label: AppLocalizations.of(context)!.myHeight,
                controller: heightController,
                unit: measurementController.getHeightUnitString(),
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == 0) {
                    return AppLocalizations.of(context)!.enterHeight;
                  }
                  return null;
                },
              ),
              const Divider(height: 1, indent: 56, endIndent: 16), // Se ajusta el indent para alinear con el texto
              _DataInputTile(
                icon: Iconsax.weight,
                label: AppLocalizations.of(context)!.myWeight,
                controller: weightController,
                unit: measurementController.getWeightUnitString(),
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == 0) {
                    return AppLocalizations.of(context)!.enterWeight;
                  }
                  return null;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DataInputTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String unit;
  final String? Function(String?)? validator;

  const _DataInputTile({
    required this.icon,
    required this.label,
    required this.controller,
    required this.unit,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // --- CAMBIO AQUÍ PARA EL FONDO TRANSPARENTE ---
        decoration: InputDecoration(
          labelText: label,
          // Se quitan todos los bordes y el fondo
          border: InputBorder.none,
          filled: false,
          // Se ajusta el padding para que no se sienta apretado
          contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
        ),
      ),
      trailing: Text(
        unit,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}