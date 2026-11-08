import 'package:flutter/material.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/views/upload/reel_upload_view.dart';

class VideoEntry {
  final int id;
  final String subject;
  final String title;
  final String previewLabel;
  final String uploadedAt;
  final String status; // 'Pending' | 'Approved'
  final String views;
  final int likes;

  const VideoEntry({
    required this.id,
    required this.subject,
    required this.title,
    required this.previewLabel,
    required this.uploadedAt,
    required this.status,
    this.views = '1.2K',
    this.likes = 85,
  });
}

class UploadedVideoScreen extends StatefulWidget {
  const UploadedVideoScreen({super.key});

  @override
  State<UploadedVideoScreen> createState() => _UploadedVideoScreenState();
}

class _UploadedVideoScreenState extends State<UploadedVideoScreen> {
  String _filter = 'All';
  String _searchQuery = '';

  final List<VideoEntry> _videos = [
    const VideoEntry(
      id: 1,
      subject: 'Bhojpuri Folk Song',
      title: 'Avela Niyra Buta Dele Diyra',
      previewLabel: 'video_1.mp4',
      uploadedAt: '20/03/2026 05:40 AM',
      status: 'Approved',
      views: '24.5K',
      likes: 1240,
    ),
    const VideoEntry(
      id: 2,
      subject: 'Classical Dance',
      title: 'Stage Live Performance Patna',
      previewLabel: 'video_2.mp4',
      uploadedAt: '19/03/2026 10:15 AM',
      status: 'Approved',
      views: '12.8K',
      likes: 890,
    ),
    const VideoEntry(
      id: 3,
      subject: 'Reporter Ground Story',
      title: 'Public Reaction on New Schemes',
      previewLabel: 'video_3.mp4',
      uploadedAt: '19/03/2026 10:04 AM',
      status: 'Pending',
      views: '0',
      likes: 0,
    ),
    const VideoEntry(
      id: 4,
      subject: 'Harmonium Solo',
      title: 'Evening Raga Acoustic Performance',
      previewLabel: 'video_4.mp4',
      uploadedAt: '19/03/2026 10:03 AM',
      status: 'Approved',
      views: '45.1K',
      likes: 3100,
    ),
    const VideoEntry(
      id: 5,
      subject: 'Comedy Vines',
      title: 'Bhojpuri Funny Bloopers Part 1',
      previewLabel: 'video_5.mp4',
      uploadedAt: '19/03/2026 10:01 AM',
      status: 'Approved',
      views: '89.4K',
      likes: 5400,
    ),
    const VideoEntry(
      id: 6,
      subject: 'News Report',
      title: 'Local Markets & Festival Highlights',
      previewLabel: 'video_6.mp4',
      uploadedAt: '19/03/2026 10:00 AM',
      status: 'Pending',
      views: '0',
      likes: 0,
    ),
    const VideoEntry(
      id: 7,
      subject: 'Interview Video',
      title: 'Exclusive Talk with Young Artist',
      previewLabel: 'video_7.mp4',
      uploadedAt: '07/03/2026 12:17 PM',
      status: 'Approved',
      views: '15.2K',
      likes: 920,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _videos.where((v) {
      if (_filter != 'All' && v.status.toLowerCase() != _filter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return v.title.toLowerCase().contains(q) || v.subject.toLowerCase().contains(q);
    }).toList();

    final approvedCount = _videos.where((v) => v.status == 'Approved').length;
    final pendingCount = _videos.where((v) => v.status == 'Pending').length;

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
            : const Icon(Icons.video_library_rounded, color: Colors.white),
        title: const Text(
          'Creator Video Studio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ReelUploadScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: const Text(
                'Upload',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 📊 Studio Metrics Overview Cards
          _buildMetricsSection(approvedCount, pendingCount),
          const SizedBox(height: 18),

          // 🔍 Studio Search Input
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
                hintText: 'Search video by title or subject...',
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
              _buildFilterChip('All', _videos.length),
              const SizedBox(width: 8),
              _buildFilterChip('Approved', approvedCount),
              const SizedBox(width: 8),
              _buildFilterChip('Pending', pendingCount),
            ],
          ),
          const SizedBox(height: 16),

          // 🎬 Video Cards List
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered.map((video) => _buildStudioVideoCard(video)),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(int approved, int pending) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF22131F), Color(0xFF161622)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primaryPink.withOpacity(0.25)),
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
                      color: AppColors.primaryPink.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_graph_rounded, color: AppColors.primaryPink, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Creator Channel Analytics',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Text('Live Stats', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem('${_videos.length}', 'TOTAL VIDEOS', Colors.white),
              Container(width: 1, height: 30, color: Colors.white10),
              _buildMetricItem('$approved', 'APPROVED', const Color(0xFF00E676)),
              Container(width: 1, height: 30, color: Colors.white10),
              _buildMetricItem('$pending', 'IN REVIEW', const Color(0xFFFF9100)),
              Container(width: 1, height: 30, color: Colors.white10),
              _buildMetricItem('187K', 'TOTAL VIEWS', Colors.cyanAccent),
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
          color: isSelected ? AppColors.primaryPink : const Color(0xFF181822),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryPink : Colors.white10),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStudioVideoCard(VideoEntry video) {
    final bool isApproved = video.status == 'Approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Box
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD70F64), Color(0xFF8A2387)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('0:45', style: TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        video.title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? const Color(0xFF00E676).withOpacity(0.15)
                            : const Color(0xFFFF9100).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        video.status,
                        style: TextStyle(
                          color: isApproved ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  video.subject,
                  style: const TextStyle(color: Color(0xFFFF6584), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded, size: 13, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(video.views, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFFF2A6D)),
                    const SizedBox(width: 4),
                    Text('${video.likes}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      video.uploadedAt,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
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
          Icon(Icons.video_collection_outlined, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text('No videos found in this filter', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}
