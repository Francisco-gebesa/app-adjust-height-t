import 'dart:convert';
import 'package:controller/src/api/goals_api.dart';
import 'package:controller/src/data/models/goals.dart';
import 'package:controller/src/widgets/backround_blur.dart';
import 'package:controller/src/widgets/buttons/buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../../api/error_handler.dart';
import '../../widgets/toast_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  // El estado se mantiene igual
  Duration timeSitting = const Duration(hours: 0);
  Duration timeStanding = const Duration(hours: 0);
  int _calories = 200;
  final int _minCalories = 50;
  final int _maxCalories = 1000;

  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchGoals();
  }

  // Las funciones de lógica de negocio se mantienen intactas
  Future<void> _fetchGoals() async {
    final response = await GoalsApi.getGoals();
    if (mounted && response['success']) {
      final goals = goalsFromJson(response['data']);
      if (goals.results != null) {
        setState(() {
          timeSitting = Duration(seconds: goals.results!.iSittingTimeSeconds!);
          timeStanding = Duration(seconds: goals.results!.iStandingTimeSeconds!);
          _calories = goals.results!.iCaloriesToBurn!;
        });
      }
    }
    if (mounted) {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _saveGoals() async {
    setState(() => _isLoading = true);

    if (timeSitting.inSeconds <= 0 || timeStanding.inSeconds <= 0 || _calories <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.error_outline, color: Colors.red[300], size: 40),
          title: Text(AppLocalizations.of(context)!.wait),
          content: Text(AppLocalizations.of(context)!.completeData),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.confirm),
            ),
          ],
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    final response = await GoalsApi.setGoals(
      timeSitting.inSeconds,
      timeStanding.inSeconds,
      _calories,
    );

    if (mounted) {
      if (response['success']) {
        ToastService.showSuccess(context, AppLocalizations.of(context)!.goalsSaved);
        Navigator.pop(context); // Opcional: cierra la pantalla al guardar con éxito
      } else {
        ToastService.showError(
          context,
          response['type'] != null
              ? ErrorHandler.getErrorMessage(response['type'], context)
              : json.decode(response['error'])['message'],
        );
      }
    }

    setState(() => _isLoading = false);
  }

  String _formatDuration(Duration duration) {
    if (!mounted) return "";
    final localizations = AppLocalizations.of(context)!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) return '$hours ${localizations.hours} $minutes ${localizations.minutes}';
    if (hours > 0) return '$hours ${localizations.hours}';
    return '$minutes ${localizations.minutes}';
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BackgroundBlur(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizations.goals),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isFetching
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
            : Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _GoalTimeCard(
                    assetPath: 'assets/images/icons/sitting.png',
                    title: localizations.timeSitQuestion,
                    subtitle: localizations.dataPerDay,
                    value: _formatDuration(timeSitting),
                    onTap: () => _showTimePicker(
                      initial: timeSitting,
                      onChanged: (newDuration) => setState(() => timeSitting = newDuration),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GoalTimeCard(
                    assetPath: 'assets/images/icons/stand_up.png',
                    title: localizations.timeStandQuestion,
                    subtitle: localizations.dataPerDay,
                    value: _formatDuration(timeStanding),
                    onTap: () => _showTimePicker(
                      initial: timeStanding,
                      onChanged: (newDuration) => setState(() => timeStanding = newDuration),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GoalCaloriesCard(
                    title: localizations.caloriesQuestion,
                    subtitle: localizations.dataPerDay,
                    calories: _calories,
                    onDecrement: () => setState(() => _calories = (_calories - 50).clamp(_minCalories, _maxCalories)),
                    onIncrement: () => setState(() => _calories = (_calories + 50).clamp(_minCalories, _maxCalories)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: RoundedButton(
                isLoading: _isLoading,
                onPressed: _saveGoals,
                text: localizations.saveGoals,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePicker({required Duration initial, required ValueChanged<Duration> onChanged}) {
    HapticFeedback.lightImpact();
    Duration tempDuration = initial;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            children: [
              // Fila con el botón de "Hecho"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        onChanged(tempDuration);
                        Navigator.pop(context);
                      },
                      child: Text(AppLocalizations.of(context)!.confirm),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTimerPicker(
                  initialTimerDuration: initial,
                  mode: CupertinoTimerPickerMode.hm,
                  onTimerDurationChanged: (duration) {
                    tempDuration = duration;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- WIDGETS DE UI REUTILIZABLES ---

/// Tarjeta base para un estilo consistente.
class _GoalCardBase extends StatelessWidget {
  final Widget child;
  const _GoalCardBase({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
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

/// Tarjeta reutilizable para seleccionar el tiempo.
class _GoalTimeCard extends StatelessWidget {
  final String assetPath;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const _GoalTimeCard({
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GoalCardBase(
        child: Row(
          children: [
            Image.asset(assetPath, width: 35, color: Theme.of(context).textTheme.bodyLarge!.color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta específica para ajustar las calorías.
class _GoalCaloriesCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int calories;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _GoalCaloriesCard({
    required this.title,
    required this.subtitle,
    required this.calories,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return _GoalCardBase(
      child: Row(
        children: [
          Icon(FontAwesomeIcons.fire, size: 30, color: Theme.of(context).textTheme.bodyLarge!.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Iconsax.minus), onPressed: onDecrement),
                Text('$calories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                IconButton(icon: const Icon(Iconsax.add), onPressed: onIncrement),
              ],
            ),
          )
        ],
      ),
    );
  }
}