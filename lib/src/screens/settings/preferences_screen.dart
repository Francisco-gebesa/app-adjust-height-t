import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:controller/src/controllers/settings/language_controller.dart';
import 'package:controller/src/controllers/settings/theme_controller.dart';
import 'package:controller/src/widgets/backround_blur.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:iconsax/iconsax.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final languageController = Provider.of<LanguageController>(context);
    final localizations = AppLocalizations.of(context)!;

    return BackgroundBlur(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizations.preferencesButton),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Tarjeta para los ajustes de Apariencia
            _SettingsCard(
              // --- CORRECCIÓN AQUÍ ---
              // Usamos un texto fijo "Appearance" ya que la clave de localización no existía.
              // Puedes cambiarlo por la clave correcta que tengas, por ej: localizations.theme
              title: "Appearance",
              icon: Iconsax.moon,
              child: ListTile(
                title: Text(
                  localizations.darkMode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                trailing: Switch(
                  value: themeController.themeMode == ThemeMode.dark,
                  activeColor: Theme.of(context).primaryColor,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    themeController.toggleTheme(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tarjeta para los ajustes de Idioma
            _SettingsCard(
              title: localizations.language,
              icon: Iconsax.global,
              child: Column(
                children: [
                  _LanguageTile(
                    title: localizations.english,
                    isSelected: languageController.currentLocale.languageCode == 'en',
                    onTap: () => languageController.changeLanguage('en'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _LanguageTile(
                    title: localizations.spanish,
                    isSelected: languageController.currentLocale.languageCode == 'es',
                    onTap: () => languageController.changeLanguage('es'),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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

class _LanguageTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Iconsax.tick_circle, color: Theme.of(context).primaryColor)
          : null,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: title == AppLocalizations.of(context)!.spanish
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : BorderRadius.zero,
      ),
    );
  }
}