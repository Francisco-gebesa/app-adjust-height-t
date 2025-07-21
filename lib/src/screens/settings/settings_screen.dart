import 'package:controller/src/widgets/buttons/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:controller/src/controllers/desk/desk_controller.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconsax/iconsax.dart'; // Importamos la librería correcta
import '../../controllers/auth/auth_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localizations.settings),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const _AccountCard(),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            children: [
              _SettingsTile(
                icon: Iconsax.setting_2,
                title: localizations.preferencesButton,
                onTap: () => Navigator.pushNamed(context, '/settings/preferences'),
              ),
              _SettingsTile(
                icon: Iconsax.weight_1, // Icono para "Físico"
                title: localizations.physicalSettings,
                onTap: () => Navigator.pushNamed(context, '/settings/deskSettings'),
              ),
              _SettingsTile(
                icon: Iconsax.rulerpen, // Icono para "Unidades"
                title: localizations.unitOfMeasure,
                onTap: () => Navigator.pushNamed(context, '/settings/measurements'),
              ),
              _SettingsTile(
                icon: Iconsax.notification_bing, // Icono para "Recordatorios"
                title: localizations.healthyReminders,
                onTap: () => Navigator.pushNamed(context, '/settings/reminders'),
                hasDivider: false, // El último no necesita divisor
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            children: [
              _SettingsTile(
                icon: Iconsax.info_circle,
                title: 'About',
                onTap: () async {
                  final url = Uri.parse("https://www.gebesa.com/");
                  if (await canLaunchUrl(url)) {
                    launchUrl(url);
                  }
                },
              ),
              _SettingsTile(
                icon: Iconsax.logout,
                title: 'Sign out',
                onTap: () {
                  final authController = Provider.of<AuthController>(context, listen: false);
                  final deskController = Provider.of<DeskController>(context, listen: false);
                  authController.logout();
                  deskController.disconnect();
                },
                textColor: Colors.red.shade400, // Color distintivo para la acción
                hasDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            'Version 1.0.0', // Puedes hacerlo dinámico si usas `package_info_plus`
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.withOpacity(0.5)),
          ),
          const SizedBox(height: 90), // Espacio para la barra de navegación
        ],
      ),
    );
  }
}

// --- WIDGETS DE UI REUTILIZABLES ---

/// La tarjeta base para cada sección de ajustes.
class _SettingsSectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsSectionCard({required this.children});

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
      child: Column(children: children),
    );
  }
}

/// La tarjeta de perfil de usuario.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final userInfo = authController.userInfo;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/settings/account'),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Iconsax.user, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userInfo?.name ?? 'Guest',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userInfo?.email ?? 'No email',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

/// Una fila reutilizable para cada opción de la lista.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;
  final bool hasDivider;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
    this.hasDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: textColor ?? Theme.of(context).iconTheme.color),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          trailing: Icon(
            Iconsax.arrow_right_3,
            size: 18,
            color: textColor ?? Colors.grey[400],
          ),
        ),
        if (hasDivider)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}