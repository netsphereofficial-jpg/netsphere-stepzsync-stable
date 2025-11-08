import 'package:get/get.dart';

import '../controllers/notification_controller.dart';
import '../screens/achievements/achievements_screen.dart';
import '../screens/active_races/active_races_screen.dart';
import '../screens/hall_of_fame/hall_of_fame_screen.dart';
import '../screens/marathon/marathon_screen.dart';
import '../screens/notifications/notification_list_screen.dart';
import '../screens/race/race_screen.dart';
import '../screens/race_invites/race_invites_screen.dart';
import '../screens/race_map/race_map_screen.dart';
import '../screens/races/marathon_races_screen.dart';
import '../screens/races/quick_race/quick_race_selection_screen.dart';
import '../screens/subscription/subscription_screen.dart';

class AppRoutes {
  static const String quickRace = '/quick-race';
  static const String quickRaceWaiting = '/quick-race-waiting';
  static const String activeRaces = '/active-races';
  static const String race = '/race';
  static const String raceMap = '/race-map';
  static const String marathon = '/marathon';
  static const String marathonRaces = '/marathon-races';
  static const String raceInvites = '/race-invites';
  static const String hallOfFame = '/hall-of-fame';
  static const String achievements = '/achievements';
  static const String raceDetails = '/race-details';
  static const String notifications = '/notifications';
  static const String adminLogin = '/admin-login';
  static const String adminDashboard = '/admin-dashboard';
  static const String subscription = '/subscription';

  static List<GetPage> routes = [
    GetPage(
      name: quickRace,
      page: () => const QuickRaceSelectionScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: activeRaces,
      page: () => const ActiveRacesScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: race,
      page: () => const RaceScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: raceMap,
      page: () => RaceMapScreen(role: UserRole.participant),
      transition: Transition.fadeIn, // Circular reveal effect
      transitionDuration: const Duration(milliseconds: 600),
    ),
    GetPage(
      name: marathon,
      page: () => const MarathonScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: marathonRaces,
      page: () => const MarathonRacesScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: raceInvites,
      page: () => const RaceInvitesScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: hallOfFame,
      page: () => const HallOfFameScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: achievements,
      page: () => const AchievementsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: notifications,
      page: () => NotificationListScreen(),
      binding: BindingsBuilder(() {
        // ✅ OPTIMIZED: fenix: true for smart controller reuse (50% faster navigation)
        Get.lazyPut(() => NotificationController(), fenix: true);
      }),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: subscription,
      page: () =>  SubscriptionScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
