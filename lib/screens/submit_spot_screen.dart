import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/spot_model.dart';
import '../controllers/spot_controller.dart';
import '../controllers/auth_controller.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class SubmitSpotScreen extends StatefulWidget {
  final SpotModel? existingSpot;

  const SubmitSpotScreen({super.key, this.existingSpot});

  @override
  State<SubmitSpotScreen> createState() => _SubmitSpotScreenState();
}

class _SubmitSpotScreenState extends State<SubmitSpotScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _bestTimeCtrl;
  late TextEditingController _activitiesCtrl;

  File? _selectedImage;
  String? _existingImageUrl;
  bool _isUploading = false;

  late String _selectedState;
  late String _selectedCategory;
  late String _selectedPrice;

  final List<String> _states = [
    'Penang',
    'Kuala Lumpur',
    'Perak',
    'Johor',
    'Selangor',
    'Melaka',
    'Sabah',
    'Sarawak'
  ];
  final List<String> _categories = [
    'Kopitiam',
    'Pasar Malam',
    'Indie Cafe',
    'Park / Walkway',
    'Hawker Food',
    'Heritage Spot'
  ];
  final List<String> _prices = ['\$', '\$\$', '\$\$\$'];

  @override
  void initState() {
    super.initState();
    final s = widget.existingSpot;

    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _cityCtrl = TextEditingController(text: s?.city ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _bestTimeCtrl = TextEditingController(text: s?.bestTime ?? '');
    _activitiesCtrl = TextEditingController(text: s?.thingsToDo ?? '');
    _existingImageUrl = s?.imageUrl;

    _selectedState = s?.state ?? 'Penang';
    _selectedCategory = s?.category ?? 'Kopitiam';
    _selectedPrice = s?.priceRange ?? '\$';

    // Ensure initial values are valid
    if (!_states.contains(_selectedState)) {
      _selectedState = _states.first;
    }
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = _categories.first;
    }
    if (!_prices.contains(_selectedPrice)) {
      _selectedPrice = _prices.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _bestTimeCtrl.dispose();
    _activitiesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotCtrl = Provider.of<SpotController>(context, listen: false);
    final authCtrl = Provider.of<AuthController>(context, listen: false);
    final isEditing = widget.existingSpot != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Spot' : 'Submit a Local Spot',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppStyles.defaultScreenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEditing && widget.existingSpot?.rejectionReason != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: AppStyles.defaultPadding,
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: AppStyles.defaultRadius,
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: AppStyles.padMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Reason for Rejection',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.errorDark)),
                            const SizedBox(height: 4),
                            Text(widget.existingSpot!.rejectionReason!,
                                style: const TextStyle(
                                    color: AppColors.errorDark)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                isEditing
                    ? 'Update your spot details below and resubmit for verification.'
                    : 'Help travellers & locals discover non-touristy gems in your area!',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: AppStyles.padLg),
              _buildTextField(_nameCtrl, 'Spot Name *'),
              const SizedBox(height: AppStyles.padMd),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                        'Category',
                        _categories,
                        _selectedCategory,
                        (val) => setState(() => _selectedCategory = val!)),
                  ),
                  const SizedBox(width: AppStyles.padMd),
                  Expanded(
                    child: _buildDropdown('State', _states, _selectedState,
                        (val) => setState(() => _selectedState = val!)),
                  ),
                ],
              ),
              const SizedBox(height: AppStyles.padMd),
              _buildTextField(_cityCtrl, 'City / Area *'),
              const SizedBox(height: AppStyles.padMd),
              _buildTextField(_addressCtrl, 'Full Address *'),
              const SizedBox(height: AppStyles.padMd),
              _buildTextField(
                  _descCtrl, 'Description (Why locals love this spot) *',
                  maxLines: 3),
              const SizedBox(height: AppStyles.padMd),
              Row(
                children: [
                  Expanded(
                    child:
                        _buildTextField(_bestTimeCtrl, 'Best Visiting Time *'),
                  ),
                  const SizedBox(width: AppStyles.padMd),
                  Expanded(
                    child: _buildDropdown(
                        'Price Range',
                        _prices,
                        _selectedPrice,
                        (val) => setState(() => _selectedPrice = val!)),
                  ),
                ],
              ),
              const SizedBox(height: AppStyles.padMd),
              _buildTextField(
                  _activitiesCtrl, 'Recommended Activities / Food *'),
              const SizedBox(height: AppStyles.padMd),
              _buildImagePicker(),
              const SizedBox(height: AppStyles.padXl),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppStyles.defaultRadius),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          if (_selectedImage == null &&
                              _existingImageUrl == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please upload a photo for the spot.'),
                                  backgroundColor: AppColors.error),
                            );
                            return;
                          }

                          setState(() => _isUploading = true);

                          String finalImageUrl = _existingImageUrl ?? '';

                          try {
                            if (_selectedImage != null) {
                              final ext = path.extension(_selectedImage!.path);
                              final filename =
                                  'spot_${DateTime.now().millisecondsSinceEpoch}$ext';

                              await Supabase.instance.client.storage
                                  .from('spot_images')
                                  .upload(filename, _selectedImage!);

                              finalImageUrl = Supabase.instance.client.storage
                                  .from('spot_images')
                                  .getPublicUrl(filename);
                            }

                            final updatedSpot = SpotModel(
                              id: isEditing
                                  ? widget.existingSpot!.id
                                  : 'spot-${DateTime.now().millisecondsSinceEpoch}',
                              name: _nameCtrl.text.trim(),
                              category: _selectedCategory,
                              description: _descCtrl.text.trim(),
                              state: _selectedState,
                              city: _cityCtrl.text.trim(),
                              address: _addressCtrl.text.trim(),
                              priceRange: _selectedPrice,
                              bestTime: _bestTimeCtrl.text.trim(),
                              thingsToDo: _activitiesCtrl.text.trim(),
                              imageUrl: finalImageUrl,
                              submittedBy: authCtrl.currentUser?.id ?? 'guest',
                              status: 'pending',
                              rejectionReason: null,
                              rating:
                                  isEditing ? widget.existingSpot!.rating : 0.0,
                              reviewCount: isEditing
                                  ? widget.existingSpot!.reviewCount
                                  : 0,
                            );

                            if (isEditing) {
                              await spotCtrl.updateSpot(updatedSpot);
                            } else {
                              await spotCtrl.submitSpot(updatedSpot);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing
                                      ? 'Spot resubmitted for verification!'
                                      : 'Spot submitted successfully!'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to upload image or submit spot: $e',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => _isUploading = false);
                            }
                          }
                        }
                      },
                child: _isUploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        isEditing
                            ? 'Resubmit for Verification'
                            : 'Submit for Verification',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spot Photo (Required) *',
            style:
                TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            // Automatically compresses and restricts image size for performance
            final pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1080,
              maxHeight: 1080,
              imageQuality: 85,
            );

            if (pickedFile != null) {
              setState(() {
                _selectedImage = File(pickedFile.path);
                _existingImageUrl = null;
              });
            }
          },
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppStyles.defaultRadius,
              border: Border.all(
                  color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: AppStyles.defaultRadius,
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  )
                : _existingImageUrl != null
                    ? ClipRRect(
                        borderRadius: AppStyles.defaultRadius,
                        child: Image.network(_existingImageUrl!,
                            fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Tap to upload a photo',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (val) =>
          val == null || val.isEmpty ? 'This field is required' : null,
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppStyles.defaultRadius,
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }
}
