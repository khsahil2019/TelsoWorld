import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:telsoworld/core/constants/app_colors.dart';

class WebLinkEntry {
  final int id;
  final String subject;
  final String name;
  final String likeLimit;
  final String state;
  final String district;
  final String webLink;
  final String utr;
  final String uploadedAt;
  final String status; // 'Approved' | 'Pending'
  final int currentLikes;

  const WebLinkEntry({
    required this.id,
    required this.subject,
    required this.name,
    required this.likeLimit,
    required this.state,
    required this.district,
    required this.webLink,
    required this.utr,
    required this.uploadedAt,
    required this.status,
    this.currentLikes = 450,
  });

  WebLinkEntry copyWith({
    int? id,
    String? subject,
    String? name,
    String? likeLimit,
    String? state,
    String? district,
    String? webLink,
    String? utr,
    String? uploadedAt,
    String? status,
    int? currentLikes,
  }) {
    return WebLinkEntry(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      name: name ?? this.name,
      likeLimit: likeLimit ?? this.likeLimit,
      state: state ?? this.state,
      district: district ?? this.district,
      webLink: webLink ?? this.webLink,
      utr: utr ?? this.utr,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      status: status ?? this.status,
      currentLikes: currentLikes ?? this.currentLikes,
    );
  }
}

class UpdatedWebLinkScreen extends StatefulWidget {
  const UpdatedWebLinkScreen({super.key});

  @override
  State<UpdatedWebLinkScreen> createState() => _UpdatedWebLinkScreenState();
}

class _UpdatedWebLinkScreenState extends State<UpdatedWebLinkScreen> {
  String _filter = 'All';
  String _searchQuery = '';

  final List<WebLinkEntry> _entries = [
    const WebLinkEntry(
      id: 1,
      subject: 'Furniture Rental Portal',
      name: 'furniturerentwale',
      likeLimit: '1,000',
      state: 'Uttar Pradesh',
      district: 'Varanasi',
      webLink: 'https://www.furniturerentwale.com',
      utr: 'UTR9982348123',
      uploadedAt: '07 Mar 2026, 04:56 AM',
      status: 'Approved',
      currentLikes: 820,
    ),
    const WebLinkEntry(
      id: 2,
      subject: 'Telso Music Store',
      name: 'telsomusic',
      likeLimit: '5,000',
      state: 'Bihar',
      district: 'Patna',
      webLink: 'https://telsoworld.com/music',
      utr: 'UTR7718293940',
      uploadedAt: '12 Mar 2026, 11:20 AM',
      status: 'Approved',
      currentLikes: 3410,
    ),
    const WebLinkEntry(
      id: 3,
      subject: 'Folk Events Booking',
      name: 'folkevents',
      likeLimit: '2,500',
      state: 'Delhi',
      district: 'New Delhi',
      webLink: 'https://folkevents.in',
      utr: 'UTR1129384756',
      uploadedAt: 'Today, 09:15 AM',
      status: 'Pending',
      currentLikes: 0,
    ),
  ];

