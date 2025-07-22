import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:controller/src/screens/routines/create_routine_screen.dart';
import 'package:controller/src/widgets/toast_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:controller/src/controllers/desk/bluetooth_controller.dart';
import 'package:controller/src/controllers/desk/desk_controller.dart';
import 'package:controller/src/widgets/buttons/buttons.dart';
import 'package:controller/src/widgets/dialogs/dialog_confirm.dart';
import 'package:controller/src/widgets/dialogs/dialog_content.dart';
import 'package:open_settings_plus/core/open_settings_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../controllers/routines/routine_controller.dart';
import '../../controllers/settings/measurement_controller.dart';

enum ControlState { manual, sit1, sit2, standUp }

final GlobalKey menuKey = GlobalKey();

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
  List<TargetFocus> targets = [];

  bool disableControls = false;
  bool isDragging = false;

  // Add type parameters to make keys more specific
  final GlobalKey<State> heigthButtonsKey = GlobalKey<State>();
  final GlobalKey<State> setMemoryButtonKey = GlobalKey<State>();
  final GlobalKey<State> memoriesButtonsKey = GlobalKey<State>();
  final GlobalKey<State> routinesKey = GlobalKey<State>();
  final GlobalKey<State> specificHeightKey = GlobalKey<State>();

  // Make them final since they shouldn't change
  UniqueKey memoy1Key = UniqueKey();
  UniqueKey memoy2Key = UniqueKey();
  UniqueKey memoy3Key = UniqueKey();

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();

    context.read<DeskController>().listenToConnectionState(this, context);
    _loadPhysicalData();
  }

  //didChangeDependencies
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (targets.isNotEmpty) {
      return;
    }
    targets.add(TargetFocus(
        identify: "Target 1",
        keyTarget: heigthButtonsKey,
        contents: [
          TargetContent(
              align: ContentAlign.bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppLocalizations.of(context)!.heightControls,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      AppLocalizations.of(context)!.adjustHeightDescription,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                ],
              ))
        ]));

    targets.add(TargetFocus(
        identify: "Target 2",
        keyTarget: specificHeightKey,
        contents: [
          TargetContent(
              align: ContentAlign.top,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppLocalizations.of(context)!.totalControl,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      AppLocalizations.of(context)!.totalControlDescription,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                ],
              ))
        ]));

    targets.add(TargetFocus(
        identify: "Target 3",
        keyTarget: setMemoryButtonKey,
        contents: [
          TargetContent(
              align: ContentAlign.top,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppLocalizations.of(context)!.setMemoryPosition,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      AppLocalizations.of(context)!
                          .saveMemoryPositionDescription,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                ],
              ))
        ]));

    targets.add(TargetFocus(
        identify: "Target 4",
        keyTarget: memoriesButtonsKey,
        contents: [
          TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(top: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppLocalizations.of(context)!.memoryPositions,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 24.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      AppLocalizations.of(context)!.memoryPositionsDescription,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  )
                ],
              ))
        ]));

    //routines
    targets.add(
      TargetFocus(
        identify: "Target 5",
        keyTarget: routinesKey,
        paddingFocus: 0,
        contents: [
          TargetContent(
            customPosition: CustomTargetContentPosition(top: 70),
            align: ContentAlign.custom,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 3,
                radius: const Radius.circular(10),
                interactive: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Título de Rutinas
                      Text(
                        AppLocalizations.of(context)!.routinesTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 24.0,
                        ),
                      ),
                      // Descripción de Rutinas
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          AppLocalizations.of(context)!.routinesSteps,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      // Paso 1
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          AppLocalizations.of(context)!.step1Title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          AppLocalizations.of(context)!.step1Description,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      // Paso 2
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          AppLocalizations.of(context)!.step2Title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          AppLocalizations.of(context)!.step2Description,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      // Paso 3
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          AppLocalizations.of(context)!.step3Title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          AppLocalizations.of(context)!.step3Description,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      // Nota final
                      // Padding(
                      //   padding: const EdgeInsets.only(top: 20.0),
                      //   child: Text(
                      //     AppLocalizations.of(context)!.finalNote,
                      //     style: const TextStyle(
                      //       fontStyle: FontStyle.italic,
                      //       color: Colors.white,
                      //       fontSize: 16,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    //controlStatsSettings
    targets
        .add(TargetFocus(identify: "Target 6", keyTarget: menuKey, contents: [
      TargetContent(
          customPosition: CustomTargetContentPosition(top: 300),
          align: ContentAlign.custom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppLocalizations.of(context)!.controlStatsSettings,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 24.0),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  AppLocalizations.of(context)!.controlStatsSettingsDescription,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              )
            ],
          ))
    ]));
  }

  void showTutorial() {
    try {
      //future delay to show tutorial

      TutorialCoachMark(
        targets: targets, // List<TargetFocus>
        colorShadow: Theme.of(context).primaryColor,
        opacityShadow: .9,
        showSkipInLastTarget: true,
        alignSkip: Alignment.topRight,
        textSkip: AppLocalizations.of(context)!.skip,
        // alignSkip: Alignment.bottomRight,
        // textSkip: "SKIP",
        // paddingFocus: 10,
        // opacityShadow: 0.8,
        paddingFocus: 0,
        onClickTarget: (target) {
          print(target.identify);
        },
        onClickTargetWithTapPosition: (target, tapDetails) {
          // print("target: $target");
          // print(
          //     "clicked at position local: ${tapDetails.localPosition} - global: ${tapDetails.globalPosition}");
        },
        onClickOverlay: (target) {
          // print(target);
        },
        onSkip: () {
          print("skip");
          return true;
        },
        onFinish: () {
          print("finish");
        },
      ).show(context: context);

      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('newUser', false);
      });
    } catch (e) {
      SharedPreferences.getInstance().then((prefs) {
        if (prefs.getBool('newUser') ?? true) {
          prefs.setBool('newUser', true);
        } else {
          return;
        }
      });
    }
  }

  void _loadPhysicalData() async {
    var measurementController =
    Provider.of<MeasurementController>(context, listen: false);
    await measurementController.loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<DeskController>().connectionStateSubscription.cancel();
    context.read<RoutineController>().stopRoutine();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // La aplicación está en segundo plano
      _onPause();
    } else if (state == AppLifecycleState.resumed) {
      // La aplicación ha vuelto al primer plano
      _onResume();
    }
  }

  void _onPause() {
    // Código para manejar la pausa
    print("App en pausa");
  }

  void _onResume() {
    print("App reanudada");

    // Obtener instancia del DeskController
    var deskController = context.read<DeskController>();

    // Verificar si el dispositivo existe y está desconectado
    if (deskController.device != null &&
        deskController.connectionState != BluetoothConnectionState.connected) {
      // Intenta reconectar automáticamente
      deskController.reconnect();
      print("Intentando reconectar al dispositivo...");
    }

    // Verifica si hay rutina activa y cancela el timer si es necesario
    var routineController = context.read<RoutineController>();
    if (routineController.isActive) {
      routineController.checkAndCancelTimer();
    }
  }

  PageController pageController = PageController();
  // Define la posición inicial y final de la imagen superior
  ControlState controlState = ControlState.manual;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var screenSize = MediaQuery.of(context).size;
    var deskController = Provider.of<DeskController>(context);
    var bluetoothController = Provider.of<BluetoothController>(context);
    var measurementController = Provider.of<MeasurementController>(context);
    var routineController = Provider.of<RoutineController>(context);

    if (deskController.device != null && deskController.device!.isConnected) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        SharedPreferences.getInstance().then((prefs) {
          if (prefs.getBool('newUser') ?? true) {
            showTutorial();
          }
        });
      });
    }

    return AbsorbPointer(
      absorbing: disableControls,
      child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            surfaceTintColor: const Color.fromARGB(0, 43, 36, 36),
            leading: const SizedBox(),
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: Image.asset(
              'assets/images/brand/logo.png',
              height: 30,
            ),
            actions: deskController.device == null
                ? null
                : [
              //menu actions
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: ListTile(
                      title: Text(
                        AppLocalizations.of(context)!.changeName,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        HapticFeedback.lightImpact();
                        //open dialog to change name
                        showDialog(
                          context: context,
                          builder: (context) {
                            TextEditingController controller =
                            TextEditingController(
                                text: deskController.deviceName);

                            GlobalKey<FormState> key =
                            GlobalKey<FormState>();
                            return AlertDialog(
                              title: Text(AppLocalizations.of(context)!
                                  .changeName),
                              content: Form(
                                key: key,
                                child: TextFormField(
                                  controller: controller,
                                  maxLength: 20,
                                  validator: (value) {
                                    var regex =
                                    RegExp(r'^[a-zA-Z0-9 ]+$');

                                    if (value!.isEmpty) {
                                      return AppLocalizations.of(context)!
                                          .nameNotEmpty;
                                    }

                                    if (!regex.hasMatch(value)) {
                                      return AppLocalizations.of(context)!
                                          .invalidName;
                                    }

                                    //validate 20 characters
                                    if (value.length > 20) {
                                      return AppLocalizations.of(context)!
                                          .nameTooLong;
                                    }

                                    return null;
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                      AppLocalizations.of(context)!
                                          .cancel),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (key.currentState!.validate()) {
                                      deskController
                                          .changeName(controller.text);
                                      ToastService.showSuccess(context,
                                          '${AppLocalizations.of(context)!.nameChanged}: ${controller.text}');
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Text(
                                      AppLocalizations.of(context)!
                                          .confirm),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      title: const Text("Tutorial"),
                      onTap: () {
                        Navigator.pop(context);
                        HapticFeedback.lightImpact();
                        if (deskController.device != null &&
                            deskController.device!.isConnected) {
                          showTutorial();
                        } else {
                          ToastService.showInfo(context,
                              AppLocalizations.of(context)!.connectDesk);
                        }
                      },
                    ),
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      title:
                      Text(AppLocalizations.of(context)!.disconnect),
                      onTap: () {
                        Navigator.pop(context);
                        HapticFeedback.lightImpact();
                        showDialog(
                            context: context,
                            builder: (context) {
                              return DialogConfirm(
                                  icon: Icons.info,
                                  iconColor: Colors.red[100],
                                  title: AppLocalizations.of(context)!
                                      .disconnect,
                                  content:
                                  '${AppLocalizations.of(context)!.disconnectQ} ${deskController.deviceName!}?',
                                  confirmText:
                                  AppLocalizations.of(context)!
                                      .disconnect,
                                  cancelText:
                                  AppLocalizations.of(context)!
                                      .cancel,
                                  onConfirm: () {
                                    deskController.disconnect();
                                    Navigator.pushReplacementNamed(
                                        context, '/scan');
                                  },
                                  onCancel: () {});
                            });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          body: !deskController.deviceReady
              ? SizedBox(
            width: screenSize.width,
            height: screenSize.height * 0.8,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context)!.pairing,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Platform.isIOS
                    ? const CupertinoActivityIndicator()
                    : CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          )
              : deskController.device == null ||
              deskController.connectionState !=
                  BluetoothConnectionState.connected
              ? SizedBox(
            width: screenSize.width,
            height: screenSize.height * 0.8,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/desk/30.png', // Ajusta el nombre de archivo
                  width: screenSize.width * 0.7,
                  height: screenSize.width * 0.8,
                  fit: BoxFit.cover,
                  gaplessPlayback:
                  true, // Para evitar parpadeos al cambiar de imagen
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.notConnected,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'Airbnb',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.connectYourDesk,
                  style: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'Airbnb',
                      fontWeight: FontWeight.w100),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 150,
                  child: PrincipalButton(
                    text: AppLocalizations.of(context)!.connect,
                    onPressed: () {
                      bluetoothController.listenToAdapterState();
                      if (bluetoothController.adapterState !=
                          BluetoothAdapterState.on) {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return DialogConfirm(
                                icon: Icons.info,
                                iconColor: Colors.red[100],
                                title: AppLocalizations.of(context)!
                                    .bluetoothDisabled,
                                content: AppLocalizations.of(context)!
                                    .messageTurnOnBluetooth,
                                confirmText:
                                AppLocalizations.of(context)!
                                    .enableBluetooth2,
                                cancelText:
                                AppLocalizations.of(context)!
                                    .cancel,
                                onConfirm: () {
                                  try {
                                    if (Platform.isAndroid) {
                                      FlutterBluePlus.turnOn();
                                    } else {
                                      //open settings ios
                                      const OpenSettingsPlusIOS()
                                          .bluetooth();
                                    }
                                  } catch (e) {
                                    rethrow;
                                  }
                                },
                                onCancel: () {},
                              );
                            });
                      } else {
                        bluetoothController
                            .stopListeningToAdapterState();
                        deskController.setDevice(null);
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/scan', (route) => false);
                      }
                    },
                  ),
                ),
                const SizedBox(
                  height: 80,
                )
              ],
            ),
          )
              : LayoutBuilder(builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.12,
                  child: Center(
                    child: //richText
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding:
                          const EdgeInsets.only(left: 20, top: 0),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            crossAxisAlignment:
                            CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                child: AnimatedFlipCounter(
                                  fractionDigits: measurementController
                                      .currentMeasurement ==
                                      MeasurementUnit.metric
                                      ? 0
                                      : 1,
                                  curve: Curves.decelerate,
                                  textStyle: TextStyle(
                                    fontSize:
                                    constraints.maxHeight * 0.1,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: -10),
                                  duration: const Duration(
                                      milliseconds: 200),
                                  value: measurementController
                                      .currentMeasurement ==
                                      MeasurementUnit.metric
                                      ? deskController.mmToCm(
                                      deskController.heightMM)
                                      : deskController.mmToInches(
                                      deskController.heightMM),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 35, left: 5),
                                child: Text(
                                  measurementController
                                      .getHeightUnitString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: constraints.maxHeight * 0.5,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return const Dialog(
                                      child: SpecificHeightWidget());
                                });
                          },
                          onVerticalDragUpdate: (details) {
                            if (!isDragging) {
                              isDragging =
                              true; // Se marca el inicio del drag
                            }

                            if (details.primaryDelta! > 0) {
                              deskController
                                  .moveDown(); // Mueve el escritorio hacia abajo
                            } else {
                              deskController
                                  .moveUp(); // Mueve el escritorio hacia arriba
                            }
                          },
                          onVerticalDragEnd: (details) {
                            isDragging =
                            false; // Se detiene cuando termina el drag
                            deskController
                                .sendStopCommand(); // Detener el movimiento del escritorio
                          },
                          onPanUpdate: (details) {
                            if (isDragging) {
                              // Si se está arrastrando, continúa el movimiento
                              if (details.primaryDelta! > 0) {
                                deskController.moveDown();
                              } else {
                                deskController.moveUp();
                              }
                            }
                          },
                          child: Stack(
                            children: [
                              //top
                              AnimatedPositioned(
                                left: -screenSize.width * 0.4,
                                bottom: (1 -
                                    (deskController.progress /
                                        100)) *
                                    -screenSize.width *
                                    .29,
                                duration:
                                const Duration(milliseconds: 200),
                                child: Image.asset(
                                  'assets/images/desk/top.png', // Ajusta el nombre de archivo
                                  width: screenSize.width,
                                  height: screenSize.width,
                                  fit: BoxFit.cover,
                                  gaplessPlayback:
                                  true, // Para evitar parpadeos al cambiar de imagen
                                ),
                              ),
                              //mid
                              AnimatedPositioned(
                                key: specificHeightKey,
                                left: -screenSize.width * 0.4,
                                bottom: (1 -
                                    (deskController.progress /
                                        100)) *
                                    -screenSize.width *
                                    0.125,
                                duration:
                                const Duration(milliseconds: 200),
                                child: Image.asset(
                                  'assets/images/desk/mid.png', // Ajusta el nombre de archivo
                                  width: screenSize.width,
                                  height: screenSize.width,
                                  fit: BoxFit.cover,
                                  gaplessPlayback:
                                  true, // Para evitar parpadeos al cambiar de imagen
                                ),
                              ),
                              AnimatedPositioned(
                                left: -screenSize.width * 0.4,
                                bottom: 2,
                                duration:
                                const Duration(milliseconds: 15),
                                child: Image.asset(
                                  'assets/images/desk/bottom.png', // Ajusta el nombre de archivo
                                  width: screenSize.width,
                                  height: screenSize.width,
                                  fit: BoxFit.cover,
                                  gaplessPlayback:
                                  true, // Para evitar parpadeos al cambiar de imagen
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Column(
                            key: heigthButtonsKey,
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              SquareButton(
                                icon:
                                Icons.keyboard_arrow_up_outlined,
                                onTapDown: () async {
                                  deskController.moveUp();
                                  await Future.delayed(const Duration(
                                      milliseconds: 200));
                                },
                                onTapUp: () {
                                  deskController.moveDown();
                                },
                                onLongPress: () {
                                  disableControls = true;
                                  setState(() {});
                                  deskController.startUpTimer();
                                },
                                onLongPressEnd: (deta) async {
                                  disableControls = false;
                                  setState(() {});
                                  deskController.upTimer!.cancel();
                                  deskController.sendStopCommand();
                                },
                                onPressed: () {},
                              ),
                              SizedBox(
                                height: screenSize.height * 0.03,
                              ),
                              SquareButton(
                                icon: Icons
                                    .keyboard_arrow_down_outlined,
                                onTapDown: () async {
                                  deskController.moveDown();
                                  await Future.delayed(const Duration(
                                      milliseconds: 200));
                                },
                                onTapUp: () {
                                  deskController.moveUp();
                                },
                                onLongPress: () {
                                  disableControls = true;
                                  setState(() {});
                                  deskController.startDownTimer();
                                },
                                onLongPressEnd: (deta) async {
                                  disableControls = false;
                                  setState(() {});
                                  deskController.downTimer!.cancel();
                                  deskController.sendStopCommand();
                                },
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(
                  height: constraints.maxHeight * 0.19,
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          key: memoriesButtonsKey,
                          mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                          children: [
                            ControlSquareButton(
                              name: 'manual',
                              key: setMemoryButtonKey,
                              manual: true,
                              active: false,
                              memoryConfigured: false,
                              asset: 'assets/images/icons/1.svg',
                              onPressed: (val) async {
                                HapticFeedback.lightImpact();
                                await showDialog(
                                    context: context,
                                    builder: (context) {
                                      int selected = 0;
                                      return DialogContent(
                                          title: AppLocalizations.of(
                                              context)!
                                              .saveCurrentHeight,
                                          content:
                                          DialogSaveMemoryWidget(
                                              onSelected:
                                                  (value) {
                                                selected = value;
                                              }),
                                          confirmText:
                                          AppLocalizations.of(
                                              context)!
                                              .confirm,
                                          onConfirm: () {
                                            switch (selected) {
                                              case 1:
                                                deskController
                                                    .setupMemory1();
                                                memoy1Key =
                                                    UniqueKey();
                                                setState(() {});
                                                break;
                                              case 2:
                                                deskController
                                                    .setupMemory2();
                                                memoy2Key =
                                                    UniqueKey();
                                                setState(() {});
                                                break;
                                              case 3:
                                                deskController
                                                    .setupMemory3();
                                                memoy3Key =
                                                    UniqueKey();
                                                setState(() {});
                                                break;
                                              default:
                                            }
                                          },
                                          cancelText:
                                          AppLocalizations.of(
                                              context)!
                                              .cancel,
                                          onCancel: () {});
                                    });
                              },
                            ),
                            ControlSquareButton(
                                name: 'memory3',
                                key: memoy3Key,
                                asset:
                                'assets/images/icons/stand_up.png',
                                memoryConfigured:
                                deskController.memory3Configured,
                                active: controlState ==
                                    ControlState.standUp,
                                onPressed: (val) {
                                  HapticFeedback.lightImpact();
                                  deskController.moveMemory3();
                                  if (!val) {
                                    showDialog(
                                        context: context,
                                        builder: (context) {
                                          return DialogConfirm(
                                              icon: Icons.warning,
                                              iconColor:
                                              Colors.red[100],
                                              title:
                                              AppLocalizations.of(
                                                  context)!
                                                  .wait,
                                              content: AppLocalizations
                                                  .of(context)!
                                                  .memoryNotConfigured,
                                              confirmText:
                                              AppLocalizations.of(
                                                  context)!
                                                  .confirm,
                                              cancelText:
                                              AppLocalizations.of(
                                                  context)!
                                                  .cancel,
                                              onConfirm: () {},
                                              onCancel: () {});
                                        });
                                  }
                                }),
                            ControlSquareButton(
                                key: memoy2Key,
                                name: 'memory2',
                                asset: 'assets/images/icons/rest.png',
                                active:
                                controlState == ControlState.sit2,
                                memoryConfigured:
                                deskController.memory2Configured,
                                onPressed: (val) {
                                  HapticFeedback.lightImpact();
                                  deskController.moveMemory2();
                                  if (!val) {
                                    showDialog(
                                        context: context,
                                        builder: (context) {
                                          return DialogConfirm(
                                              icon: Icons.warning,
                                              iconColor:
                                              Colors.red[100],
                                              title:
                                              AppLocalizations.of(
                                                  context)!
                                                  .wait,
                                              content: AppLocalizations
                                                  .of(context)!
                                                  .memoryNotConfigured,
                                              confirmText:
                                              AppLocalizations.of(
                                                  context)!
                                                  .confirm,
                                              cancelText:
                                              AppLocalizations.of(
                                                  context)!
                                                  .cancel,
                                              onConfirm: () {},
                                              onCancel: () {});
                                        });
                                  }
                                }),
                            ControlSquareButton(
                              name: 'memory1',
                              key: memoy1Key,
                              asset:
                              'assets/images/icons/sitting.png',
                              active:
                              controlState == ControlState.sit1,
                              memoryConfigured:
                              deskController.memory1Configured,
                              onPressed: (val) {
                                HapticFeedback.lightImpact();
                                deskController.moveMemory1();
                                if (!val) {
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return DialogConfirm(
                                            icon: Icons.warning,
                                            iconColor:
                                            Colors.red[100],
                                            title:
                                            AppLocalizations.of(
                                                context)!
                                                .wait,
                                            content: AppLocalizations
                                                .of(context)!
                                                .memoryNotConfigured,
                                            confirmText:
                                            AppLocalizations
                                                .of(context)!
                                                .confirm,
                                            cancelText:
                                            AppLocalizations.of(
                                                context)!
                                                .cancel,
                                            onConfirm: () {},
                                            onCancel: () {});
                                      });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();

                                disableControls = true;
                                setState(() {});

                                if (routineController.isActive) {
                                  showDialog(
                                      useRootNavigator: false,
                                      context: context,
                                      builder: (context) {
                                        return DialogConfirm(
                                            icon: Icons.info,
                                            iconColor:
                                            Colors.red[100],
                                            title:
                                            AppLocalizations.of(
                                                context)!
                                                .stopRoutine,
                                            content: AppLocalizations
                                                .of(context)!
                                                .confirmStopRoutine,
                                            confirmText:
                                            AppLocalizations
                                                .of(context)!
                                                .stop,
                                            cancelText:
                                            AppLocalizations.of(
                                                context)!
                                                .cancel,
                                            onConfirm: () {
                                              routineController
                                                  .cancelRoutine(
                                                  context);
                                            },
                                            onCancel: () {});
                                      });
                                } else {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (context) {
                                      return const CreateRoutineModal();
                                    },
                                  );
                                }

                                disableControls = false;
                                setState(() {});
                              },
                              child: Container(
                                height: 50,
                                width: screenSize.width * 0.75,
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(100),
                                  border: Border.all(
                                    color: routineController.isActive
                                        ? Theme.of(context)
                                        .primaryColor
                                        : Theme.of(context)
                                        .navigationBarTheme
                                        .backgroundColor!,
                                    width: 1,
                                  ),
                                  color: Theme.of(context)
                                      .navigationBarTheme
                                      .backgroundColor,
                                ),
                                child: Center(
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                      ),
                                      if (routineController.isActive)
                                        Icon(
                                          Icons.stop,
                                          color: Theme.of(context)
                                              .primaryColor,
                                        ),
                                      Text(
                                        routineController.isActive
                                            ? AppLocalizations.of(
                                            context)!
                                            .stopRoutine
                                            : AppLocalizations.of(
                                            context)!
                                            .initRoutine,
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: routineController
                                                .isActive
                                                ? Theme.of(context)
                                                .primaryColor
                                                : null,
                                            fontWeight:
                                            FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      routineController.isActive
                                          ? Text(
                                          '${(routineController.totalSeconds ~/ 60).round()}m',
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Theme.of(
                                                  context)
                                                  .primaryColor,
                                              fontWeight:
                                              FontWeight
                                                  .bold))
                                          : Icon(
                                        Icons
                                            .double_arrow_sharp,
                                        color: Theme.of(context)
                                            .textTheme
                                            .displayLarge!
                                            .color,
                                        size: 18,
                                      ),
                                      const SizedBox(
                                        width: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              key: routinesKey,
                              right: 0,
                              child: const IgnorePointer(
                                ignoring: true,
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          })),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class SpecificHeightWidget extends StatefulWidget {
  const SpecificHeightWidget({
    super.key,
  });

  @override
  State<SpecificHeightWidget> createState() => _SpecificHeightWidgetState();
}

class _SpecificHeightWidgetState extends State<SpecificHeightWidget> {
  late double selectedHeight;
  late List<double> heightOptions;
  late int initialIndex;
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() {
    if (initialized) return;

    final deskController = Provider.of<DeskController>(context, listen: false);
    final measurementController =
    Provider.of<MeasurementController>(context, listen: false);

    // Initialize selected height with current height
    double currentHeight =
    measurementController.currentMeasurement == MeasurementUnit.metric
        ? deskController.mmToCm(deskController.heightMM)
        : deskController.mmToInches(deskController.heightMM);

    // Calculate min and max heights based on unit
    double minHeightConverted =
    measurementController.currentMeasurement == MeasurementUnit.metric
        ? deskController.mmToCm(deskController.minHeightMM)
        : deskController.mmToInches(deskController.minHeightMM);

    double maxHeightConverted =
    measurementController.currentMeasurement == MeasurementUnit.metric
        ? deskController.mmToCm(deskController.maxHeightMM)
        : deskController.mmToInches(deskController.maxHeightMM);

    //round to up min height
    minHeightConverted = minHeightConverted.ceilToDouble();

    //round to down max height
    maxHeightConverted = maxHeightConverted.floorToDouble();

    // Generate height options based on unit
    heightOptions = [];
    double step =
    measurementController.currentMeasurement == MeasurementUnit.metric
        ? 3.0
        : 1.0;

    for (double height = minHeightConverted;
    height <= maxHeightConverted;
    height += step) {
      heightOptions.add(height);
    }

    // Find the closest value to current height
    initialIndex = 0;
    double minDifference = double.infinity;
    for (int i = 0; i < heightOptions.length; i++) {
      double difference = (heightOptions[i] - currentHeight).abs();
      if (difference < minDifference) {
        minDifference = difference;
        initialIndex = i;
      }
    }

    // Initialize selectedHeight with the closest value
    selectedHeight = heightOptions[initialIndex];
    initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    // Solo escuchamos isStable del DeskController
    final deskController = Provider.of<DeskController>(context, listen: true);
    final measurementController =
    Provider.of<MeasurementController>(context, listen: false);

    _initializeValues();

    int decimals = 0;

    return SizedBox(
      width: 300,
      height: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.moveToHeight,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController:
              FixedExtentScrollController(initialItem: initialIndex),
              onSelectedItemChanged: (index) {
                selectedHeight = heightOptions[index];
              },
              children: heightOptions
                  .map((height) => Center(
                child: Text(
                  '${height.toStringAsFixed(decimals)} ${measurementController.currentMeasurement == MeasurementUnit.metric ? 'cm' : 'in'}',
                  style: const TextStyle(fontSize: 20),
                ),
              ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () {
                    print(selectedHeight);
                    num mm = measurementController.currentMeasurement ==
                        MeasurementUnit.metric
                        ? deskController.cmToMm(selectedHeight)
                        : deskController.inchesToMm(selectedHeight);

                    print(mm);

                    if (mm < deskController.minHeightMM ||
                        mm > deskController.maxHeightMM) {
                      print('fuera de rango');
                      Navigator.pop(context);
                      return;
                    }

                    var variante = (mm - deskController.heightMM).abs() <= 3;

                    if (mm == deskController.heightMM || variante) {
                      print('igual o muy cercano');
                      Navigator.pop(context);
                      return;
                    }

                    // Asegurar precisión en la conversión
                    int targetHeight;
                    if (measurementController.currentMeasurement ==
                        MeasurementUnit.metric) {
                      targetHeight = mm.round();
                    } else {
                      // Para pulgadas, simplemente convertimos directamente sin manipulación adicional
                      targetHeight =
                          (deskController.inchesToMm(selectedHeight)).ceil() +
                              3;
                    }

                    deskController.moveToHeight(targetHeight);
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context)!.confirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DialogSaveMemoryWidget extends StatefulWidget {
  final ValueChanged<int> onSelected;
  const DialogSaveMemoryWidget({
    super.key,
    required this.onSelected,
  });

  @override
  State<DialogSaveMemoryWidget> createState() => _DialogSaveMemoryWidgetState();
}

class _DialogSaveMemoryWidgetState extends State<DialogSaveMemoryWidget> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 10,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.only(left: 10),
              leading: Image.asset(
                width: 25,
                'assets/images/icons/stand_up.png',
                color: Theme.of(context).textTheme.displayLarge!.color,
              ),
              title: Text(AppLocalizations.of(context)!.standing),
              onTap: () {
                selected = 3;
                setState(() {});
                widget.onSelected(selected);
              },
              trailing: Radio(
                value: 3,
                groupValue: selected,
                onChanged: (value) {
                  selected = value as int;
                  widget.onSelected(selected);
                  setState(() {});
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.only(left: 10),
              leading: Image.asset(
                width: 25,
                'assets/images/icons/rest.png',
                color: Theme.of(context).textTheme.displayLarge!.color,
              ),
              title: Text(AppLocalizations.of(context)!.rest),
              onTap: () {
                selected = 2;
                setState(() {});
                widget.onSelected(selected);
              },
              trailing: Radio(
                value: 2,
                groupValue: selected,
                onChanged: (value) {
                  selected = value as int;
                  widget.onSelected(selected);
                  setState(() {});
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.only(left: 10),
              leading: Image.asset(
                width: 25,
                'assets/images/icons/sitting.png',
                color: Theme.of(context).textTheme.displayLarge!.color,
              ),
              title: Text(AppLocalizations.of(context)!.sitting),
              onTap: () {
                selected = 1;
                setState(() {});
                widget.onSelected(selected);
              },
              trailing: Radio(
                value: 1,
                groupValue: selected,
                onChanged: (value) {
                  selected = value as int;
                  setState(() {});
                  widget.onSelected(selected);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ControlSquareButton extends StatefulWidget {
  const ControlSquareButton({
    super.key,
    required this.name,
    required this.asset,
    this.manual = false,
    required this.onPressed,
    required this.active,
    required this.memoryConfigured,
  });

  final String asset;
  final bool manual;
  final Function(bool) onPressed;
  final bool active;
  final bool memoryConfigured;
  final String name;

  @override
  State<ControlSquareButton> createState() => _ControlSquareButtonState();
}

class _ControlSquareButtonState extends State<ControlSquareButton> {
  bool isConfigured = false;

  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      setState(() {
        prefs = value;
        isConfigured = (prefs!.getDouble(widget.name)) != null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;

    return SizedBox(
      width: screenSize.width * 0.15,
      height: screenSize.width * 0.15,
      child: Stack(
        children: [
          SizedBox(
            width: screenSize.width * 0.15,
            height: screenSize.width * 0.15,
            child: ElevatedButton(
              onPressed: () {
                widget.onPressed(isConfigured);
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                elevation: WidgetStateProperty.all(0),
                backgroundColor: widget.active
                    ? WidgetStateProperty.all(Theme.of(context).primaryColor)
                    : WidgetStateProperty.all(
                    Theme.of(context).navigationBarTheme.backgroundColor),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color:
                      Theme.of(context).iconTheme.color!.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
              ),
              child: widget.manual
                  ? Text(
                'M',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.displayLarge!.color,
                ),
              )
                  : Image.asset(
                widget.asset,
                width: screenSize.width * 0.07,
                fit: BoxFit.cover,
                color: widget.active
                    ? Colors.white
                    : Theme.of(context).iconTheme.color,
              ),
            ),
          ),
          if (widget.memoryConfigured) const AnimatedIconMemory(),
          if (!isConfigured && widget.name != 'manual')
            Positioned(
              top: 4,
              right: 3,
              child: Icon(
                Icons.info,
                color: Colors.red[100],
                size: 13,
              ),
            )
        ],
      ),
    );
  }
}

class AnimatedIconMemory extends StatefulWidget {
  const AnimatedIconMemory({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AnimatedIconMemoryState createState() => _AnimatedIconMemoryState();
}

class _AnimatedIconMemoryState extends State<AnimatedIconMemory>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    // var deskController = context.read<DeskController>();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Desaparecer el widget después de 2 segundos
    Future.delayed(const Duration(seconds: 1), () {
      _controller!.animateTo(0);
      // deskController.resetMemoryCofigured();
    });
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;

    return Padding(
        padding: const EdgeInsets.all(4.0),
        child: FadeIn(
          controller: (controller) => _controller = controller,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: screenSize.width * 0.15,
            height: screenSize.width * 0.15,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: Theme.of(context).iconTheme.color!.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ZoomIn(
              delay: const Duration(milliseconds: 100),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ));
  }
}

class SquareButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  final ValueChanged<LongPressEndDetails> onLongPressEnd;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const SquareButton(
      {super.key,
        required this.icon,
        required this.onPressed,
        required this.onLongPress,
        required this.onLongPressEnd,
        required this.onTapDown,
        required this.onTapUp});

  @override
  State<SquareButton> createState() => _SquareButtonState();
}

class _SquareButtonState extends State<SquareButton> {
  bool isPressed = false;
  bool isLongPressed = false;

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    return SizedBox(
      width: screenSize.width * 0.22,
      height: screenSize.width * 0.2,
      child: GestureDetector(
        onLongPress: () {
          widget.onLongPress();
          setState(() {
            isPressed = true;
            isLongPressed = true;
          });
        },
        onLongPressEnd: (details) {
          widget.onLongPressEnd(details);
          if (isLongPressed) {
            HapticFeedback.lightImpact();
          }
          setState(() {
            isPressed = false;
            isLongPressed = false;
          });
        },
        onTapDown: (details) {
          HapticFeedback.lightImpact();
          widget.onTapDown();
          setState(() {
            isPressed = true;
          });
        },
        onTapUp: (details) {
          HapticFeedback.lightImpact();
          widget.onTapUp();
          setState(() {
            isPressed = false;
          });
        },
        // onTap: widget.onPressed,
        child: ElevatedButton(
          onPressed: null,
          style: ButtonStyle(
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(
              isPressed
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).navigationBarTheme.backgroundColor,
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Theme.of(context).iconTheme.color!.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
          ),
          child: Icon(
            widget.icon,
            color: Theme.of(context).iconTheme.color,
            size: 30,
          ),
        ),
      ),
    );
  }
}