import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';
import 'package:dalal_alqaim/pages/profile_page.dart';
import 'package:dalal_alqaim/features/vacancies/presentation/pages/vacancies_page.dart';
import 'package:dalal_alqaim/pages/complaints_page.dart';
import 'package:dalal_alqaim/main.dart'; // For AuthWrapper
import 'package:dalal_alqaim/pages/welcome_page.dart';
import 'package:dalal_alqaim/pages/my_orders_page.dart';

// Service Pages Imports
import 'package:dalal_alqaim/features/taxi/presentation/taxi_request_screen.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurants_page.dart';
import 'package:dalal_alqaim/pages/all_sections_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/madar_stores_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/user_points_page.dart';
import 'package:dalal_alqaim/pages/cart_page.dart';
import 'package:dalal_alqaim/pages/real_estate_page.dart';
import 'package:dalal_alqaim/features/home/pages/settings_page.dart';
import 'package:dalal_alqaim/features/home/pages/search_page.dart';
import 'package:dalal_alqaim/features/home/pages/favorites_page.dart';
import 'package:dalal_alqaim/pages/notifications_page.dart';
import 'package:dalal_alqaim/pages/emergency_services_page.dart';
import 'package:dalal_alqaim/pages/technical_support_chat_page.dart';
import 'package:dalal_alqaim/pages/my_addresses_page.dart';
import 'package:dalal_alqaim/pages/user_info_page.dart';
import 'package:dalal_alqaim/pages/add_place_page.dart';

// Auth pages
import 'package:dalal_alqaim/features/auth/pages/login_page.dart';
import 'package:dalal_alqaim/features/auth/pages/register_page.dart';
import 'package:dalal_alqaim/features/auth/pages/email_login_page.dart';
import 'package:dalal_alqaim/features/auth/widgets/role_selector_tab.dart';

import 'package:firebase_auth/firebase_auth.dart';

// Copied Taxi Captain Pages
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_dashboard_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/captain_login_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/captain_register_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_registration_status_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/rewards_page.dart'
    as taxi_rewards;
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/wallet_page.dart'
    as taxi_wallet;

// Copied Restaurant Merchant Pages
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_dashboard_page.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_login_page.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_register_page.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_analytics_page.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/add_food_page.dart';

// Store Pages
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_register_page.dart';

// Delivery Pages
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_registration_status_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_register_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_login_page.dart';

// Admin Portal Pages
import 'package:flutter/foundation.dart';
import 'package:dalal_alqaim/features/admin_web/pages/admin_web_portal_page.dart';
import 'package:dalal_alqaim/pages/admin_dashboard_page.dart';
import 'package:dalal_alqaim/features/admin/presentation/pages/admin_web_only_notice_page.dart';

// Madar Shop POS Pages
import 'package:dalal_alqaim/features/madar_shop/presentation/auth/madar_shop_auth_gate.dart';
import 'package:dalal_alqaim/features/madar_shop/presentation/pos/pages/windows_pos_page.dart';

class AppRouter {
  static const String welcome = '/welcome';
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String emailLogin = '/email-login';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String vacancies = '/vacancies';
  static const String complaints = '/complaints';
  static const String merchant = '/merchant';
  static const String myOrders = '/my_orders';

  // New Service Routes
  static const String taxi = '/taxi';
  static const String restaurants = '/restaurants';
  static const String delivery = '/delivery';
  static const String stores = '/stores';
  static const String allSections = '/all-sections';
  static const String realEstate = '/real_estate';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String emergency = '/emergency';
  static const String support = '/support';
  static const String myAddresses = '/my_addresses';
  static const String userInfo = '/user_info';
  static const String points = '/points';
  static const String cart = '/cart';
  static const String lostFound = '/lost_found';
  static const String addPlace = '/add_place';

  // Role Specific Routes
  static const String captainLogin = '/captain-login';
  static const String captainRegister = '/captain-register';
  static const String driverDashboard = '/driver-dashboard';
  static const String restaurantLogin = '/restaurant-login';
  static const String restaurantRegister = '/restaurant-register';
  static const String restaurantDashboard = '/restaurant-dashboard';
  static const String restaurantAnalytics = '/restaurant-analytics';
  static const String addFood = '/add-food';
  static const String storeDashboard = '/store-dashboard';
  static const String storeRegister = '/store-register';
  static const String deliveryDashboard = '/delivery-dashboard';
  static const String deliveryRegister = '/delivery-register';
  static const String deliveryLogin = '/delivery-login';
  static const String deliveryRegistrationStatus = '/delivery-registration-status';
  static const String registrationStatus = '/registration-status';
  static const String rewards = '/rewards';
  static const String wallet = '/wallet';

  // Admin Routes
  static const String admin = '/admin';
  static const String adminPortal = '/admin-portal';
  static const String adminDashboard = '/admin-dashboard';