  Future<void> _openUrl(String url) async {
    try {
      await Share.share(url, subject: 'Website Link');
    } catch (_) {
      _copyLink(url);
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar(
      'Copied',
      'Web link copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1E1E24),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _showAddLinkModal() {
    final subjectCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final stateCtrl = TextEditingController(text: 'Uttar Pradesh');
    final districtCtrl = TextEditingController(text: 'Varanasi');
    final utrCtrl = TextEditingController();
    String selectedLikeLimit = '1,000';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🔗 Submit Website Link',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildInputField(label: 'Subject / Category', controller: subjectCtrl, hint: 'e.g. Online Store, Portal'),
                const SizedBox(height: 12),
                _buildInputField(label: 'Website Name / Title', controller: nameCtrl, hint: 'e.g. MyBrand Online'),
                const SizedBox(height: 12),
                _buildInputField(label: 'Website URL', controller: linkCtrl, hint: 'https://yourwebsite.com', prefixIcon: Icons.link_rounded),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _buildInputField(label: 'State', controller: stateCtrl, hint: 'State')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInputField(label: 'District', controller: districtCtrl, hint: 'District')),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Target Likes Promotion', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: ['500', '1,000', '2,500', '5,000'].map((limit) {
                    final isSelected = selectedLikeLimit == limit;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedLikeLimit = limit),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryPink : const Color(0xFF1E1E28),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AppColors.primaryPink : Colors.white10),
                          ),
                          child: Center(
                            child: Text(
                              limit,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                _buildInputField(label: 'Payment UTR / Txn ID', controller: utrCtrl, hint: 'e.g. UTR8892193821'),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (subjectCtrl.text.trim().isEmpty || linkCtrl.text.trim().isEmpty) {
                        Get.snackbar('Error', 'Please fill subject and website URL',
                            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
                        return;
                      }

                      final newEntry = WebLinkEntry(
                        id: _entries.length + 1,
                        subject: subjectCtrl.text.trim(),
                        name: nameCtrl.text.trim().isEmpty ? 'Website Link' : nameCtrl.text.trim(),
                        likeLimit: selectedLikeLimit,
                        state: stateCtrl.text.trim(),
                        district: districtCtrl.text.trim(),
                        webLink: linkCtrl.text.trim(),
                        utr: utrCtrl.text.trim().isEmpty ? '—' : utrCtrl.text.trim(),
                        uploadedAt: 'Just now',
                        status: 'Pending',
                        currentLikes: 0,
                      );

                      setState(() => _entries.insert(0, newEntry));
                      Navigator.of(ctx).pop();

                      Get.snackbar(
                        'Submitted Successfully',
                        'Your website link is submitted for review.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF1E1E24),
                        colorText: const Color(0xFF00E676),
                      );
                    },
                    child: const Text('Submit Web Link', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, color: AppColors.primaryPink, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _entries.where((e) {
      if (_filter != 'All' && e.status.toLowerCase() != _filter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          e.subject.toLowerCase().contains(q) ||
          e.webLink.toLowerCase().contains(q);
    }).toList();

    final approvedCount = _entries.where((e) => e.status == 'Approved').length;
    final pendingCount = _entries.where((e) => e.status == 'Pending').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : const Icon(Icons.link_rounded, color: Colors.white),
        title: const Text(
          'Website Link Promotions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _showAddLinkModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_link_rounded, color: Colors.white, size: 18),
              label: const Text(
                '+ New Link',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 📊 Analytics Overview Banner
          _buildOverviewBanner(approvedCount, pendingCount),
          const SizedBox(height: 18),

          // 🔍 Search Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF181822),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: const InputDecoration(
                hintText: 'Search by link, name, or subject...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryPink, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 🏷️ Status Filters Row
          Row(
            children: [
              _buildFilterChip('All', _entries.length),
              const SizedBox(width: 8),
              _buildFilterChip('Approved', approvedCount),
              const SizedBox(width: 8),
              _buildFilterChip('Pending', pendingCount),
            ],
          ),
          const SizedBox(height: 16),

          // 🔗 Link Cards List
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered.map((entry) => _buildWebLinkCard(entry)),
        ],
      ),
    );
  }

  Widget _buildOverviewBanner(int approved, int pending) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1D2B), Color(0xFF161622)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Promoted Web Portals',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Text('Active Campaigns', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem('${_entries.length}', 'TOTAL LINKS', Colors.white),
              Container(width: 1, height: 30, color: Colors.white10),
              _buildMetricItem('$approved', 'LIVE / APPROVED', const Color(0xFF00E676)),
              Container(width: 1, height: 30, color: Colors.white10),
              _buildMetricItem('$pending', 'IN REVIEW', const Color(0xFFFF9100)),
              Container(width: 1, height: 30, color: Colors.white10),
              _buildMetricItem('8.5K', 'TOTAL LIKES', const Color(0xFFFF4081)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String value, String label, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF181822),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.white10),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildWebLinkCard(WebLinkEntry entry) {
    final bool isApproved = entry.status == 'Approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, Subject & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subject,
                      style: const TextStyle(color: Color(0xFFFF6584), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isApproved ? const Color(0xFF00E676).withOpacity(0.15) : const Color(0xFFFF9100).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.status,
                  style: TextStyle(
                    color: isApproved ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // URL Chip with Open and Copy Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F2C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF00E5FF), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.webLink,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _openUrl(entry.webLink),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white60, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _copyLink(entry.webLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Meta: Region & Like Target
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white38, size: 13),
              const SizedBox(width: 4),
              Text('${entry.district}, ${entry.state}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              const Spacer(),
              const Icon(Icons.favorite_rounded, color: Color(0xFFFF2A6D), size: 13),
              const SizedBox(width: 4),
              Text(
                'Target: ${entry.likeLimit} Likes',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.link_off_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text('No web links found', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}
