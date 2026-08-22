import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/routes/app_routes.dart';
import 'package:telsoworld/core/services/session_token_store.dart';

/// ---------------------------------------------------------------------------
/// 📝 MusicianRegistrationScreen (3-Step Creator Wizard with Bottom Sheet Dropdowns)
/// ---------------------------------------------------------------------------
/// Step 1: 👤 Musician & Identity (Name, Username, Email, DOB)
/// Step 2: 📍 Contact & Location (Mobile, WhatsApp, Searchable Bottom Sheet States/Districts)
/// Step 3: 🔐 Security & Referral (Password, Referral Code, Terms & Submit)
/// ---------------------------------------------------------------------------
class MusicianRegistrationScreen extends StatefulWidget {
  const MusicianRegistrationScreen({super.key});

  @override
  State<MusicianRegistrationScreen> createState() =>
      _MusicianRegistrationScreenState();
}

class _MusicianRegistrationScreenState
    extends State<MusicianRegistrationScreen> {
  final PageController _pageController = PageController();
  final Logger _logger = Logger();
  int _currentStep = 0;

  bool _agreeTerms = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _selectedState;
  String? _selectedDistrict;
  DateTime? _dob;

  // Controllers
  final _schoolNameCtrl = TextEditingController(); // school_name
  final _mobileCtrl = TextEditingController(); // mobile_no
  final _whatsappCtrl = TextEditingController(); // whatsapp
  final _emailCtrl = TextEditingController(); // email
  final _villageCtrl = TextEditingController(); // village
  final _pincodeCtrl = TextEditingController(); // pincode
  final _usernameCtrl = TextEditingController(); // username
  final _passwordCtrl = TextEditingController(); // password
  final _referralCtrl = TextEditingController(); // referral_code

  final _states = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  final _districtsByState = <String, List<String>>{
    'Bihar': [
      'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Darbhanga', 'Purnia', 'Arrah (Bhojpur)',
      'Begusarai', 'Katihar', 'Munger', 'Chhapra (Saran)', 'Saharsa', 'Sasaram (Rohtas)',
      'Hajipur (Vaishali)', 'Dehri', 'Siwan', 'Motihari (East Champaran)', 'Nawada', 'Buxar',
      'Kishanganj', 'Sitamarhi', 'Madhubani', 'Samastipur', 'Bettiah (West Champaran)'
    ],
    'Uttar Pradesh': [
      'Lucknow', 'Varanasi', 'Kanpur', 'Agra', 'Prayagraj (Allahabad)', 'Gorakhpur', 'Noida (Gautam Buddha Nagar)',
      'Ghaziabad', 'Meerut', 'Bareilly', 'Aligarh', 'Moradabad', 'Saharanpur', 'Jhansi', 'Ayodhya (Faizabad)',
      'Mathura', 'Muzaffarnagar', 'Firozabad', 'Mirzapur', 'Basti', 'Azamgarh', 'Jaunpur', 'Ballia'
    ],
    'Rajasthan': [
      'Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer', 'Bikaner', 'Bhilwara', 'Alwar', 'Bharatpur',
      'Sikar', 'Pali', 'Sri Ganganagar', 'Chittorgarh', 'Jhunjhunu', 'Barmer', 'Jaisalmer'
    ],
    'Gujarat': [
      'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Junagadh', 'Gandhinagar',
      'Anand', 'Navsari', 'Morbi', 'Mehsana', 'Bharuch', 'Porbandar', 'Valsad', 'Kutch'
    ],
    'Maharashtra': [
      'Mumbai City', 'Mumbai Suburban', 'Pune', 'Nagpur', 'Nashik', 'Thane', 'Chhatrapati Sambhajinagar (Aurangabad)',
      'Solapur', 'Amravati', 'Kolhapur', 'Navi Mumbai', 'Sangli', 'Jalgaon', 'Akola', 'Latur', 'Nanded'
    ],
    'Delhi': [
      'New Delhi', 'Central Delhi', 'South Delhi', 'North Delhi', 'East Delhi', 'West Delhi',
      'South West Delhi', 'North East Delhi', 'North West Delhi', 'Shahdara', 'South East Delhi'
    ],
    'Jharkhand': [
      'Ranchi', 'Jamshedpur (East Singhbhum)', 'Dhanbad', 'Bokaro', 'Deoghar', 'Hazaribagh', 'Giridih',
      'Ramgarh', 'Medininagar (Daltonganj)', 'Dumka', 'Chaibasa (West Singhbhum)', 'Koderma'
    ],
    'West Bengal': [
      'Kolkata', 'Howrah', 'North 24 Parganas', 'South 24 Parganas', 'Siliguri (Darjeeling)',
      'Durgapur (Paschim Bardhaman)', 'Asansol', 'Hooghly', 'Nadia', 'Murshidabad', 'Malda'
    ],
    'Madhya Pradesh': [
      'Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas', 'Satna', 'Ratlam', 'Rewa'
    ],
    'Haryana': [
      'Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Yamunanagar', 'Rohtak', 'Hisar', 'Karnal', 'Sonipat', 'Panchkula'
    ],
    'Punjab': [
      'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali (SAS Nagar)', 'Hoshiarpur', 'Pathankot'
    ],
    'Karnataka': [
      'Bengaluru Urban', 'Bengaluru Rural', 'Mysuru', 'Hubballi-Dharwad', 'Mangaluru (Dakshina Kannada)',
      'Belagavi', 'Kalaburagi', 'Davanagere', 'Ballari', 'Shivamogga', 'Tumakuru', 'Udupi'
    ],
    'Tamil Nadu': [
      'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli', 'Tiruppur', 'Vellore', 'Erode'
    ],
    'Telangana': [
      'Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam', 'Ramagundam', 'Mahbubnagar', 'Nalgonda'
    ],
    'Andhra Pradesh': [
      'Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Rajahmundry', 'Tirupati', 'Kakinada'
    ],
    'Odisha': [
      'Bhubaneswar (Khurda)', 'Cuttack', 'Rourkela (Sundargarh)', 'Berhampur (Ganjam)', 'Sambalpur', 'Puri', 'Balasore'
    ],
    'Assam': [
      'Guwahati (Kamrup Metro)', 'Silchar (Cachar)', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia', 'Tezpur (Sonitpur)'
    ],
    'Uttarakhand': [
      'Dehradun', 'Haridwar', 'Roorkee', 'Haldwani (Nainital)', 'Rudrapur (Udham Singh Nagar)', 'Rishikesh', 'Almora'
    ],
    'Himachal Pradesh': [
      'Shimla', 'Dharamshala (Kangra)', 'Mandi', 'Solan', 'Kullu', 'Baddi', 'Bilaspur', 'Hamirpur', 'Una'
    ],
    'Chhattisgarh': [
      'Raipur', 'Bhilai (Durg)', 'Bilaspur', 'Korba', 'Rajnandgaon', 'Jagdalpur (Bastar)', 'Ambikapur (Surguja)'
    ],
    'Goa': ['North Goa (Panaji)', 'South Goa (Margao)'],
  };

  List<String> get _districts {
    if (_selectedState == null) return [];
    return _districtsByState[_selectedState!] ?? [
      'Central District',
      'North District',
      'South District',
      'East District',
      'West District',
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _schoolNameCtrl.dispose();
    _mobileCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _villageCtrl.dispose();
    _pincodeCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  // ── Validation Helpers ──
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  bool _isValidMobile(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    return (clean.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) ||
        (clean.length == 12 && clean.startsWith('91') && RegExp(r'^91[6-9]\d{9}$').hasMatch(clean));
  }

  String get _dobDisplay => _dob == null
      ? 'Select Date of Birth'
      : '${_dob!.day.toString().padLeft(2, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.year}';

  String get _dobApi => _dob == null
      ? ''
      : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryPink,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E28),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF181822),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _dob = d);
  }

  void _showError(String message) {
    Get.snackbar(
      'Validation Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1E1E24),
      colorText: const Color(0xFFFF6584),
      margin: const EdgeInsets.all(16),
      icon: const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6584)),
      duration: const Duration(seconds: 3),
    );
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  // ── Step 1 Validation ──
  void _validateStep1AndNext() {
    final name = _schoolNameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your Musician / Channel Name.');
      return;
    }
    if (name.length < 2) {
      _showError('Musician / Channel Name must be at least 2 characters.');
      return;
    }
    if (username.isEmpty) {
      _showError('Please choose a unique username.');
      return;
    }
    if (username.length < 3) {
      _showError('Username must be at least 3 characters.');
      return;
    }
    if (username.contains(' ')) {
      _showError('Username cannot contain spaces.');
      return;
    }
    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }
    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address (e.g. yourname@gmail.com).');
      return;
    }
    if (_dob == null) {
      _showError('Please select your Date of Birth.');
      return;
    }
    _goToStep(1);
  }

  // ── Step 2 Validation ──
  void _validateStep2AndNext() {
    final mobile = _mobileCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim();
    final pincode = _pincodeCtrl.text.trim();

    if (mobile.isEmpty) {
      _showError('Please enter your mobile number.');
      return;
    }
    if (!_isValidMobile(mobile)) {
      _showError('Please enter a valid 10-digit Indian mobile number (e.g. 9876543210).');
      return;
    }
    if (whatsapp.isNotEmpty && !_isValidMobile(whatsapp)) {
      _showError('Please enter a valid 10-digit WhatsApp number or leave it blank.');
      return;
    }
    if (_selectedState == null) {
      _showError('Please select your State.');
      return;
    }
    if (_selectedDistrict == null) {
      _showError('Please select your District.');
      return;
    }
    if (pincode.isNotEmpty && pincode.length != 6) {
      _showError('Please enter a valid 6-digit Pincode.');
      return;
    }
    _goToStep(2);
  }

  // ── Final Registration API ──
  Future<void> _register() async {
    if (_passwordCtrl.text.isEmpty || _passwordCtrl.text.length < 4) {
      _showError('Password must be at least 4 characters long.');
      return;
    }
    if (!_agreeTerms) {
      _showError('Please agree to the Terms & Conditions to complete registration.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('https://telsoworld.com/api/reporter/register');

      final cleanMobile = _mobileCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
      final cleanWhatsapp = _whatsappCtrl.text.trim().replaceAll(RegExp(r'\D'), '');

      final body = {
        'school_name': _schoolNameCtrl.text.trim(),
        'mobile_no': cleanMobile.length == 12 ? cleanMobile.substring(2) : cleanMobile,
        'whatsapp': cleanWhatsapp.isNotEmpty
            ? (cleanWhatsapp.length == 12 ? cleanWhatsapp.substring(2) : cleanWhatsapp)
            : (cleanMobile.length == 12 ? cleanMobile.substring(2) : cleanMobile),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'village': _villageCtrl.text.trim().isNotEmpty ? _villageCtrl.text.trim() : 'City',
        'pincode': _pincodeCtrl.text.trim().isNotEmpty ? _pincodeCtrl.text.trim() : '110001',
        'dob': _dobApi,
        'district': _selectedDistrict!,
        'state': _selectedState!,
        'terms': '1',
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'password': _passwordCtrl.text,
        'referral_code': _referralCtrl.text.trim(),
      };

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;

        final bool status = json['status'] == true || json['status'] == 1;

        if (status) {
          try {
            final dynamic rawToken = json['token'] ?? (json['data']?['token']);
            final token = rawToken?.toString();
            if (token != null && token.isNotEmpty) {
              await SessionTokenStore.setToken(token);
            }
          } catch (_) {}

          Get.offAllNamed(AppRoutes.registrationSuccess);
        } else {
          final msg = json['message']?.toString() ?? 'Registration failed. Try again.';
          _showError(msg);
        }
      } else {
        _showError('Server error (${response.statusCode}). Please try again.');
      }
    } catch (e) {
      _showError('Unable to connect to server. Please check your internet connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Modern Searchable Bottom Sheet Modal Selector ──
  void _openSearchableBottomSheet({
    required String title,
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = items.where((item) {
              if (query.isEmpty) return true;
              return item.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: Color(0xFF12121A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Colors.white12, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Top Notch Grab Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with Close
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2A6D).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.map_rounded, color: Color(0xFFFF2A6D), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // 🔍 Search Bar inside Bottom Sheet
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B26),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (val) => setModalState(() => query = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search $title...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF2A6D), size: 18),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Items List
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching results found',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isSelected = item == selectedValue;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                tileColor: isSelected ? const Color(0xFFFF2A6D).withOpacity(0.12) : Colors.transparent,
                                title: Text(
                                  item,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF2A6D), size: 20)
                                    : null,
                                onTap: () {
                                  onSelected(item);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F16),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (_currentStep > 0) {
              _goToStep(_currentStep - 1);
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
        title: const Text(
          'Creator Registration',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🌌 Ambient Glowing Background
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD70F64).withOpacity(0.16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD70F64).withOpacity(0.3),
                    blurRadius: 120,
                  ),
                ],
              ),
            ),
          ),

          // Main Column
          Column(
            children: [
              const SizedBox(height: 12),

              // 🌟 Top 3-Step Indicator Bar
              _buildStepProgressBar(),
              const SizedBox(height: 16),

              // 📄 PageView for 3 Step Screens
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1Identity(),
                    _buildStep2Location(),
                    _buildStep3Security(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🌟 3-Step Visual Progress Indicator
  Widget _buildStepProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            _buildStepIcon(stepIndex: 0, label: 'Identity', icon: Icons.person_rounded),
            _buildStepConnector(isCompleted: _currentStep >= 1),
            _buildStepIcon(stepIndex: 1, label: 'Contact', icon: Icons.location_on_rounded),
            _buildStepConnector(isCompleted: _currentStep >= 2),
            _buildStepIcon(stepIndex: 2, label: 'Security', icon: Icons.lock_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon({
    required int stepIndex,
    required String label,
    required IconData icon,
  }) {
    final isDone = _currentStep > stepIndex;
    final isCurrent = _currentStep == stepIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isCurrent || isDone
                ? const LinearGradient(
                    colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
                  )
                : null,
            color: isCurrent || isDone ? null : const Color(0xFF1F1F2C),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF2A6D).withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Icon(
                    icon,
                    color: isCurrent ? Colors.white : Colors.white38,
                    size: 16,
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white38,
            fontSize: 10.5,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 14, left: 6, right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: isCompleted ? const Color(0xFFFF2A6D) : Colors.white12,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // STEP 1: Musician & Identity Info
  // ─────────────────────────────────────────
  Widget _buildStep1Identity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            title: 'Step 1: Musician & Profile',
            subtitle: 'Enter your artist name, username, and valid email',
            badge: '1 / 3',
          ),
          const SizedBox(height: 18),

          _buildFormCard([
            _buildInputField(
              label: 'Musician / Channel Name *',
              hint: 'e.g. Sahil Music Records',
              controller: _schoolNameCtrl,
              icon: Icons.music_note_rounded,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              label: 'Unique Username *',
              hint: 'e.g. sahil_star (no spaces)',
              controller: _usernameCtrl,
              icon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              label: 'Email Address *',
              hint: 'e.g. yourname@gmail.com',
              controller: _emailCtrl,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            // Birthday Date Picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date of Birth *',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDob,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF191924),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dobDisplay,
                          style: TextStyle(
                            color: _dob == null ? Colors.white30 : Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(Icons.cake_rounded, color: Color(0xFFFF2A6D), size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 24),

          // Continue Button
          _buildActionButton(
            label: 'Continue to Contact',
            icon: Icons.arrow_forward_rounded,
            onTap: _validateStep1AndNext,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // STEP 2: Contact & Location Info
  // ─────────────────────────────────────────
  Widget _buildStep2Location() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            title: 'Step 2: Contact & Location',
            subtitle: 'Provide verified phone and choose state & district',
            badge: '2 / 3',
          ),
          const SizedBox(height: 18),

          _buildFormCard([
            _buildInputField(
              label: 'Mobile Number *',
              hint: '10-digit mobile number (e.g. 9876543210)',
              controller: _mobileCtrl,
              icon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              label: 'WhatsApp Number (Optional)',
              hint: 'Same or 10-digit alternate number',
              controller: _whatsappCtrl,
              icon: Icons.chat_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // 🌟 Bottom Sheet State & District Selectors
            Row(
              children: [
                Expanded(
                  child: _buildBottomSheetTrigger(
                    label: 'State *',
                    hint: 'Select State',
                    value: _selectedState,
                    onTap: () {
                      _openSearchableBottomSheet(
                        title: 'Select State',
                        items: _states,
                        selectedValue: _selectedState,
                        onSelected: (val) {
                          setState(() {
                            _selectedState = val;
                            _selectedDistrict = null; // Reset district when state changes
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBottomSheetTrigger(
                    label: 'District *',
                    hint: _selectedState == null ? 'Choose State First' : 'Select District',
                    value: _selectedDistrict,
                    onTap: () {
                      if (_selectedState == null) {
                        _showError('Please select a State first.');
                        return;
                      }
                      _openSearchableBottomSheet(
                        title: 'Select District ($_selectedState)',
                        items: _districts,
                        selectedValue: _selectedDistrict,
                        onSelected: (val) {
                          setState(() => _selectedDistrict = val);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'Village / City',
                    hint: 'Locality',
                    controller: _villageCtrl,
                    icon: Icons.home_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInputField(
                    label: 'Pincode',
                    hint: '6-digit PIN',
                    controller: _pincodeCtrl,
                    icon: Icons.pin_drop_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 24),

          // Continue Button
          _buildActionButton(
            label: 'Continue to Security',
            icon: Icons.arrow_forward_rounded,
            onTap: _validateStep2AndNext,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // STEP 3: Security & Referral
  // ─────────────────────────────────────────
  Widget _buildStep3Security() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            title: 'Step 3: Security & Referral',
            subtitle: 'Set your password and finish account registration',
            badge: '3 / 3',
          ),
          const SizedBox(height: 18),

          _buildFormCard([
            // Password Field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Password *',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF191924),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Create a secure password (min 4 chars)',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFFF2A6D), size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildInputField(
              label: 'Referral Code (Optional)',
              hint: 'e.g. TELSO882',
              controller: _referralCtrl,
              icon: Icons.card_giftcard_rounded,
            ),
          ]),
          const SizedBox(height: 18),

          // Summary Mini Review Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF14141E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00E5FF), size: 16),
                    SizedBox(width: 6),
                    Text('Account Summary', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Creator: ${_schoolNameCtrl.text.isNotEmpty ? _schoolNameCtrl.text : "Musician"} (@${_usernameCtrl.text})\n• Mobile: ${_mobileCtrl.text}\n• Email: ${_emailCtrl.text}\n• Region: ${_selectedDistrict ?? ""}, ${_selectedState ?? ""}',
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreeTerms,
                  activeColor: const Color(0xFFFF2A6D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    children: const [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: TextStyle(color: Color(0xFFFF6584), fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' and Privacy Policy of Telso World.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Final Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _register,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD70F64).withOpacity(0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Complete Registration',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildStepHeader({
    required String title,
    required String subtitle,
    required String badge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2A6D).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF2A6D).withOpacity(0.3)),
          ),
          child: Text(
            badge,
            style: const TextStyle(color: Color(0xFFFF6584), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF191924),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFFFF2A6D), size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // 🌟 Bottom Sheet Trigger Box (Replaces inline dropdown)
  Widget _buildBottomSheetTrigger({
    required String label,
    required String hint,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF191924),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value != null ? const Color(0xFFFF2A6D).withOpacity(0.4) : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.white30,
                      fontSize: 13,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFFF2A6D), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD70F64).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
