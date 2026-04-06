import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../data/models/job_model.dart';
import '../../data/services/job_service.dart';
import '../../../auth/data/services/access_token_service.dart';
import '../widgets/job_card.dart';

class JobSuggestionPage extends StatefulWidget {
  const JobSuggestionPage({super.key});

  @override
  State<JobSuggestionPage> createState() => _JobSuggestionPageState();
}

class _JobSuggestionPageState extends State<JobSuggestionPage> {
  List<JobModel> _jobs = [];
  bool _isLoading = true;
  String _selectedFilter = 'ทั้งหมด';
  String? _userOccupation;
  List<String> _selectedSkills = [];
  Position? _currentPosition;
  String _currentLocationName = "กำลังหาพิกัด...";


  final List<String> _allSkills = [
    'ขับรถ',
    'คอมพิวเตอร์',
    'ภาษาอังกฤษ',
    'ภาษาไทย',
    'การสื่อสาร',
    'งานบริการ',
    'งานช่าง',
    'งานเขียน',
    'ออกแบบ',
    'ความอดทน',
    'การตลาด',
    'ศิลปะ',
    'ถ่ายภาพ',
    'แต่งภาพ',
    'ดูแลสัตว์',
  ];

  final List<String> _filters = [
    'ทั้งหมด',
    'แนะนำ',
    'รายวัน',
    'รายเดือน',
    'Work from Home',
    'หลังเลิกงาน',
  ];

