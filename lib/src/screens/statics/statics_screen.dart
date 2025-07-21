import 'package:controller/src/widgets/buttons/buttons.dart';
import 'package:flutter/material.dart';
// Mantenemos FontAwesome solo porque estaba en tu archivo original.
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';
import '../../controllers/statistics/statistics_controller.dart';
import '../goals/goal_screen.dart';

// --- PANTALLA PRINCIPAL REDISEÑADA ---
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StatisticsController>(context, listen: false)
          .getStatistics(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var provider = Provider.of<StatisticsController>(context);
    final localizations = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizations.statistics),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            onTap: (val) {
              final filters = ['Today', 'Week', 'Month', 'Year'];
              provider.setDateFilter(filters[val]);
              provider.getStatistics(context);
            },
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3.0,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 16),
            tabs: const [
              Tab(text: 'Today'),
              Tab(text: 'Week'),
              Tab(text: 'Month'),
              Tab(text: 'Year'),
            ],
          ),
        ),
        body: provider.withoutData && !provider.loading
            ? _EmptyStateView(provider: provider)
            : RefreshIndicator(
          color: Theme.of(context).primaryColor,
          onRefresh: () => provider.getStatistics(context),
          child: _StatisticsListView(provider: provider),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}


// --- WIDGETS DE LA UI (REFACTORIZADOS Y NUEVOS) ---

/// Vista que se muestra cuando no hay metas configuradas.
class _EmptyStateView extends StatelessWidget {
  final StatisticsController provider;
  const _EmptyStateView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_late_outlined, // Icono más neutral
              size: 60,
              color: Theme.of(context).primaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 20),
            Text(
              localizations.noGoals,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              localizations.configureGoals,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            PrincipalButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GoalsScreen()),
                ).then((_) => provider.getStatistics(context));
              },
              text: localizations.configureGoalsButton,
            ),
          ],
        ),
      ),
    );
  }
}

/// El contenido principal de la pantalla con la lista de estadísticas.
class _StatisticsListView extends StatelessWidget {
  final StatisticsController provider;
  const _StatisticsListView({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Usamos un LayoutBuilder para asegurar que el SingleChildScrollView ocupe el espacio disponible
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            children: [
              _CaloriesCard(provider: provider),
              const SizedBox(height: 16),
              _TimeCardsRow(provider: provider),
              const SizedBox(height: 16),
              if (provider.statistics != null) ...[
                _GoalsCard(provider: provider),
                const SizedBox(height: 16),
                _MostUsedMemoriesCard(provider: provider),
              ],
              const SizedBox(height: 90),
            ],
          ),
        ),
      );
    });
  }
}

/// Tarjeta base reutilizable para un estilo consistente.
class _StatCard extends StatelessWidget {
  final Widget child;
  const _StatCard({required this.child});

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

/// Tarjeta grande para las calorías.
class _CaloriesCard extends StatelessWidget {
  final StatisticsController provider;
  const _CaloriesCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _StatCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              radius: 35,
              child: Icon(
                Icons.fireplace_rounded, // Icono original
                color: Theme.of(context).primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.caloriesBurned,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  provider.loading
                      ? _ShimmerText(width: 120, height: 28)
                      : Text(
                    '${provider.statistics!.result!.caloriesBurned!.toStringAsFixed(1)} cal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
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

/// Fila que contiene las 3 tarjetas de tiempo.
class _TimeCardsRow extends StatelessWidget {
  final StatisticsController provider;
  const _TimeCardsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _StatCardSmall(
            title: localizations.timeSitting,
            assetPath: 'assets/images/icons/sitting.png', // Icono original
            value: provider.formatDuration(provider.statistics?.result?.timeSeatedInSeconds ?? 0),
            isLoading: provider.loading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCardSmall(
            title: localizations.timeRest,
            assetPath: 'assets/images/icons/rest.png', // Icono original
            value: provider.formatDuration(provider.statistics?.result?.timeMidInSeconds ?? 0),
            isLoading: provider.loading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCardSmall(
            title: localizations.timeStanding,
            assetPath: 'assets/images/icons/stand_up.png', // Icono original
            value: provider.formatDuration(provider.statistics?.result?.timeStandingInSeconds ?? 0),
            isLoading: provider.loading,
          ),
        ),
      ],
    );
  }
}

/// Widget refactorizado que reemplaza a SitTimeWidget, StandUpTimeWidget, etc.
class _StatCardSmall extends StatelessWidget {
  final String title;
  final String assetPath;
  final String value;
  final bool isLoading;

