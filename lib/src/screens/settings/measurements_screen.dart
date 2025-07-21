import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:controller/src/widgets/backround_blur.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/settings/measurement_controller.dart';

class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final measurementController = Provider.of<MeasurementController>(context);
    final localizations = AppLocalizations.of(context)!;

    return BackgroundBlur(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizations.unitOfMeasure),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _SettingsCard(
              // --- CORRECCIÓN 1: Usamos la clave de localización correcta ---
              title: localizations.unitOfMeasure,
              // --- CORRECCIÓN 2: Usamos el nombre de icono correcto ---
              icon: Iconsax.ruler,
              child: Column(
                children: [
                  _UnitSelectionTile(
                    title: localizations.metric,
                    subtitle: localizations.metricUnits,
                    isSelected: measurementController.currentMeasurement == MeasurementUnit.metric,
                    onTap: () => measurementController.setUnit(MeasurementUnit.metric),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _UnitSelectionTile(
                    title: localizations.imperial,
                    subtitle: localizations.imperialUnits,
                    isSelected: measurementController.currentMeasurement == MeasurementUnit.imperial,
                    onTap: () => measurementController.setUnit(MeasurementUnit.imperial),
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

// --- WIDGETS DE UI REUTILIZABLES ---

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _UnitSelectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitSelectionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
        ),
      ),
      trailing: isSelected
          ? Icon(Iconsax.tick_circle, color: Theme.of(context).primaryColor, size: 24)
      // --- CORRECCIÓN 3 y 4: Nombre de icono correcto y se quita el `const` ---
          : const Icon(Iconsax.radio, size: 24),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: title == AppLocalizations.of(context)!.imperial
              ? const Radius.circular(20)
              : Radius.zero,
        ),
      ),
    );
  }
}