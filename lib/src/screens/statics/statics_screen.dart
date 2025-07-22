import 'package:controller/src/widgets/buttons/buttons.dart';
import 'package:flutter/material.dart';
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
    // Aseguramos que la carga de datos se inicie solo una vez cuando el widget se construye.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<StatisticsController>(context, listen: false);
      // Solo carga los datos si aún no existen.
      // Esto es útil gracias a `AutomaticKeepAliveClientMixin`
      if (provider.statistics == null) {
        provider.getStatistics(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              final provider = Provider.of<StatisticsController>(context, listen: false);
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            tabs: const [
              Tab(text: 'Hoy'),
              Tab(text: 'Semana'),
              Tab(text: 'Mes'),
              Tab(text: 'Año'),
            ],
          ),
        ),
        // Usamos Consumer para reconstruir el body según el estado del provider
        body: Consumer<StatisticsController>(
          builder: (context, provider, child) {
            // 1. Estado de carga inicial (no hay datos previos)
            if (provider.loading && provider.statistics == null) {
              return _LoadingStateView();
            }

            // 2. Estado vacío (sin datos de metas después de cargar)
            if (provider.withoutData && !provider.loading) {
              return _EmptyStateView(provider: provider);
            }

            // 3. Estado con datos (o recargando con datos previos)
            return RefreshIndicator(
              color: Theme.of(context).primaryColor,
              onRefresh: () => provider.getStatistics(context),
              child: _StatisticsListView(provider: provider),
            );
          },
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
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_ind_outlined,
              size: 60,
              color: Theme.of(context).primaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              localizations.noGoals,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.configureGoals,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
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

/// Widget que muestra el esqueleto de carga inicial para toda la pantalla.
class _LoadingStateView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(), // Deshabilita el scroll durante la carga
      padding: EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Shimmer para la tarjeta de calorías
          _ShimmerCard(height: 125),
          SizedBox(height: 20),
          // Shimmer para la fila de tarjetas de tiempo
          Row(
            children: [
              Expanded(child: _ShimmerCard(height: 155)),
              SizedBox(width: 16),
              Expanded(child: _ShimmerCard(height: 155)),
              SizedBox(width: 16),
              Expanded(child: _ShimmerCard(height: 155)),
            ],
          ),
          SizedBox(height: 20),
          // Shimmer para la tarjeta de metas
          _ShimmerCard(height: 200),
          SizedBox(height: 20),
          // Shimmer para la tarjeta de memorias
          _ShimmerCard(height: 180),
        ],
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
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            children: [
              // Estas tarjetas superiores ahora manejan el estado de carga internamente
              _CaloriesCard(provider: provider),
              const SizedBox(height: 20),
              _TimeCardsRow(provider: provider),
              const SizedBox(height: 20),

              // Condición segura para construir las tarjetas inferiores solo si existen los datos
              if (provider.statistics != null && provider.statistics!.result != null) ...[
                _GoalsCard(provider: provider),
                const SizedBox(height: 20),
                _MostUsedMemoriesCard(provider: provider),
              ] else if (provider.loading) ... [
                // Muestra shimmers si los datos aún no llegan (caso de recarga)
                _ShimmerCard(height: 200),
                const SizedBox(height: 20),
                _ShimmerCard(height: 180),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
    // isLoading es true si se está cargando y NO hay datos para mostrar
    final isLoading = provider.loading && provider.statistics == null;

    return _StatCard(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              radius: 35,
              child: Icon(
                Icons.local_fire_department_rounded,
                color: Theme.of(context).primaryColor,
                size: 35,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.caloriesBurned,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  isLoading
                      ? _ShimmerText(width: 120, height: 32)
                      : Text(
                    // Usamos el operador `??` para proveer un valor por defecto seguro
                    '${provider.statistics?.result?.caloriesBurned?.toStringAsFixed(1) ?? '0.0'} cal',
                    style: TextStyle(
                      fontSize: 32,
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
    final isLoading = provider.loading && provider.statistics == null;
    const gap = SizedBox(width: 16);

    return Row(
      children: [
        Expanded(
          child: _StatCardSmall(
            title: localizations.timeSitting,
            assetPath: 'assets/images/icons/sitting.png',
            value: provider.formatDuration(provider.statistics?.result?.timeSeatedInSeconds ?? 0),
            isLoading: isLoading,
          ),
        ),
        gap,
        Expanded(
          child: _StatCardSmall(
            title: localizations.timeRest,
            assetPath: 'assets/images/icons/rest.png',
            value: provider.formatDuration(provider.statistics?.result?.timeMidInSeconds ?? 0),
            isLoading: isLoading,
          ),
        ),
        gap,
        Expanded(
          child: _StatCardSmall(
            title: localizations.timeStanding,
            assetPath: 'assets/images/icons/stand_up.png',
            value: provider.formatDuration(provider.statistics?.result?.timeStandingInSeconds ?? 0),
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}

/// Widget refactorizado para las tarjetas pequeñas.
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
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Column(
          children: [
            Image.asset(
              assetPath,
              width: 32,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            isLoading
                ? _ShimmerText(width: 60, height: 20)
                : Text(
              value,
              style: TextStyle(
                fontSize: 20,
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
    // Es seguro usar '!' aquí porque este widget solo se construye si `statistics.result` no es nulo.
    final result = provider.statistics!.result!;

    return _StatCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 20, right: 16, top: 4, bottom: 4),
            title: Text(localizations.goals, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GoalsScreen())),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CircleStat(
                  assetPath: 'assets/images/icons/sitting.png',
                  label: localizations.timeSitting,
                  value: "${provider.formatDuration(result.timeSeatedInSeconds!)} / ${provider.formatDuration(result.iSittingTimeSecondsGoal!)}",
                ),
                _CircleStat(
                  assetPath: 'assets/images/icons/stand_up.png',
                  label: localizations.timeStanding,
                  value: "${provider.formatDuration(result.timeStandingInSeconds!)} / ${provider.formatDuration(result.iStandingTimeSecondsGoal!)}",
                ),
                _CircleStat(
                  iconData: FontAwesomeIcons.fire,
                  label: localizations.caloriesBurned,
                  value: "${result.caloriesBurned!.toStringAsFixed(1)} / ${result.iCaloriesToBurnGoal!.toStringAsFixed(1)}",
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
    // Es seguro usar '!' aquí también por la misma razón.
    final memories = provider.statistics!.result!.memoriMoreUse!.split(',');

    return _StatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 12),
            child: Text(
              AppLocalizations.of(context)!.mostUsedMemoryPosition,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: memories.map((e) {
                final Map<String, dynamic> memoryAssets = {
                  '1': {'asset': 'assets/images/icons/stand_up.png', 'text': AppLocalizations.of(context)!.standingMemory},
                  '2': {'asset': 'assets/images/icons/rest.png', 'text': AppLocalizations.of(context)!.restMemory},
                  '3': {'asset': 'assets/images/icons/sitting.png', 'text': AppLocalizations.of(context)!.sittingMemory},
                };
                return _CircleStat(
                  assetPath: memoryAssets[e]?['asset'] ?? 'assets/images/icons/rest.png', // Valor por defecto
                  label: "$e° ${memoryAssets[e]?['text'] ?? ''}",
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

  const _CircleStat({
    this.assetPath,
    this.iconData,
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).textTheme.bodyLarge!.color;
    const iconSize = 30.0;

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            radius: 35,
            child: assetPath != null
                ? Image.asset(assetPath!, width: iconSize, color: iconColor)
                : Icon(iconData, size: iconSize - 2, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (value != null) ...[
            const SizedBox(height: 6),
            Text(
              value!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
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

/// Widget de esqueleto para las tarjetas inferiores durante la carga.
class _ShimmerCard extends StatelessWidget {
  final double height;
  const _ShimmerCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}