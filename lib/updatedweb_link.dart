import 'package:flutter/material.dart';

// Same pink theme as dashboard
const Color kDashPink = Color(0xFFD70F64);

// ── Data model ────────────────────────────────────────────────────────────────

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
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class UpdatedWebLinkScreen extends StatefulWidget {
  const UpdatedWebLinkScreen({super.key});

  @override
  State<UpdatedWebLinkScreen> createState() => _UpdatedWebLinkScreenState();
}

class _UpdatedWebLinkScreenState extends State<UpdatedWebLinkScreen> {
  // Mock data – replace with real API calls
  List<WebLinkEntry> _entries = [
    const WebLinkEntry(
      id: 1,
      subject: 'furniturerentwale w...',
      name: 'furniturerentwale',
      likeLimit: '1,000',
      state: 'Varanasi',
      district: 'Uttar Pradesh',
      webLink: 'https://www.furniturerent...',
      utr: '—',
      uploadedAt: '07 Mar 2026\n04:56 AM',
      status: 'Approved',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _entries.isEmpty ? _buildEmptyState() : _buildContent(),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: kDashPink,
      elevation: 0,
      leading: const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(Icons.link, color: Colors.white),
      ),
      title: const Text(
        'Update Website Link',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ElevatedButton.icon(
            onPressed: _showAddLinkDialog,
            icon: const Icon(Icons.add_link, size: 16, color: kDashPink),
            label: const Text(
              'Update New Web Link',
              style: TextStyle(
                color: kDashPink,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // ── Table + List ─────────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Column(
      children: [
        _buildTableHeader(),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        Expanded(
          child: ListView.separated(
            itemCount: _entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
            itemBuilder: (context, index) => _buildRow(_entries[index]),
          ),
        ),
      ],
    );
  }

  // ── Header Row ───────────────────────────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: const [
            _HeaderCell('#',           width: 30),
            _HeaderCell('SUBJECT',     width: 110),
            _HeaderCell('NAME',        width: 110),
            _HeaderCell('LIKE LIMIT',  width: 80),
            _HeaderCell('STATE',       width: 90),
            _HeaderCell('DISTRICT',    width: 110),
            _HeaderCell('WEB LINK',    width: 140),
            _HeaderCell('UTR',         width: 70),
            _HeaderCell('SCREENSHOT',  width: 90),
            _HeaderCell('STATUS',      width: 90),
            _HeaderCell('UPLOADED AT', width: 110),
            _HeaderCell('ACTIONS',     width: 130),
          ],
        ),
      ),
    );
  }

  // ── Data Row ──────────────────────────────────────────────────────────────────

  Widget _buildRow(WebLinkEntry entry) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // #
            SizedBox(
              width: 30,
              child: Text(
                '${entry.id}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),

            // Subject
            SizedBox(
              width: 110,
              child: _AvatarLabel(
                label: entry.subject,
                color: Colors.deepPurple,
              ),
            ),

            // Name
            SizedBox(
              width: 110,
              child: _AvatarLabel(
                label: entry.name,
                color: Colors.green,
              ),
            ),

            // Like Limit
            SizedBox(
              width: 80,
              child: _AvatarLabel(
                label: entry.likeLimit,
                color: Colors.orange,
              ),
            ),

            // State
            SizedBox(
              width: 90,
              child: _AvatarLabel(
                label: entry.state,
                color: Colors.blue,
              ),
            ),

            // District
            SizedBox(
              width: 110,
              child: Row(
                children: [
                  const Icon(Icons.location_pin, size: 16, color: kDashPink),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      entry.district,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Web Link
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  const Icon(Icons.language, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      entry.webLink,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // UTR
            SizedBox(
              width: 70,
              child: Text(
                entry.utr,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),

            // Screenshot
            SizedBox(
              width: 90,
              child: entry.status == 'Approved'
                  ? const Icon(Icons.image_outlined, color: Colors.grey, size: 20)
                  : const Text('—', style: TextStyle(color: Colors.black38)),
            ),

            // Status
            SizedBox(
              width: 90,
              child: _StatusBadge(status: entry.status),
            ),

            // Uploaded At
            SizedBox(
              width: 110,
              child: Text(
                entry.uploadedAt,
                style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.5),
              ),
            ),

            // Actions
            SizedBox(
              width: 130,
              child: Row(
                children: [
                  _ActionBtn(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: Colors.orange,
                    onTap: () => _onEdit(entry),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: () => _onDelete(entry),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No web links added yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddLinkDialog,
            icon: const Icon(Icons.add_link, color: Colors.white),
            label: const Text(
              'Add Web Link',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDashPink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs & Actions ────────────────────────────────────────────────────────

  void _showAddLinkDialog() {
    final subjectCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Update New Web Link',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(subjectCtrl, 'Subject'),
            const SizedBox(height: 12),
            _dialogField(nameCtrl, 'Name'),
            const SizedBox(height: 12),
            _dialogField(linkCtrl, 'Web Link URL'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Web link submitted!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: kDashPink,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: kDashPink),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  TextField _dialogField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDashPink),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }

  void _onEdit(WebLinkEntry entry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit: ${entry.subject}'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onDelete(WebLinkEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Web Link'),
        content: Text('Delete "${entry.subject}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _entries = _entries.where((e) => e.id != entry.id).toList();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;

  const _HeaderCell(this.text, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AvatarLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _AvatarLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 7, backgroundColor: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool approved = status == 'Approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: approved ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