  const _StatCardSmall({
    required this.title,
    required this.assetPath,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            Image.asset(
              assetPath, // Usando el icono original
              width: 30,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            isLoading
                ? _ShimmerText(width: 50, height: 18)
                : Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta para las metas (Goals).
class _GoalsCard extends StatelessWidget {
  final StatisticsController provider;
  const _GoalsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _StatCard(
      child: Column(
        children: [
          ListTile(
            title: Text(localizations.goals, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalsScreen())),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CircleStat(
                  assetPath: 'assets/images/icons/sitting.png', // Icono original
                  label: localizations.timeSitting,
                  value: "${provider.formatDuration(provider.statistics!.result!.timeSeatedInSeconds!)} / ${provider.formatDuration(provider.statistics!.result!.iSittingTimeSecondsGoal!)}",
                  isLoading: provider.loading,
                ),
                _CircleStat(
                  assetPath: 'assets/images/icons/stand_up.png', // Icono original
                  label: localizations.timeStanding,
                  value: "${provider.formatDuration(provider.statistics!.result!.timeStandingInSeconds!)} / ${provider.formatDuration(provider.statistics!.result!.iStandingTimeSecondsGoal!)}",
                  isLoading: provider.loading,
                ),
                _CircleStat(
                  iconData: FontAwesomeIcons.fire, // Icono original
                  label: localizations.caloriesBurned,
                  value: "${provider.statistics!.result!.caloriesBurned!.toStringAsFixed(1)} / ${provider.statistics!.result!.iCaloriesToBurnGoal!.toStringAsFixed(1)}",
                  isLoading: provider.loading,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// Tarjeta para las memorias más usadas.
class _MostUsedMemoriesCard extends StatelessWidget {
  final StatisticsController provider;
  const _MostUsedMemoriesCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final memories = provider.statistics!.result!.memoriMoreUse!.split(',');
    return _StatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              AppLocalizations.of(context)!.mostUsedMemoryPosition,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: memories.map((e) {
                final Map<String, dynamic> memoryAssets = {
                  '1': {'asset': 'assets/images/icons/stand_up.png', 'text': AppLocalizations.of(context)!.standingMemory},
                  '2': {'asset': 'assets/images/icons/rest.png', 'text': AppLocalizations.of(context)!.restMemory},
                  '3': {'asset': 'assets/images/icons/sitting.png', 'text': AppLocalizations.of(context)!.sittingMemory},
                };
                return _CircleStat(
                  assetPath: memoryAssets[e]!['asset'],
                  label: "$e° ${memoryAssets[e]!['text']}",
                  isLoading: provider.loading,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget reutilizable para el ícono circular con texto debajo.
class _CircleStat extends StatelessWidget {
  final String? assetPath;
  final IconData? iconData;
  final String label;
  final String? value;
  final bool isLoading;

  const _CircleStat({
    this.assetPath,
    this.iconData,
    required this.label,
    this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            radius: 35,
            child: assetPath != null
                ? Image.asset(assetPath!, width: 30, color: Theme.of(context).textTheme.bodyLarge!.color)
                : Icon(iconData, size: 28, color: Theme.of(context).textTheme.bodyLarge!.color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if (value != null) ...[
            const SizedBox(height: 4),
            isLoading
                ? _ShimmerText(width: 80, height: 14)
                : Text(
              value!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ]
        ],
      ),
    );
  }
}

/// Widget para el efecto de carga shimmer.
class _ShimmerText extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerText({this.width = 60, this.height = 16});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}