  // Madar Shop POS Routes
  static const String shopAuthGate = '/shop/auth';
  static const String shopPos = '/shop/pos';

  static Map<String, WidgetBuilder> getRoutes(bool isDark) {
    return {
      welcome: (context) => const WelcomePage(),
      home: (context) => const HomePage(),
      login: (context) => const EnhancedLoginPage(),
      register: (context) => const EnhancedRegisterPage(),
      emailLogin: (context) => const EmailLoginPage(),
      favorites: (context) => const FavoritesPage(),
      profile: (context) => ProfilePage(isDarkMode: isDark),
      vacancies: (context) => const VacanciesPage(),
      complaints: (context) => const ComplaintsPage(),
      merchant: (context) => const RestaurantDashboardPage(),
      myOrders: (context) => const MyOrdersPage(),

      // Admin Web Portal (Web only - restricted on mobile app)
      admin: (context) => kIsWeb ? const AdminWebPortalPage() : const AdminWebOnlyNoticePage(),
      adminPortal: (context) => kIsWeb ? const AdminWebPortalPage() : const AdminWebOnlyNoticePage(),
      adminDashboard: (context) => kIsWeb ? const AdminDashboardPage() : const AdminWebOnlyNoticePage(),

      // New Routes Registration
      taxi: (context) => const TaxiRequestScreen(),
      restaurants: (context) => const RestaurantsPage(),
      delivery: (context) => const DeliveryPage(),
      stores: (context) => const MadarStoresPage(),
      allSections: (context) => const AllSectionsPage(),
      realEstate: (context) => const RealEstatePage(),
      search: (context) => const SearchPage(),
      settings: (context) => const SettingsPage(),
      notifications: (context) => const NotificationsPage(),
      emergency: (context) => const EmergencyServicesPage(),
      support: (context) => const TechnicalSupportChatPage(),
      myAddresses: (context) => const MyAddressesPage(),
      userInfo: (context) => const UserInfoPage(),
      points: (context) => const UserPointsPage(),
      cart: (context) => const CartPage(),
      lostFound: (context) => const AllSectionsPage(),
      addPlace: (context) => const AddPlacePage(),

      // Taxi Captain Routes
      captainLogin: (context) => const CaptainLoginPage(),
      captainRegister: (context) => const CaptainRegisterPage(),
      driverDashboard: (context) => const DriverDashboardPage(),
      rewards: (context) => const taxi_rewards.RewardsPage(),
      wallet: (context) => const taxi_wallet.WalletPage(),

      // Restaurant Routes
      restaurantLogin: (context) => const RestaurantLoginPage(),
      restaurantRegister: (context) => const RestaurantRegisterPage(),
      restaurantDashboard: (context) => const RestaurantDashboardPage(),
      restaurantAnalytics: (context) => const RestaurantAnalyticsPage(),
      addFood: (context) => const AddFoodPage(),

      // Store Routes
      storeDashboard: (context) => StoreDashboardPage(
            storeId: FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
      storeRegister: (context) => const StoreRegisterPage(),

      // Delivery Routes
      deliveryDashboard: (context) => const DeliveryDashboardPage(),
      deliveryRegister: (context) => const DeliveryRegisterPage(),
      deliveryLogin: (context) => const DeliveryLoginPage(),
      deliveryRegistrationStatus: (context) => const DeliveryRegistrationStatusPage(),

      // Status Guard Route
      registrationStatus: (context) => const DriverRegistrationStatusPage(),

      // Madar Shop POS
      shopAuthGate: (context) => const MadarShopAuthGate(),
      shopPos: (context) => const MadarShopAuthGate(),
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name == '/' || name == '') {
      return MaterialPageRoute(builder: (context) => const AuthWrapper(), settings: settings);
    }

    // Direct handlers for Madar Shop POS paths
    if (name == '/shop/auth' || name == '/shop/pos' || name == '/pos' || name == 'shop' || name == 'pos') {
      return MaterialPageRoute(builder: (context) => const MadarShopAuthGate(), settings: settings);
    }

    // Direct handlers for admin web paths (Restricted on mobile app)
    if (name == '/admin' || name == '/admin-portal' || name == '/admin-web' || name == 'admin') {
      if (!kIsWeb) {
        return MaterialPageRoute(builder: (context) => const AdminWebOnlyNoticePage(), settings: settings);
      }
      return MaterialPageRoute(builder: (context) => const AdminWebPortalPage(), settings: settings);
    }
    if (name == '/admin-dashboard') {
      if (!kIsWeb) {
        return MaterialPageRoute(builder: (context) => const AdminWebOnlyNoticePage(), settings: settings);
      }
      return MaterialPageRoute(builder: (context) => const AdminDashboardPage(), settings: settings);
    }

    final routes = getRoutes(false);
    final builder = routes[name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }

    return MaterialPageRoute(builder: (context) => const AuthWrapper(), settings: settings);
  }
}
