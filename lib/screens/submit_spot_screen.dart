import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/spot_model.dart';
import '../controllers/spot_controller.dart';
import '../controllers/auth_controller.dart';

class SubmitSpotScreen extends StatefulWidget {
  const SubmitSpotScreen({super.key});

  @override
  State<SubmitSpotScreen> createState() => _SubmitSpotScreenState();
}

class _SubmitSpotScreenState extends State<SubmitSpotScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bestTimeCtrl = TextEditingController();
  final _activitiesCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController(
    text: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600',
  );

  String _selectedState = 'Penang';
  String _selectedCategory = 'Kopitiam';
  String _selectedPrice = '\$';

  final List<String> _states = ['Penang', 'Kuala Lumpur', 'Perak', 'Johor', 'Selangor', 'Melaka', 'Sabah', 'Sarawak'];
  final List<String> _categories = ['Kopitiam', 'Pasar Malam', 'Indie Cafe', 'Park / Walkway', 'Hawker Food', 'Heritage Spot'];
  final List<String> _prices = ['\$', '\$\$', '\$\$\$'];

  @override
  Widget build(BuildContext context) {
    final spotCtrl = Provider.of<SpotController>(context);
    final authCtrl = Provider.of<AuthController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit a Local Spot', style: TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
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
                'Help travellers & locals discover non-touristy gems in your area!',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Spot Name *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Please enter spot name' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedState,
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
                validator: (val) => val == null || val.isEmpty ? 'Please enter city or neighborhood' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Full Address *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Please enter address' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Why locals love this spot) *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter description' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bestTimeCtrl,
                      decoration: const InputDecoration(labelText: 'Best Visiting Time *', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPrice,
                      decoration: const InputDecoration(labelText: 'Price Range', border: OutlineInputBorder()),
                      items: _prices.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setState(() => _selectedPrice = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _activitiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Recommended Activities / Food *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Spot Photo URL (Minimum 1 Photo Required) *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Photo URL is required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final newSpot = SpotModel(
                      id: 'spot-${DateTime.now().millisecondsSinceEpoch}',
                      name: _nameCtrl.text.trim(),
                      category: _selectedCategory,
                      description: _descCtrl.text.trim(),
                      state: _selectedState,
                      city: _cityCtrl.text.trim(),
                      address: _addressCtrl.text.trim(),
                      priceRange: _selectedPrice,
                      bestTime: _bestTimeCtrl.text.trim(),
                      thingsToDo: _activitiesCtrl.text.trim(),
                      imageUrl: _imageUrlCtrl.text.trim(),
                      submittedBy: authCtrl.currentUser?.id ?? 'guest',
                      status: 'pending', // Pending admin approval (FR22)
                    );

                    await spotCtrl.submitSpot(newSpot);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Spot submitted successfully! Sent to admin for approval.'),
                          backgroundColor: Color(0xFF2D6A4F),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Submit for Verification', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