  final List<String> _occupations = [
    'ยังไม่ได้ระบุ',
    'พนักงานบริษัท',
    'ค้าขาย/เจ้าของธุรกิจ',
    'นักเรียน/นักศึกษา',
    'รับจ้างทั่วไป',
    'ขับรถรับจ้าง',
    'ข้าราชการ/พนักงานรัฐ',
    'แม่บ้าน/พ่อบ้าน',
    'พนักงานไอที/กราฟิก',
    'ช่างฝีมือ/ช่างซ่อม',
    'ตกงาน/ว่างงาน',
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _currentLocationName = "ไม่ได้เปิด GPS");
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _currentLocationName = "ไม่ได้อนุญาต GPS");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _currentLocationName = "สิทธิ์ GPS ถูกปฏิเสธถาวร");
      return;
    }
    
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _currentPosition = position;
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
           _currentLocationName = "${place.subAdministrativeArea ?? place.locality}, ${place.administrativeArea}";
        });
      }
    } catch (e) {
      setState(() => _currentLocationName = "ไม่สามารถระบุพิกัดได้");
    }
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      await _handleLocationPermission();
      
      final occupation = await AccesstokenService.sharedStorage.read(key: "userOccupation");
      final skillsRaw = await AccesstokenService.sharedStorage.read(key: "userSkills");
      
      List<String> skills = [];
      if (skillsRaw != null && skillsRaw.isNotEmpty) {
        skills = skillsRaw.split(',');
      }

      final jobs = await JobService.getSuggestedJobs(
        occupation ?? 'ยังไม่ได้ระบุ',
        userSkills: skills,
        userLocation: _currentLocationName,
        userPosition: _currentPosition,
      );

      if (mounted) {
        setState(() {
          _userOccupation = occupation;
          _selectedSkills = skills;
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล')),
        );
      }
    }
  }

  Future<void> _toggleSkill(String skill) async {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
    await AccesstokenService.sharedStorage.write(
      key: "userSkills",
      value: _selectedSkills.join(','),
    );
    _loadJobs();
  }

  Future<void> _updateOccupation(String? newValue) async {
    if (newValue == null) return;
    setState(() => _isLoading = true);
    try {
      await AccesstokenService.sharedStorage.write(key: "userOccupation", value: newValue);
      await _loadJobs();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกข้อมูลอาชีพได้')),
        );
      }
    }
  }

  List<JobModel> get _filteredJobs {
    List<JobModel> results;
    if (_selectedFilter == 'ทั้งหมด') {
      results = List.from(_jobs);
    } else if (_selectedFilter == 'แนะนำ') {
      results = _jobs.where((job) => job.isRecommended).toList();
    } else if (_selectedFilter == 'รายวัน') {
      results = _jobs.where((job) => job.incomeType == 'daily').toList();
    } else if (_selectedFilter == 'รายเดือน') {
      results = _jobs.where((job) => job.incomeType == 'monthly').toList();
    } else {
      results = _jobs.where((job) => job.type.contains(_selectedFilter)).toList();
    }

    // Always sort recommended jobs to the top
    results.sort((a, b) {
      if (a.isRecommended && !b.isRecommended) return -1;
      if (!a.isRecommended && b.isRecommended) return 1;
      return 0;
    });

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D955F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'แนะนำอาชีพเสริม',
          style: GoogleFonts.kanit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF2D955F),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เพิ่มโอกาส เพิ่มรายได้',
                  style: GoogleFonts.kanit(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ปลดหนี้ให้ไวขึ้น!',
                  style: GoogleFonts.kanit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'พิกัดของคุณ: $_currentLocationName',
                        style: GoogleFonts.kanit(color: Colors.white70, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ปุ่มตั้งค่าเพิ่ม
                  ],
                ),
                const SizedBox(height: 24),
                
                // Profile & Skills Card
                Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ตั้งค่าโปรไฟล์เพื่อคำนวณงานที่เหมาะ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'อาชีพปัจจุบัน:',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _userOccupation ?? 'ยังไม่ได้ระบุ',
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2D955F)),
                              items: _occupations.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: GoogleFonts.kanit(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: _updateOccupation,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'ทักษะที่คุณถนัด (เลือกเพื่อเน้นงานเฉพาะทาง):',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allSkills.map((skill) {
                            final isSelected = _selectedSkills.contains(skill);
                            return GestureDetector(
                              onTap: () => _toggleSkill(skill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2D955F) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2D955F) : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  skill,
                                  style: GoogleFonts.kanit(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if ((_userOccupation != null && _userOccupation != 'ยังไม่ได้ระบุ') || _selectedSkills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA5D6A7).withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D955F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (_userOccupation != null && _userOccupation != 'ยังไม่ได้ระบุ' && _selectedSkills.isNotEmpty)
                                ? 'ระบบกำลังคำนวณงานที่เหมาะกับอาชีพ "$_userOccupation" และทักษะเฉพาะของคุณให้เป็นพิเศษ'
                                : _selectedSkills.isNotEmpty
                                    ? 'ระบบกำลังคำนวณงานที่เหมาะกับทักษะที่คุณเลือกให้เป็นพิเศษ'
                                    : 'ระบบกำลังคำนวณงานที่เหมาะกับอาชีพ "$_userOccupation" ให้เป็นพิเศษ',
                            style: GoogleFonts.kanit(
                              color: const Color(0xFF1B5E20),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Text(
                  'หมวดหมู่งาน',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      filter,
                      style: GoogleFonts.kanit(
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = filter);
                      }
                    },
                    selectedColor: const Color(0xFF2D955F),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2D955F) : Colors.grey.withOpacity(0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF2D955F))),
                )
              : _filteredJobs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'ไม่พบงานในหมวดหมู่นี้',
                              style: GoogleFonts.kanit(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32, top: 8),
                      itemCount: _filteredJobs.length,
                      itemBuilder: (context, index) {
                        return JobCard(job: _filteredJobs[index]);
                      },
                    ),

          // Footer Note (Disclaimer for Presentation)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                   Icon(Icons.tips_and_updates_rounded, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'หมายเหตุ: ระบบเลือกแนะนำงานจาก JobsDB และ Fastwork เนื่องจากเป็นแพลตฟอร์มที่ได้รับความนิยมอย่างสูงในปัจจุบัน',
                      style: GoogleFonts.kanit(
                        fontSize: 11,
                        color: Colors.grey[600],
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
