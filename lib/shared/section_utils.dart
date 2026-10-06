import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/icon_utils.dart';

IconData sectionIconFromString(String? iconName) {
  if (iconName == null) return Icons.category;

  // Check if the iconName is a numeric code point (from Admin Panel)
  if (int.tryParse(iconName) != null) {
    return IconUtils.getIconByCode(int.parse(iconName));
  }

  switch (iconName.toLowerCase().trim()) {
    // General
    case 'category':
      return Icons.category;
    case 'home':
      return Icons.home;
    case 'work':
      return Icons.work;
    case 'person':
      return Icons.person;
    case 'settings':
      return Icons.settings;
    case 'map':
      return Icons.map;
    case 'search':
      return Icons.search;
    case 'star':
      return Icons.star;
    case 'favorite':
      return Icons.favorite;
    case 'menu':
      return Icons.menu;
    case 'close':
      return Icons.close;
    case 'add':
      return Icons.add;
    case 'edit':
      return Icons.edit;
    case 'delete':
      return Icons.delete;
    case 'image':
      return Icons.image;
    case 'camera':
      return Icons.camera_alt;
    case 'phone':
      return Icons.phone;
    case 'email':
      return Icons.email;
    case 'location':
      return Icons.location_on;
    case 'location_on':
      return Icons.location_on;

    // Food & Drink
    case 'restaurant':
      return Icons.restaurant;
    case 'restaurant_menu':
      return Icons.restaurant_menu;
    case 'fastfood':
      return Icons.fastfood;
    case 'local_dining':
      return Icons.local_dining;
    case 'local_cafe':
      return Icons.local_cafe;
    case 'cafe':
      return Icons.local_cafe;
    case 'coffee':
      return Icons.coffee;
    case 'local_bar':
      return Icons.local_bar;
    case 'local_pizza':
      return Icons.local_pizza;
    case 'bakery_dining':
      return Icons.bakery_dining;
    case 'icecream':
      return Icons.icecream;
    case 'liquor':
      return Icons.liquor;

    // Shopping
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'shopping_cart':
      return Icons.shopping_cart;
    case 'shopping_basket':
      return Icons.shopping_basket;
    case 'store':
      return Icons.store;
    case 'storefront':
      return Icons.storefront;
    case 'local_grocery_store':
      return Icons.local_grocery_store;
    case 'grocery':
      return Icons.local_grocery_store;
    case 'local_offer':
      return Icons.local_offer;

    // Services
    case 'local_hospital':
      return Icons.local_hospital;
    case 'hospital':
      return Icons.local_hospital;
    case 'local_pharmacy':
      return Icons.local_pharmacy;
    case 'pharmacy':
      return Icons.local_pharmacy;
    case 'medical_services':
      return Icons.medical_services;
    case 'local_gas_station':
      return Icons.local_gas_station;
    case 'gas_station':
      return Icons.local_gas_station;
    case 'local_atm':
      return Icons.local_atm;
    case 'atm':
      return Icons.local_atm;
    case 'local_laundry_service':
      return Icons.local_laundry_service;
    case 'cleaning_services':
      return Icons.cleaning_services;
    case 'hotel':
      return Icons.hotel;
    case 'local_hotel':
      return Icons.hotel;

    // Education
    case 'school':
      return Icons.school;
    case 'local_library':
      return Icons.local_library;
    case 'library':
      return Icons.local_library;
    case 'menu_book':
      return Icons.menu_book;

    // Entertainment & Sports
    case 'park':
      return Icons.park;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'gym':
      return Icons.fitness_center;
    case 'pool':
      return Icons.pool;
    case 'spa':
      return Icons.spa;
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'movie':
      return Icons.movie;
    case 'theaters':
      return Icons.theaters;
    case 'videogame_asset':
      return Icons.videogame_asset;

    // Transport
    case 'directions_car':
      return Icons.directions_car;
    case 'car':
      return Icons.directions_car;
    case 'taxi':
      return Icons.local_taxi;
    case 'local_taxi':
      return Icons.local_taxi;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'bus':
      return Icons.directions_bus;
    case 'flight':
      return Icons.flight;

    // Tech
    case 'computer':
      return Icons.computer;
    case 'smartphone':
      return Icons.smartphone;
    case 'wifi':
      return Icons.wifi;

    // Religion
    case 'mosque':
      return Icons.mosque;

    // Trades
    case 'build':
      return Icons.build;
    case 'construction':
      return Icons.construction;
    case 'plumbing':
      return Icons.plumbing;
    case 'electrical_services':
      return Icons.electrical_services;

    default:
      // Try to guess icon from common names if possible, else return category
      final lower = iconName.toLowerCase();
      if (lower.contains('food') || lower.contains('rest')) return Icons.restaurant;
      if (lower.contains('health') || lower.contains('med')) return Icons.medical_services;
      if (lower.contains('shop')) return Icons.shopping_bag;
      if (lower.contains('car') || lower.contains('taxi')) return Icons.local_taxi;
      return Icons.category;
  }
}
