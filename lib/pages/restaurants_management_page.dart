import 'package:flutter/material.dart';
import '../features/restaurants_management/application/restaurant_management_controller.dart';
import '../features/restaurants_management/presentation/widgets/restaurant_card.dart';
import '../features/restaurants_management/presentation/widgets/restaurant_source_toggle.dart';

/// Restaurants Management Page
/// تم تحويل الصفحة إلى معمارية نظيفة مفصولة الطبقات (Clean Architecture Conformance).
class RestaurantsManagementPage extends StatefulWidget {
  const RestaurantsManagementPage({super.key});

  @override
  State<RestaurantsManagementPage> createState() => _RestaurantsManagementPageState();
}

class _RestaurantsManagementPageState extends State<RestaurantsManagementPage> {
  late final RestaurantManagementController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = RestaurantManagementController()..init();
    _searchController.addListener(() {
      _controller.setQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final filteredList = _controller.filteredRestaurants;

        return Scaffold(
          appBar: AppBar(
            title: const Text('إدارة المطاعم', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: isDark ? Colors.teal[700] : Colors.teal,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _controller.init(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مطعم بالاسم أو المالك',
                    hintStyle: const TextStyle(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // Source Toggle (Restaurants collection vs items collectionGroup)
              RestaurantSourceToggle(
                showMainCollection: _controller.showMainCollection,
                onToggle: _controller.toggleSource,
              ),

              // Content List
              Expanded(
                child: _controller.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                    : filteredList.isEmpty
                        ? Center(
                            child: Text(
                              _controller.query.isEmpty ? 'ماكو مطاعم حالياً.' : 'ماكو نتائج حالياً مطابقة',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final restaurant = filteredList[index];
                              return RestaurantCard(
                                restaurant: restaurant,
                                onToggleSuspend: _controller.toggleSuspension,
                                onUpdateRestaurant: _controller.updateRestaurant,
                                onDeleteRestaurant: _controller.deleteRestaurant,
                                onFetchOwner: _controller.getOwnerUser,
                                onChangeOwnerPassword: _controller.changeOwnerPassword,
                              );
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
