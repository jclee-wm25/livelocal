import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/restaurant_model.dart';
import '../models/discount_code_model.dart';
import '../controllers/localeats_controller.dart';
import '../controllers/auth_controller.dart';
import '../constants/app_colors.dart';

class AddRestaurantScreen extends StatefulWidget {
  const AddRestaurantScreen({super.key});

  @override
  State<AddRestaurantScreen> createState() => _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends State<AddRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _dishesCtrl = TextEditingController();
  final _socialMediaCtrl = TextEditingController();
  final _coverPhotoCtrl = TextEditingController(
    text: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600',
  );

  // Discount code fields
  final _discountCodeCtrl = TextEditingController();
  final _discountDescCtrl = TextEditingController();

  String _selectedState = 'Penang';
  String _selectedCuisine = 'Hawker Food';
  final String _selectedPrice = '\$';

  final List<String> _states = ['Penang', 'Kuala Lumpur', 'Perak', 'Johor', 'Selangor'];
  final List<String> _cuisines = ['Hawker Food', 'Nasi Kandar', 'Kopitiam', 'Malay', 'Chinese', 'Indian'];

  @override
  Widget build(BuildContext context) {
    final foodCtrl = Provider.of<LocalEatsController>(context);
    final authCtrl = Provider.of<AuthController>(context);
    final user = authCtrl.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Influencer Food Review', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Publish your TikTok/Instagram restaurant review to LiveLocal & offer exclusive discount codes to your followers!',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Restaurant Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCuisine,
                      decoration: const InputDecoration(labelText: 'Cuisine Type', border: OutlineInputBorder()),
                      items: _cuisines.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCuisine = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedState,
                      decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                      items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedState = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'City / Area *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Full Address *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dishesCtrl,
                decoration: const InputDecoration(labelText: 'Reviewed Dishes (e.g. Char Kuey Teow, Duck Egg) *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _socialMediaCtrl,
                decoration: const InputDecoration(labelText: 'TikTok / Instagram Review Post Link *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Social media link required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coverPhotoCtrl,
                decoration: const InputDecoration(labelText: 'Restaurant Cover Photo URL *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Photo URL required' : null,
              ),
              const SizedBox(height: 24),
              const Text('Add Exclusive Discount Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _discountCodeCtrl,
                decoration: const InputDecoration(labelText: 'Discount Code (e.g. FOODIE10)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountDescCtrl,
                decoration: const InputDecoration(labelText: 'Discount Description (e.g. 10% OFF all items)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final restId = 'rest-${DateTime.now().millisecondsSinceEpoch}';
                    final newRest = RestaurantModel(
                      id: restId,
                      name: _nameCtrl.text.trim(),
                      address: _addressCtrl.text.trim(),
                      state: _selectedState,
                      city: _cityCtrl.text.trim(),
                      cuisineType: _selectedCuisine,
                      priceRange: _selectedPrice,
                      reviewedDishes: _dishesCtrl.text.trim(),
                      influencerId: user?.id ?? 'influencer-1',
                      influencerName: user?.fullName ?? 'KL Foodie',
                      socialMediaUrl: _socialMediaCtrl.text.trim(),
                      coverPhotoUrl: _coverPhotoCtrl.text.trim(),
                    );

                    await foodCtrl.addRestaurantListing(newRest);

                    if (_discountCodeCtrl.text.trim().isNotEmpty) {
                      final newDisc = DiscountCodeModel(
                        id: 'disc-${DateTime.now().millisecondsSinceEpoch}',
                        restaurantId: restId,
                        code: _discountCodeCtrl.text.trim().toUpperCase(),
                        description: _discountDescCtrl.text.trim(),
                        expiryDate: DateTime.now().add(const Duration(days: 30)),
                        createdBy: user?.id ?? 'influencer-1',
                      );
                      await foodCtrl.addDiscountCode(newDisc);
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Food review & discount published!'), backgroundColor: AppColors.primary),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Publish Review Listing', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
