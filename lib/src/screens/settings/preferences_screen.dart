import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:controller/src/controllers/settings/language_controller.dart';
import 'package:controller/src/controllers/settings/theme_controller.dart';
import 'package:controller/src/widgets/backround_blur.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:iconsax/iconsax.dart';

// Modelo para representar un idioma
class LanguageOption {
  final String code;
  final String name;

  LanguageOption(this.code, this.name);
}

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final languageController = Provider.of<LanguageController>(context);
    final localizations = AppLocalizations.of(context)!;

    // --- MEJORA: Lista de idiomas para evitar código hardcodeado ---
    final List<LanguageOption> languages = [
      LanguageOption('en', localizations.english),
      LanguageOption('es', localizations.spanish),
    ];

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
              // --- CORRECCIÓN 1: Usar clave de localización ---
              title: "Theme", // Asumiendo que tienes 'appearance' en tus .arb
              icon: Iconsax.moon,
              child: ListTile(
                title: Text(
                  localizations.darkMode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                trailing: Switch(
                  value: themeController.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    themeController.toggleTheme(value);
                  },
                  // --- CORRECCIÓN 2: Estilo moderno para el Switch ---
                  thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.white; // Color del pulgar cuando está activo
                    }
                    return Colors.grey.shade400; // Color del pulgar cuando está inactivo
                  }),
                  trackColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Theme.of(context).primaryColor; // Color de la pista cuando está activo
                    }
                    return Colors.grey.shade200; // Color de la pista cuando está inactivo
                  }),
                  trackOutlineColor: MaterialStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.transparent;
                    }
                    // Añade un borde sutil cuando está inactivo para mejor contraste
                    return Colors.grey.shade400;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tarjeta para los ajustes de Idioma
            _SettingsCard(
              title: localizations.language,
              icon: Iconsax.global,
              child: Column(
                // --- MEJORA 2: Generar la lista de idiomas dinámicamente ---
                children: List.generate(languages.length, (index) {
                  final lang = languages[index];
                  final isLast = index == languages.length - 1;

                  return _LanguageTile(
                    title: lang.name,
                    isSelected: languageController.currentLocale.languageCode == lang.code,
                    onTap: () => languageController.changeLanguage(lang.code),
                    isLast: isLast, // Pasar si es el último elemento
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS DE UI REUTILIZABLES (con mejoras) ---

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
          child, // Se elimina el Divider de aquí para dar más control al child
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLast; // Parámetro para saber si es el último

  const _LanguageTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
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
          // --- MEJORA 3: Lógica de borde simplificada ---
          shape: RoundedRectangleBorder(
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
          ),
        ),
      ],
    );
  }
}