import 'dart:async';
import 'dart:ui';
import 'package:controller/src/controllers/auth/auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:controller/src/controllers/desk/bluetooth_controller.dart';
import 'package:controller/src/screens/control/control_screen.dart';
import 'package:controller/src/screens/settings/settings_screen.dart';
import 'package:controller/src/widgets/backround_blur.dart';
import 'package:provider/provider.dart';
import '../../../routes/auth_routes.dart';
import '../../controllers/agent/agent_controller.dart';
import '../statics/statics_screen.dart';
import '../agent/chat_screen.dart';
import 'package:iconsax/iconsax.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  late StreamSubscription<User?> _authStateSubscription;
  PageController pageController = PageController();
  final GlobalKey menuKey = GlobalKey();

  changeIndex(int newIndex) {
    final bool isAgentAvailable =
        context.read<AgentController>().isAgentAvailable;
    final int maxIndex = isAgentAvailable ? 3 : 2;

    if (newIndex <= maxIndex) {
      // Ocultar el teclado antes de cambiar de pantalla
      FocusScope.of(context).unfocus();
      // Forzar el cierre del teclado del sistema
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      setState(() {
        index = newIndex;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<BluetoothController>().listenToAdapterState();
    _listenToAuthState();
    context.read<AuthController>().initializeNotifications(context);
    context.read<AgentController>().checkAgentAvailability();
  }

  void _listenToAuthState() {
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (user == null) {
            Navigator.of(context).pushReplacementNamed(AuthRoutes.welcome);
          }
        });
  }

  @override
  dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Verificamos si el teclado está visible obteniendo el espacio que ocupa en la parte inferior.
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return BackgroundBlur(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Stack(
          children: [
            PageView(
              onPageChanged: changeIndex,
              controller: pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                const ControlScreen(),
                const StatisticsScreen(),
                const SettingsScreen(),
                // Solo muestra la pantalla del agente si está disponible
                if (context.watch<AgentController>().isAgentAvailable)
                  const ChatScreen()
                else
                  const SizedBox(), // Pantalla vacía como placeholder
              ],
            ),
            // El Align ahora envuelve el widget de animación.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                // Usamos AnimatedOpacity para una transición de aparición/desaparición suave.
                child: AnimatedOpacity(
                  // Si el teclado está visible, la opacidad es 0 (totalmente transparente).
                  // Si el teclado está oculto, la opacidad es 1 (totalmente visible).
                  opacity: isKeyboardVisible ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  // IgnorePointer evita que el usuario pueda tocar la barra cuando está invisible.
                  child: IgnorePointer(
                    ignoring: isKeyboardVisible,
                    child: _buildCustomNavigationBar(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNavigationBar() {
    final bool isAgentAvailable =
        context.watch<AgentController>().isAgentAvailable;
    final int totalItems = isAgentAvailable ? 4 : 3;
    final double navBarWidth =
        MediaQuery.of(context).size.width * 0.8; // 80% del ancho de pantalla
    final double itemWidth = navBarWidth / totalItems;
    final double adjustedPosition = index * itemWidth;

    return ClipRRect(
      key: menuKey,
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Indicador que se mueve
            AnimatedPositioned(
              left: adjustedPosition,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _buildIndicatorBack(),
            ),
            Container(
                height: kBottomNavigationBarHeight,
                width: navBarWidth,
                decoration: BoxDecoration(
                  color: Theme.of(context).navigationBarTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                      color:
                      Theme.of(context).navigationBarTheme.backgroundColor!,
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildNavItem(Iconsax.home_2, 0)),
                    Expanded(child: _buildNavItem(Iconsax.chart_21, 1)),
                    Expanded(child: _buildNavItem(Iconsax.setting_2, 2)),
                    if (isAgentAvailable)
                      Expanded(child: _buildNavItem(Iconsax.message_text_1, 3)),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorBack() {
    final bool isAgentAvailable =
        context.watch<AgentController>().isAgentAvailable;
    final int totalItems = isAgentAvailable ? 4 : 3;
    final double navBarWidth = MediaQuery.of(context).size.width * 0.8;
    final double itemWidth = navBarWidth / totalItems;

    return Container(
      width: itemWidth,
      height: kBottomNavigationBarHeight,
      decoration: BoxDecoration(
        color: Colors.cyan,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int i) {
    final bool isSelected = index == i;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        pageController.jumpToPage(i);
      },
      child: Container(
        color: Colors.transparent,
        width: MediaQuery.of(context).size.width *
            0.8 /
            (context.watch<AgentController>().isAgentAvailable ? 4 : 3),
        height: kBottomNavigationBarHeight,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 25,
          color: isSelected
              ? Colors.white
              : Theme.of(context).textTheme.displayLarge!.color,
        ),
      ),
    );
  }
}