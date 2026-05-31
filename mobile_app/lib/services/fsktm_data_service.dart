import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Enhanced local data service untuk FSKTM comprehensive information
/// No backend required - semua data local dalam JSON files
class FSKTMDataService {
  static Map<String, dynamic>? _cachedStaffData;
  static Map<String, dynamic>? _cachedKnowledgeBase;

  // FKAAB (Civil Engineering) cache
  static Map<String, dynamic>? _cachedFKAABStaffData;

  // FKEE (Electrical & Electronic Engineering) cache
  static Map<String, dynamic>? _cachedFKEEStaffData;

  /// Supported faculties enum
  static const Map<String, String> supportedFaculties = {
    'fsktm': 'Fakulti Sains Komputer dan Teknologi Maklumat',
    'fkaab': 'Fakulti Kejuruteraan Awam dan Alam Bina',
    'fkee': 'Fakulti Kejuruteraan Elektrik dan Elektronik',
  };

  // ============== QUERY EXPANSION: Sinonim BM ↔ EN + SLANG ==============
  /// Dictionary sinonim untuk expand query - supaya "pensyarah" match "lecturer" dll
  /// ENHANCED V2: 150+ terms with casual/slang, typos, abbreviations, greetings
  static const Map<String, List<String>> _synonymDictionary = {
    // ===========================================
    // STAFF/PEOPLE - Comprehensive
    // ===========================================
    'pensyarah': [
      'lecturer',
      'pengajar',
      'tenaga pengajar',
      'cikgu',
      'teacher',
      'lec',
      'lecturers'
    ],
    'lecturer': ['pensyarah', 'pengajar', 'tenaga pengajar', 'cikgu', 'lec'],
    'profesor': [
      'professor',
      'prof',
      'proffesor',
      'proffessor',
      'profssor'
    ], // typos
    'professor': ['profesor', 'prof', 'proffesor', 'proffessor'],
    'dekan': ['dean', 'ketua fakulti', 'pengetua'],
    'dean': ['dekan', 'ketua fakulti'],
    'ketua': ['head', 'pengarah', 'director', 'boss', 'chief', 'leader', 'kj'],
    'head': ['ketua', 'pengarah', 'boss', 'leader'],
    'staff': [
      'kakitangan',
      'pekerja',
      'staf',
      'orang',
      'worker',
      'workers',
      'employees'
    ],
    'kakitangan': ['staff', 'pekerja', 'staf', 'worker', 'workers'],
    'dr': ['doctor', 'doktor', 'dr.', 'doc'],
    'doctor': ['dr', 'doktor', 'dr.', 'doc'],
    'encik': ['mr', 'mister', 'en', 'en.', 'cik'],
    'puan': ['mrs', 'madam', 'mdm', 'pn', 'pn.', 'cik'],
    'tuan': ['sir', 'tn', 'tn.'],

    // ===========================================
    // ACADEMIC - Comprehensive
    // ===========================================
    'program': ['course', 'kursus', 'pengajian', 'subjek', 'major', 'jurusan'],
    'course': ['program', 'kursus', 'pengajian', 'subjek', 'kelas'],
    'kursus': ['course', 'program', 'pengajian', 'class', 'kelas'],
    'ijazah': ['degree', 'sarjana muda', 'diploma', 'bachelor', 'sijil'],
    'degree': ['ijazah', 'sarjana muda', 'diploma', 'bachelor'],
    'sarjana': [
      'master',
      'pascasiswazah',
      'masters',
      'postgrad',
      'postgraduate'
    ],
    'master': ['sarjana', 'pascasiswazah', 'masters', 'postgrad'],
    'phd': ['doctorate', 'doktoral', 'kedoktoran', 'doktor falsafah'],
    'belajar': ['study', 'studying', 'pelajar', 'student', 'blaja', 'blajr'],
    'study': ['belajar', 'studying', 'pelajar', 'blaja'],
    'pelajar': ['student', 'students', 'murid', 'anak murid', 'budak'],
    'student': ['pelajar', 'students', 'murid', 'budak'],

    // ===========================================
    // DEPARTMENTS & FACULTY - Comprehensive
    // ===========================================
    'jabatan': ['department', 'dept', 'unit', 'bahagian', 'jab'],
    'department': ['jabatan', 'dept', 'unit', 'bahagian'],
    'fakulti': ['faculty', 'fak', 'fakulty', 'fac'], // typos
    'faculty': ['fakulti', 'fak', 'fac'],
    'fsktm': [
      'fakulti sains komputer',
      'computer science',
      'it faculty',
      'fskpm'
    ], // typo
    'fkaab': ['kejuruteraan awam', 'civil engineering', 'civil', 'awam'],
    'fkee': [
      'kejuruteraan elektrik',
      'electrical engineering',
      'elektrik',
      'elektronik'
    ],

    // ===========================================
    // RESEARCH - Comprehensive
    // ===========================================
    'penyelidikan': ['research', 'kajian', 'projek', 'rresearch'], // typo
    'research': [
      'penyelidikan',
      'kajian',
      'projek',
      'rnd',
      'r&d',
      'penyelidik'
    ],
    'kepakaran': [
      'expertise',
      'specialization',
      'bidang',
      'skill',
      'expert',
      'pakar'
    ],
    'expertise': ['kepakaran', 'specialization', 'bidang', 'skill', 'pakar'],
    'pakar': ['expert', 'specialist', 'kepakaran'],

    // ===========================================
    // CONTACT INFO - Comprehensive
    // ===========================================
    'telefon': [
      'phone',
      'tel',
      'nombor',
      'number',
      'call',
      'fon',
      'hp',
      'handphone',
      'no tel'
    ],
    'phone': ['telefon', 'tel', 'nombor', 'number', 'hp', 'handphone'],
    'alamat': [
      'address',
      'lokasi',
      'tempat',
      'location',
      'kat mana',
      'dimana',
      'mane',
      'kt mana'
    ],
    'address': ['alamat', 'lokasi', 'tempat', 'location'],
    'emel': ['email', 'e-mel', 'mail', 'mel', 'e-mail', 'gmail'],
    'email': ['emel', 'e-mel', 'mail', 'mel', 'e-mail'],
    'website': ['web', 'laman web', 'site', 'portal', 'homepage'],
    'office': ['pejabat', 'bilik', 'room', 'ofis', 'opis'],
    'pejabat': ['office', 'bilik', 'room', 'ofis', 'opis'],

    // ===========================================
    // QUESTIONS/ACTIONS - Casual BM Slang
    // ===========================================
    'cari': [
      'find',
      'search',
      'senarai',
      'list',
      'carikan',
      'tolong cari',
      'carik',
      'cr'
    ],
    'find': ['cari', 'search', 'senarai', 'carikan', 'carik'],
    'siapa': ['who', 'sapa', 'sape', 'ape nama', 'sp', 'who is', 'whos'],
    'who': ['siapa', 'sapa', 'sape', 'sp'],
    'apa': ['what', 'apakah', 'ape', 'pe', 'ap', 'whats'],
    'what': ['apa', 'apakah', 'ape', 'pe'],
    'berapa': [
      'how many',
      'jumlah',
      'bilangan',
      'brapa',
      'bape',
      'brape',
      'brp'
    ],
    'mana': [
      'where',
      'kat mana',
      'dekat mana',
      'kt mane',
      'mn',
      'dmn',
      'di mana'
    ],
    'where': ['mana', 'kat mana', 'dekat mana', 'kt mane'],
    'kenapa': ['why', 'knp', 'nape', 'mengapa', 'knape', 'y'],
    'why': ['kenapa', 'mengapa', 'nape', 'knp'],
    'macam mana': [
      'how',
      'mcm mane',
      'camne',
      'cara',
      'mcmne',
      'canne',
      'cmne'
    ],
    'how': ['macam mana', 'bagaimana', 'cara', 'mcm mane', 'camne'],
    'bila': ['when', 'bile', 'bl', 'when is'],
    'when': ['bila', 'bile', 'bl'],

    // ===========================================
    // COMMON CASUAL/SLANG WORDS
    // ===========================================
    'boleh': ['can', 'bole', 'blh', 'could', 'bleh', 'bley'],
    'nak': ['want', 'mahu', 'nk', 'wanna', 'mau'],
    'ada': ['have', 'got', 'ade', 'ad', 'ader'],
    'tak': ['not', 'x', 'xde', 'takde', 'tiada', 'tk', 'xda', 'xdk'],
    'tidak': ['no', 'not', 'tak', 'x', 'xde'],
    'dgn': ['dengan', 'with', 'ngn', 'ngan'],
    'dengan': ['with', 'dgn', 'ngn', 'ngan'],
    'yg': ['yang', 'which', 'that', 'y'],
    'yang': ['which', 'that', 'yg', 'y'],
    'utk': ['untuk', 'for', 'tok', 'tuk'],
    'untuk': ['for', 'utk', 'tok', 'tuk'],
    'dlm': ['dalam', 'in', 'inside', 'dlem'],
    'dalam': ['in', 'inside', 'dlm'],
    'ni': ['this', 'ini', 'nih'],
    'tu': ['that', 'itu', 'tuh'],
    'je': ['only', 'just', 'sahaja', 'saje', 'jer'],
    'pun': ['also', 'too', 'pon'],
    'dah': ['already', 'sudah', 'dh'],
    'lagi': ['more', 'again', 'lg', 'lgi'],
    'saya': ['i', 'me', 'sy', 'aku', 'ak', 'gua', 'gue'],
    'kamu': ['you', 'awak', 'kau', 'ko', 'u', 'hang', 'demo'],
    'awak': ['you', 'kamu', 'kau', 'ko', 'u'],
    'dia': ['he', 'she', 'dy', 'die'],

    // ===========================================
    // GREETINGS & POLITE PHRASES
    // ===========================================
    'tolong': ['help', 'please', 'tlg', 'pls', 'plz', 'tlng'],
    'help': ['tolong', 'bantu', 'tlg'],
    'terima kasih': ['thank you', 'thanks', 'tq', 'ty', 'tks', 'tkasih'],
    'thanks': ['terima kasih', 'tq', 'ty', 'tks'],
    'hai': ['hi', 'hey', 'hello', 'hye', 'hai2'],
    'hello': ['hai', 'hi', 'hey', 'helo', 'hye'],
    'assalamualaikum': ['salam', 'slm', 'assalam', 'wsalam'],
    'salam': ['assalamualaikum', 'slm', 'assalam'],

    // ===========================================
    // COMMON TYPOS & ABBREVIATIONS
    // ===========================================
    'information': ['info', 'maklumat', 'informasi'],
    'maklumat': ['information', 'info', 'informasi', 'mklmt'],
    'nama': ['name', 'nm'],
    'name': ['nama', 'nm'],
    'senarai': ['list', 'listing', 'senari'], // typo
    'list': ['senarai', 'listing'],
  };

  // ============== CHUNKING: Document Chunks for Better Retrieval ==============
  /// Cached chunks for efficient retrieval
  static List<DocumentChunk>? _cachedChunks;

  /// Create chunks from knowledge base for better retrieval
  static Future<List<DocumentChunk>> _createChunks() async {
    if (_cachedChunks != null) return _cachedChunks!;

    final staffData = await loadStaffData();
    final knowledgeBase = await loadKnowledgeBase();
    final chunks = <DocumentChunk>[];

    // Chunk 1: Faculty Identity
    if (knowledgeBase['faculty_identity'] != null) {
      final identity = knowledgeBase['faculty_identity'];
      chunks.add(DocumentChunk(
        id: 'faculty_identity',
        category: 'faculty',
        keywords: [
          'fsktm',
          'fakulti',
          'faculty',
          'uthm',
          'visi',
          'misi',
          'vision',
          'mission'
        ],
        content: '''
IDENTITI FAKULTI:
Nama: ${identity['official_name']?['malay'] ?? 'FSKTM'}
English: ${identity['official_name']?['english'] ?? 'Faculty of Computer Science'}
Singkatan: ${identity['official_name']?['acronym'] ?? 'FSKTM'}
Universiti: ${identity['university'] ?? 'UTHM'}
Visi: ${identity['vision'] ?? '-'}
Misi: ${identity['mission'] ?? '-'}
''',
      ));
    }

    // Chunk 2: Contact Information
    if (knowledgeBase['quick_answers'] != null) {
      final qa = knowledgeBase['quick_answers'];
      chunks.add(DocumentChunk(
        id: 'contact_info',
        category: 'contact',
        keywords: [
          'telefon',
          'phone',
          'email',
          'alamat',
          'address',
          'hubungi',
          'contact'
        ],
        content: '''
MAKLUMAT HUBUNGAN FSKTM:
Telefon: ${qa['phone'] ?? '+607 453 3606'}
Email: ${qa['email'] ?? 'fsktm@uthm.edu.my'}
Alamat: ${qa['address'] ?? 'UTHM Parit Raja'}
Website: https://fsktm.uthm.edu.my
''',
      ));
    }

    // Chunk 3: Statistics
    if (knowledgeBase['quick_answers'] != null) {
      final qa = knowledgeBase['quick_answers'];
      chunks.add(DocumentChunk(
        id: 'statistics',
        category: 'stats',
        keywords: ['berapa', 'jumlah', 'total', 'ramai', 'banyak', 'statistik'],
        content: '''
STATISTIK FSKTM:
Jumlah Pelajar: ${qa['total_students'] ?? '-'}
Jumlah Akademik: ${qa['total_academicians'] ?? '-'}
Jumlah Program: ${qa['total_programs'] ?? '-'}
''',
      ));
    }

    // Chunk 4: Departments
    final departments = staffData['departments'] as List? ?? [];
    if (departments.isNotEmpty) {
      final deptContent = StringBuffer('JABATAN-JABATAN FSKTM:\n');
      for (var dept in departments) {
        deptContent.writeln('- ${dept['name']} (${dept['name_en']})');
      }
      chunks.add(DocumentChunk(
        id: 'departments',
        category: 'department',
        keywords: ['jabatan', 'department', 'dept'],
        content: deptContent.toString(),
      ));
    }

    // Chunk 5-N: Individual Staff (each staff as separate chunk)
    final staff = staffData['staff'] as List? ?? [];
    for (int i = 0; i < staff.length; i++) {
      final member = staff[i];
      final nameParts = member['name'].toString().toLowerCase().split(' ');
      chunks.add(DocumentChunk(
        id: 'staff_$i',
        category: 'staff',
        keywords: [
          ...nameParts.where((p) => p.length > 2),
          member['department'].toString().toLowerCase(),
          'pensyarah',
          'lecturer',
          'staff',
        ],
        content: '''
STAFF: ${member['name']}
Jawatan: ${member['title']}
Jabatan: ${member['department']}
Email: ${member['email']}
${member['specialization'] != null ? 'Kepakaran: ${member['specialization']}' : ''}
''',
      ));
    }

    // Chunk: Programs
    if (knowledgeBase['academic_programs'] != null) {
      final programs = knowledgeBase['academic_programs'];
      final progContent =
          StringBuffer('PROGRAM AKADEMIK FSKTM:\n\nSARJANA MUDA:\n');

      if (programs['undergraduate'] != null) {
        final undergrad = programs['undergraduate']['programs'] as List? ?? [];
        for (var prog in undergrad) {
          progContent.writeln('- ${prog['title'] ?? prog['name']}');
        }
      }

      if (programs['postgraduate'] != null) {
        progContent.writeln('\nPASCA SISWAZAH:');
        final postgrad = programs['postgraduate']['programs'] as List? ?? [];
        for (var prog in postgrad) {
          progContent.writeln('- ${prog['title'] ?? prog['name']}');
        }
      }

      chunks.add(DocumentChunk(
        id: 'programs',
        category: 'program',
        keywords: [
          'program',
          'course',
          'kursus',
          'ijazah',
          'degree',
          'sarjana',
          'bachelor',
          'master',
          'phd'
        ],
        content: progContent.toString(),
      ));
    }

    _cachedChunks = chunks;
    debugPrint('RAG Chunking: Created ${chunks.length} chunks');
    return chunks;
  }

  /// Get relevant chunks based on query
  static Future<List<DocumentChunk>> getRelevantChunks(String query,
      {int maxChunks = 5}) async {
    final chunks = await _createChunks();
    final expandedQuery = expandQueryWithSynonyms(query.toLowerCase());
    final queryWords = expandedQuery.split(RegExp(r'\s+'));

    // Score each chunk
    final scoredChunks = <MapEntry<DocumentChunk, double>>[];

    for (final chunk in chunks) {
      double score = 0.0;

      // Check keyword matches
      for (final keyword in chunk.keywords) {
        if (expandedQuery.contains(keyword)) {
          score += 1.0;
        }
        // Fuzzy match for keywords
        for (final queryWord in queryWords) {
          if (queryWord.length >= 3) {
            final fuzzyScore = _fuzzyMatchScore(queryWord, keyword);
            if (fuzzyScore >= 0.7) {
              score += fuzzyScore * 0.5;
            }
          }
        }
      }

      // Content match bonus
      final contentLower = chunk.content.toLowerCase();
      for (final queryWord in queryWords) {
        if (queryWord.length >= 3 && contentLower.contains(queryWord)) {
          score += 0.3;
        }
      }

      if (score > 0) {
        scoredChunks.add(MapEntry(chunk, score));
      }
    }

    // Sort by score and return top chunks
    scoredChunks.sort((a, b) => b.value.compareTo(a.value));

    return scoredChunks.take(maxChunks).map((e) => e.key).toList();
  }

  /// Expand query dengan sinonim untuk matching yang lebih baik
  static String expandQueryWithSynonyms(String query) {
    String expandedQuery = query.toLowerCase();

    _synonymDictionary.forEach((word, synonyms) {
      if (expandedQuery.contains(word)) {
        // Add synonyms to query for better matching
        for (final synonym in synonyms) {
          if (!expandedQuery.contains(synonym)) {
            expandedQuery = '$expandedQuery $synonym';
          }
        }
      }
    });

    return expandedQuery;
  }

  /// Load FSKTM staff data dari local JSON file
  static Future<Map<String, dynamic>> loadStaffData() async {
    if (_cachedStaffData != null) {
      return _cachedStaffData!;
    }

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/fsktm_staff_data.json');
      _cachedStaffData = json.decode(jsonString);
      return _cachedStaffData!;
    } catch (e) {
      if (kDebugMode) print('Error loading FSKTM staff data: $e');
      return _getDefaultStaffData();
    }
  }

  /// Load comprehensive knowledge base dari local JSON file
  static Future<Map<String, dynamic>> loadKnowledgeBase() async {
    if (_cachedKnowledgeBase != null) {
      return _cachedKnowledgeBase!;
    }

    try {
      final String jsonString = await rootBundle
          .loadString('assets/data/fsktm_comprehensive_knowledge_base.json');
      _cachedKnowledgeBase = json.decode(jsonString);
      return _cachedKnowledgeBase!;
    } catch (e) {
      if (kDebugMode) print('Error loading FSKTM knowledge base: $e');
      return _getDefaultKnowledgeBase();
    }
  }

  /// Load FKAAB (Civil Engineering) staff data dari local JSON file
  static Future<Map<String, dynamic>> loadFKAABStaffData() async {
    if (_cachedFKAABStaffData != null) {
      return _cachedFKAABStaffData!;
    }

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/fkaab_staff_data.json');
      _cachedFKAABStaffData = json.decode(jsonString);
      return _cachedFKAABStaffData!;
    } catch (e) {
      if (kDebugMode) print('Error loading FKAAB staff data: $e');
      return _getDefaultFKAABStaffData();
    }
  }

  /// Detect which faculty the user is asking about
  /// Returns: 'fsktm', 'fkaab', 'fkee', 'unclear', or 'general'
  static String detectFacultyFromQuery(String query) {
    final lowerQuery = query.toLowerCase();

    // FSKTM keywords
    final fsktmKeywords = [
      'fsktm',
      'sains komputer',
      'computer science',
      'it',
      'software',
      'multimedia',
      'keselamatan maklumat',
      'information security',
      'web technology',
      'teknologi web',
      'kejuruteraan perisian',
    ];

    // FKAAB keywords
    final fkaabKeywords = [
      'fkaab',
      'kejuruteraan awam',
      'civil engineering',
      'alam bina',
      'built environment',
      'senibina',
      'architecture',
      'struktur',
      'geoteknik',
      'hidrologi',
      'pembinaan',
      'construction',
    ];

    // FKEE keywords
    final fkeeKeywords = [
      'fkee',
      'kejuruteraan elektrik',
      'electrical engineering',
      'kejuruteraan elektronik',
      'electronic engineering',
      'elektrik',
      'elektronik',
      'elektrikal',
      'power system',
      'sistem kuasa',
      'robotik',
      'robotics',
      'automation',
      'automasi',
    ];

    final hasFSKTM = fsktmKeywords.any((k) => lowerQuery.contains(k));
    final hasFKAAB = fkaabKeywords.any((k) => lowerQuery.contains(k));
    final hasFKEE = fkeeKeywords.any((k) => lowerQuery.contains(k));

    // Count how many faculties detected
    int facultyCount =
        (hasFSKTM ? 1 : 0) + (hasFKAAB ? 1 : 0) + (hasFKEE ? 1 : 0);

    if (facultyCount == 1) {
      if (hasFSKTM) return 'fsktm';
      if (hasFKAAB) return 'fkaab';
      if (hasFKEE) return 'fkee';
    }
    if (facultyCount > 1) return 'unclear';

    // Check for generic staff/lecturer queries without faculty specified
    final genericStaffKeywords = [
      'lecturer',
      'pensyarah',
      'staff',
      'professor',
      'prof',
      'dr.',
      'siapa',
      'who',
      'email',
      'contact',
    ];
    if (genericStaffKeywords.any((k) => lowerQuery.contains(k))) {
      return 'unclear'; // Need clarification which faculty
    }

    return 'general';
  }

  /// Get context for specific faculty
  static Future<String> getFacultyContextForAI(
      String faculty, String query) async {
    if (faculty == 'fsktm') {
      return await getFSKTMContextForAIWithQuery(query);
    } else if (faculty == 'fkaab') {
      return await getFKAABContextForAI(query);
    } else if (faculty == 'fkee') {
      return await getFKEEContextForAI(query);
    }
    return '';
  }

  /// Generate FKAAB context for AI
  static Future<String> getFKAABContextForAI(String query) async {
    final staffData = await loadFKAABStaffData();
    final StringBuffer context = StringBuffer();
    final lowerQuery = query.toLowerCase();
    final expandedQuery = expandQueryWithSynonyms(lowerQuery);

    context.writeln('=== FKAAB (Fakulti Kejuruteraan Awam dan Alam Bina) ===');

    final facultyInfo = staffData['faculty_info'];
    context.writeln('Nama: ${facultyInfo['name']}');
    context.writeln('English: ${facultyInfo['name_en']}');
    context.writeln('Total Staff: ${facultyInfo['total_staff']}');
    context.writeln('');

    // Add departments
    final departments = staffData['departments'] as List? ?? [];
    context.writeln('=== JABATAN ===');
    for (var dept in departments) {
      context.writeln('- ${dept['name']} (${dept['name_en']})');
    }
    context.writeln('');

    // Smart staff search
    final staff = staffData['staff'] as List? ?? [];
    final relevantStaff = _findRelevantStaff(staff, expandedQuery);

    if (relevantStaff.isNotEmpty) {
      context.writeln('=== STAFF BERKAITAN ===');
      for (var member in relevantStaff.take(3)) {
        context.writeln('**${member['name']}**');
        context.writeln('Jawatan: ${member['title']}');
        context.writeln('Jabatan: ${member['department']}');
        context.writeln('Email: ${member['email']}');
        context.writeln('---');
      }
    } else {
      context.writeln(
          '=== SENARAI STAFF (menunjukkan 3 daripada ${staff.length} orang) ===');
      for (var member in staff.take(3)) {
        context.writeln(
            '${member['name']} | ${member['title']} | ${member['email']}');
      }
    }

    return context.toString();
  }

  /// Default FKAAB staff data fallback
  static Map<String, dynamic> _getDefaultFKAABStaffData() {
    return {
      'faculty_info': {
        'name': 'Fakulti Kejuruteraan Awam dan Alam Bina',
        'name_en': 'Faculty of Civil Engineering and Built Environment',
        'acronym': 'FKAAB',
        'university': 'Universiti Tun Hussein Onn Malaysia (UTHM)',
        'total_staff': 0,
      },
      'departments': [],
      'staff': [],
    };
  }

  /// Load FKEE (Electrical & Electronic Engineering) staff data
  static Future<Map<String, dynamic>> loadFKEEStaffData() async {
    if (_cachedFKEEStaffData != null) {
      return _cachedFKEEStaffData!;
    }

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/fkee_staff_data.json');
      _cachedFKEEStaffData = json.decode(jsonString);
      return _cachedFKEEStaffData!;
    } catch (e) {
      if (kDebugMode) print('Error loading FKEE staff data: $e');
      return _getDefaultFKEEStaffData();
    }
  }

  /// Generate FKEE context for AI
  static Future<String> getFKEEContextForAI(String query) async {
    final staffData = await loadFKEEStaffData();
    final StringBuffer context = StringBuffer();
    final lowerQuery = query.toLowerCase();
    final expandedQuery = expandQueryWithSynonyms(lowerQuery);

    context
        .writeln('=== FKEE (Fakulti Kejuruteraan Elektrik dan Elektronik) ===');

    final facultyInfo = staffData['faculty_info'];
    context.writeln('Nama: ${facultyInfo['name']}');
    context.writeln('English: ${facultyInfo['name_en']}');
    context.writeln('Total Staff: ${facultyInfo['total_staff']}');
    context.writeln('');

    // Add departments
    final departments = staffData['departments'] as List? ?? [];
    context.writeln('=== JABATAN ===');
    for (var dept in departments) {
      context.writeln('- ${dept['name']} (${dept['name_en']})');
    }
    context.writeln('');

    // Smart staff search
    final staff = staffData['staff'] as List? ?? [];
    final relevantStaff = _findRelevantStaff(staff, expandedQuery);

    if (relevantStaff.isNotEmpty) {
      context.writeln('=== STAFF BERKAITAN ===');
      for (var member in relevantStaff.take(3)) {
        context.writeln('**${member['name']}**');
        context.writeln('Jawatan: ${member['title']}');
        context.writeln('Jabatan: ${member['department']}');
        context.writeln('Email: ${member['email']}');
        context.writeln('---');
      }
    } else {
      context.writeln(
          '=== SENARAI STAFF (menunjukkan 3 daripada ${staff.length} orang) ===');
      for (var member in staff.take(3)) {
        context.writeln(
            '${member['name']} | ${member['title']} | ${member['email']}');
      }
    }

    return context.toString();
  }

  /// Default FKEE staff data fallback
  static Map<String, dynamic> _getDefaultFKEEStaffData() {
    return {
      'faculty_info': {
        'name': 'Fakulti Kejuruteraan Elektrik dan Elektronik',
        'name_en': 'Faculty of Electrical and Electronic Engineering',
        'acronym': 'FKEE',
        'university': 'Universiti Tun Hussein Onn Malaysia (UTHM)',
        'total_staff': 0,
      },
      'departments': [],
      'staff': [],
    };
  }

  /// ENHANCED: Generate comprehensive context string untuk AI chatbot
  static Future<String> getFSKTMContextForAI() async {
    final staffData = await loadStaffData();
    final knowledgeBase = await loadKnowledgeBase();

    final StringBuffer context = StringBuffer();

    // === QUICK ANSWERS (Priority untuk fast responses) ===
    if (knowledgeBase['quick_answers'] != null) {
      context.writeln('=== FSKTM QUICK ANSWERS ===');
      final quickAnswers = knowledgeBase['quick_answers'];
      quickAnswers.forEach((key, value) {
        context.writeln('$key: $value');
      });
      context.writeln('');
    }

    // === FACULTY IDENTITY ===
    if (knowledgeBase['faculty_identity'] != null) {
      final identity = knowledgeBase['faculty_identity'];
      context.writeln('=== FACULTY IDENTITY ===');
      context.writeln('Name: ${identity['official_name']['english']}');
      context.writeln('Malay: ${identity['official_name']['malay']}');
      context.writeln('Acronym: ${identity['official_name']['acronym']}');
      context.writeln('University: ${identity['university']}');
      context.writeln('Vision: ${identity['vision']}');
      context.writeln('Mission: ${identity['mission']}');
      context
          .writeln('Strategic Direction: ${identity['strategic_direction']}');
      context.writeln('');
    }

    // === ACADEMIC PROGRAMS ===
    if (knowledgeBase['academic_programs'] != null) {
      final programs = knowledgeBase['academic_programs'];
      context.writeln('=== ACADEMIC PROGRAMS ===');

      if (programs['undergraduate'] != null) {
        context.writeln('UNDERGRADUATE PROGRAMS:');
        final undergrad = programs['undergraduate']['programs'] as List;
        for (var program in undergrad) {
          context.writeln('- ${program['name']}');
          if (program['mqa_code'] != null) {
            context.writeln('  MQA Code: ${program['mqa_code']}');
          }
        }
      }

      if (programs['postgraduate'] != null) {
        context.writeln('POSTGRADUATE PROGRAMS:');
        final postgrad = programs['postgraduate']['programs'] as List;
        for (var program in postgrad) {
          context.writeln('- ${program['name']}');
        }
      }
      context.writeln('');
    }

    // === RESEARCH EXPERTISE ===
    if (knowledgeBase['research_expertise'] != null) {
      final research = knowledgeBase['research_expertise'];
      context.writeln('=== RESEARCH EXPERTISE ===');

      if (research['research_centers'] != null) {
        context.writeln('RESEARCH CENTERS:');
        final centers = research['research_centers']['centers'] as List;
        for (var center in centers) {
          context.writeln('- ${center['name']} (${center['acronym']})');
        }
      }

      if (research['focus_groups'] != null) {
        context.writeln('FOCUS GROUPS:');
        final groups = research['focus_groups']['groups'] as List;
        for (var group in groups) {
          context.writeln('- ${group['name']} (${group['acronym']})');
        }
      }
      context.writeln('');
    }

    // === CONTACT INFORMATION ===
    if (knowledgeBase['contact_information'] != null) {
      final contact = knowledgeBase['contact_information']['main_office'];
      context.writeln('=== CONTACT INFORMATION ===');
      context.writeln('Address: ${contact['address']}');
      context.writeln('Phone: ${contact['phone']}');
      context.writeln('Email: ${contact['email']}');
      context.writeln('Website: ${contact['website']}');
      context.writeln('');
    }

    // === STAFF DIRECTORY (from original data) ===
    final facultyInfo = staffData['faculty_info'];
    context.writeln('=== STAFF DIRECTORY ===');
    context.writeln('Total Staff: ${facultyInfo['total_staff']}');

    // Add departments
    final departments = staffData['departments'] as List;
    context.writeln('DEPARTMENTS:');
    for (var dept in departments) {
      context.writeln('- ${dept['name']} (${dept['name_en']})');
    }

    // Add ALL staff members (not just first 10) for better AI search
    context.writeln('STAFF MEMBERS:');
    final staff = staffData['staff'] as List;
    for (var member in staff) {
      context.writeln('${member['name']} - ${member['title']}');
      context.writeln('Department: ${member['department']}');
      context.writeln('Email: ${member['email']}');
      if (member['specialization'] != null) {
        context.writeln('Expertise: ${member['specialization']}');
      }
      context.writeln('---');
    }
    context.writeln('[Total: ${staff.length} staff members]');

    return context.toString();
  }

  /// ENHANCED: Generate optimized context dengan smart retrieval + CHUNKING
  /// Uses chunk-based retrieval for better relevance
  static Future<String> getFSKTMContextForAIWithQuery(String query) async {
    final staffData = await loadStaffData();
    final knowledgeBase = await loadKnowledgeBase();

    final StringBuffer context = StringBuffer();
    final lowerQuery = query.toLowerCase();

    // FEATURE 1: Expand query dengan sinonim untuk better matching
    final expandedQuery = expandQueryWithSynonyms(lowerQuery);
    debugPrint('RAG Query Expansion: "$lowerQuery" → "$expandedQuery"');

    // FEATURE 6: Use chunk-based retrieval for better relevance
    final relevantChunks = await getRelevantChunks(expandedQuery, maxChunks: 8);
    debugPrint('RAG Chunking: Found ${relevantChunks.length} relevant chunks');

    // Add relevant chunks to context
    if (relevantChunks.isNotEmpty) {
      context.writeln(
          '=== MAKLUMAT BERKAITAN (dari ${relevantChunks.length} sumber) ===');
      for (final chunk in relevantChunks) {
        context.writeln(chunk.content);
        context.writeln('---');
      }
      context.writeln('');
    }

    // Determine query intent for smart context selection (use expanded query)
    final queryIntent = _detectQueryIntent(expandedQuery);

    // === ALWAYS INCLUDE: Quick Answers (essential info) ===
    if (knowledgeBase['quick_answers'] != null) {
      context.writeln('=== FSKTM INFO PANTAS ===');
      final quickAnswers =
          knowledgeBase['quick_answers'] as Map<String, dynamic>;

      // Only include relevant quick answers based on query
      if (_isContactQuery(expandedQuery)) {
        context.writeln('Telefon: ${quickAnswers['phone']}');
        context.writeln('Email: ${quickAnswers['email']}');
        context.writeln('Alamat: ${quickAnswers['address']}');
      } else if (_isStatsQuery(expandedQuery)) {
        context.writeln('Jumlah Pelajar: ${quickAnswers['total_students']}');
        context
            .writeln('Jumlah Akademik: ${quickAnswers['total_academicians']}');
        context.writeln('Jumlah Program: ${quickAnswers['total_programs']}');
      } else {
        // Include all quick answers for general queries
        quickAnswers.forEach((key, value) {
          context.writeln('$key: $value');
        });
      }
      context.writeln('');
    }

    // === FACULTY IDENTITY (if asking about faculty) ===
    if (queryIntent.contains('faculty') || queryIntent.contains('general')) {
      if (knowledgeBase['faculty_identity'] != null) {
        final identity = knowledgeBase['faculty_identity'];
        context.writeln('=== IDENTITI FAKULTI ===');
        context.writeln('Nama: ${identity['official_name']['malay']}');
        context.writeln('English: ${identity['official_name']['english']}');
        context.writeln('Singkatan: ${identity['official_name']['acronym']}');
        context.writeln('Universiti: ${identity['university']}');
        if (identity['vision'] != null) {
          context.writeln('Visi: ${identity['vision']}');
        }
        context.writeln('');
      }
    }

    // === ACADEMIC PROGRAMS (if asking about programs/courses) ===
    if (queryIntent.contains('program') || queryIntent.contains('course')) {
      if (knowledgeBase['academic_programs'] != null) {
        final programs = knowledgeBase['academic_programs'];
        context.writeln('=== PROGRAM AKADEMIK ===');

        if (programs['undergraduate'] != null) {
          context.writeln('SARJANA MUDA:');
          final undergrad = programs['undergraduate']['programs'] as List;
          for (var program in undergrad) {
            context.writeln('- ${program['title'] ?? program['name']}');
          }
        }

        if (programs['postgraduate'] != null && _isPostgradQuery(lowerQuery)) {
          context.writeln('PASCA SISWAZAH:');
          final postgrad = programs['postgraduate']['programs'] as List;
          for (var program in postgrad) {
            context.writeln('- ${program['title'] ?? program['name']}');
          }
        }
        context.writeln('');
      }
    }

    // === RESEARCH (if asking about research) ===
    if (queryIntent.contains('research')) {
      if (knowledgeBase['research_expertise'] != null) {
        final research = knowledgeBase['research_expertise'];
        context.writeln('=== PENYELIDIKAN ===');

        if (research['research_centers'] != null) {
          context.writeln('PUSAT PENYELIDIKAN:');
          final centers = research['research_centers']['centers'] as List;
          for (var center in centers) {
            context.writeln('- ${center['name']} (${center['acronym']})');
          }
        }

        if (research['focus_groups'] != null) {
          context.writeln('KUMPULAN FOKUS:');
          final groups = research['focus_groups']['groups'] as List;
          for (var group in groups) {
            context.writeln('- ${group['name']} (${group['acronym']})');
          }
        }
        context.writeln('');
      }
    }

    // === STAFF DIRECTORY (smart retrieval) ===
    final staff = staffData['staff'] as List;
    final departments = staffData['departments'] as List;

    // Add departments list
    context.writeln('=== JABATAN ===');
    for (var dept in departments) {
      context.writeln('- ${dept['name']} (${dept['name_en']})');
    }
    context.writeln('');

    // Smart staff search - use EXPANDED query untuk better matching
    final relevantStaff = _findRelevantStaff(staff, expandedQuery);

    if (relevantStaff.isNotEmpty) {
      // User mentioned specific staff/department - show detailed info
      context.writeln('=== STAFF BERKAITAN ===');
      for (var member in relevantStaff.take(3)) {
        // Limit to top 3
        context.writeln('**${member['name']}**');
        context.writeln('Jawatan: ${member['title']}');
        context.writeln('Jabatan: ${member['department']}');
        context.writeln('Email: ${member['email']}');
        if (member['specialization'] != null) {
          context.writeln('Kepakaran: ${member['specialization']}');
        }
        context.writeln('---');
      }
    } else if (queryIntent.contains('staff') ||
        queryIntent.contains('lecturer')) {
      // General staff query - show compact list
      context.writeln(
          '=== SENARAI STAFF (menunjukkan 3 daripada ${staff.length} orang) ===');
      for (var member in staff.take(3)) {
        context.writeln(
            '${member['name']} | ${member['title']} | ${member['email']}');
      }
    } else {
      // Non-staff query - just show count
      context.writeln('Jumlah Staff: ${staff.length} orang');
      context.writeln(
          '[Untuk maklumat staff, sebut nama atau jabatan dalam soalan]');
    }

    return context.toString();
  }

  /// Detect query intent for smart context selection
  static Set<String> _detectQueryIntent(String query) {
    final intents = <String>{};

    // Staff/Lecturer queries
    if (query.contains(RegExp(
        r'staff|lecturer|pensyarah|professor|prof|dr\.|ketua|dekan|siapa'))) {
      intents.add('staff');
      intents.add('lecturer');
    }

    // Program/Course queries
    if (query.contains(RegExp(
        r'program|course|kursus|degree|ijazah|sarjana|bachelor|master|phd'))) {
      intents.add('program');
      intents.add('course');
    }

    // Research queries
    if (query.contains(RegExp(
        r'research|penyelidikan|center|pusat|focus|group|kepakaran|expertise'))) {
      intents.add('research');
    }

    // Faculty info queries
    if (query.contains(RegExp(
        r'fsktm|fakulti|faculty|uthm|visi|misi|vision|mission|apa itu'))) {
      intents.add('faculty');
    }

    // Contact queries
    if (query.contains(
        RegExp(r'contact|telefon|phone|email|alamat|address|hubungi'))) {
      intents.add('contact');
    }

    // If no specific intent, treat as general query
    if (intents.isEmpty) {
      intents.add('general');
    }

    return intents;
  }

  // ============== FUZZY MATCHING: Levenshtein Distance ==============
  /// Calculate Levenshtein distance between two strings
  /// Returns edit distance (0 = exact match, higher = more different)
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prevRow = List.generate(s2.length + 1, (i) => i);
    List<int> currRow = List.filled(s2.length + 1, 0);

    for (int i = 1; i <= s1.length; i++) {
      currRow[0] = i;
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        currRow[j] = [
          prevRow[j] + 1, // deletion
          currRow[j - 1] + 1, // insertion
          prevRow[j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
      // Swap rows
      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
    }

    return prevRow[s2.length];
  }

  /// Calculate fuzzy match score (0.0 - 1.0, higher = better match)
  static double _fuzzyMatchScore(String query, String target) {
    if (query.isEmpty || target.isEmpty) return 0.0;

    final distance = _levenshteinDistance(query, target);
    final maxLength =
        query.length > target.length ? query.length : target.length;

    // Convert distance to similarity score (0-1)
    return 1.0 - (distance / maxLength);
  }

  /// Find relevant staff based on query with IMPROVED FUZZY MATCHING
  static List<Map<String, dynamic>> _findRelevantStaff(
      List staff, String query) {
    final results = <Map<String, dynamic>>[];
    final queryWords = query.split(RegExp(r'\s+'));

    for (var member in staff) {
      final name = member['name'].toString().toLowerCase();
      final department = member['department'].toString().toLowerCase();
      final title = member['title'].toString().toLowerCase();
      double matchScore = 0.0;

      // IMPROVED: Direct substring check first (most reliable)
      // Check if ANY query word is contained in staff name
      for (final queryWord in queryWords) {
        if (queryWord.length < 3) continue;

        // Direct substring match (e.g., "muhaini" in "Dr. Muhaini binti...")
        if (name.contains(queryWord)) {
          matchScore += 2.0; // High score for direct match
          debugPrint('Direct match: "$queryWord" found in "$name"');
          continue;
        }
      }

      // Check name match (exact partial OR fuzzy)
      final nameParts = name.split(' ');
      for (final namePart in nameParts) {
        if (namePart.length < 3) continue;

        // Reverse check: if name part contains query word
        for (final queryWord in queryWords) {
          if (queryWord.length < 3) continue;

          // Name contains query (e.g., "muhaimin" contains "muhai")
          if (namePart.contains(queryWord)) {
            matchScore += 1.5;
            continue;
          }

          // Query contains name part (existing logic)
          if (query.contains(namePart)) {
            matchScore += 1.0;
            continue;
          }

          // Fuzzy match with LOWER threshold (0.5 instead of 0.7)
          final fuzzyScore = _fuzzyMatchScore(queryWord, namePart);
          if (fuzzyScore >= 0.5) {
            // 50% similarity threshold (was 70%)
            matchScore += fuzzyScore;
            debugPrint(
                'Fuzzy match: "$queryWord" ≈ "$namePart" (score: ${fuzzyScore.toStringAsFixed(2)})');
          }
        }
      }

      // Check department match
      final deptMatch = query.contains('kejuruteraan perisian') &&
              department.contains('kejuruteraan perisian') ||
          query.contains('software') && department.contains('perisian') ||
          query.contains('multimedia') && department.contains('multimedia') ||
          query.contains('keselamatan') && department.contains('keselamatan') ||
          query.contains('security') && department.contains('keselamatan') ||
          query.contains('web') && department.contains('web');

      if (deptMatch) matchScore += 0.8;

      // Check title match
      final titleMatch =
          query.contains('profesor') && title.contains('profesor') ||
              query.contains('professor') && title.contains('profesor') ||
              query.contains('dekan') && title.contains('dekan') ||
              query.contains('ketua') && title.contains('ketua');

      if (titleMatch) matchScore += 0.5;

      // Add to results if any match found
      if (matchScore > 0) {
        // Store match score for sorting
        final memberWithScore = Map<String, dynamic>.from(member as Map);
        memberWithScore['_matchScore'] = matchScore;
        results.add(memberWithScore);
      }
    }

    // Sort by match score (highest first) - for Relevance Scoring feature
    results.sort((a, b) =>
        (b['_matchScore'] as double).compareTo(a['_matchScore'] as double));

    return results;
  }

  /// Check if query is about contact info
  static bool _isContactQuery(String query) {
    return query.contains(
        RegExp(r'contact|telefon|phone|email|alamat|address|hubungi|call'));
  }

  /// Check if query is about statistics
  static bool _isStatsQuery(String query) {
    return query.contains(RegExp(r'berapa|how many|jumlah|total|ramai|banyak'));
  }

  /// Check if query is about postgraduate programs
  static bool _isPostgradQuery(String query) {
    return query.contains(
        RegExp(r'master|phd|pasca|postgrad|doctorate|sarjana(?! muda)'));
  }

  /// ENHANCED: Search staff by name (unchanged - works with staff data)
  static Future<List<Map<String, dynamic>>> searchStaffByName(
      String query) async {
    final data = await loadStaffData();
    final staff = data['staff'] as List;

    final lowerQuery = query.toLowerCase();
    return staff
        .where((member) {
          final name = member['name'].toString().toLowerCase();
          return name.contains(lowerQuery);
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// ENHANCED: Search staff by department (unchanged)
  static Future<List<Map<String, dynamic>>> searchStaffByDepartment(
      String department) async {
    final data = await loadStaffData();
    final staff = data['staff'] as List;

    final lowerDept = department.toLowerCase();
    return staff
        .where((member) {
          final memberDept = member['department'].toString().toLowerCase();
          return memberDept.contains(lowerDept);
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// NEW: Search academic programs
  static Future<List<Map<String, dynamic>>> searchPrograms(String query) async {
    final kb = await loadKnowledgeBase();
    final programs = <Map<String, dynamic>>[];

    final lowerQuery = query.toLowerCase();

    // Search undergraduate programs
    if (kb['academic_programs']['undergraduate'] != null) {
      final undergrad =
          kb['academic_programs']['undergraduate']['programs'] as List;
      for (var program in undergrad) {
        if (program['name'].toString().toLowerCase().contains(lowerQuery)) {
          programs.add({...program, 'level': 'Undergraduate'});
        }
      }
    }

    // Search postgraduate programs
    if (kb['academic_programs']['postgraduate'] != null) {
      final postgrad =
          kb['academic_programs']['postgraduate']['programs'] as List;
      for (var program in postgrad) {
        if (program['name'].toString().toLowerCase().contains(lowerQuery)) {
          programs.add({...program, 'level': 'Postgraduate'});
        }
      }
    }

    return programs;
  }

  /// NEW: Get quick answer for common queries
  static Future<String?> getQuickAnswer(String query) async {
    final kb = await loadKnowledgeBase();
    final quickAnswers = kb['quick_answers'];

    final lowerQuery = query.toLowerCase();

    // Direct matches
    for (String key in quickAnswers.keys) {
      if (lowerQuery.contains(key.toLowerCase())) {
        return quickAnswers[key];
      }
    }

    // Fuzzy matches for common terms
    if (lowerQuery.contains('phone') ||
        lowerQuery.contains('telefon') ||
        lowerQuery.contains('contact')) {
      return quickAnswers['phone'];
    }
    if (lowerQuery.contains('email') || lowerQuery.contains('emel')) {
      return quickAnswers['email'];
    }
    if (lowerQuery.contains('address') || lowerQuery.contains('alamat')) {
      return quickAnswers['address'];
    }
    if (lowerQuery.contains('student') && lowerQuery.contains('total')) {
      return '${quickAnswers['total_students']} students in FSKTM';
    }

    return null;
  }

  /// ENHANCED: Get comprehensive faculty statistics
  static Future<Map<String, dynamic>> getFacultyStats() async {
    final staffData = await loadStaffData();
    final kb = await loadKnowledgeBase();

    final staff = staffData['staff'] as List;
    final departments = staffData['departments'] as List;

    // Count staff by department
    Map<String, int> staffByDept = {};
    for (var member in staff) {
      final dept = member['department'];
      staffByDept[dept] = (staffByDept[dept] ?? 0) + 1;
    }

    final quickAnswers = kb['quick_answers'];

    return {
      'total_staff': staff.length,
      'total_departments': departments.length,
      'total_students': quickAnswers['total_students'],
      'total_academicians': quickAnswers['total_academicians'],
      'total_programs': quickAnswers['total_programs'],
      'staff_by_department': staffByDept,
      'faculty_name': staffData['faculty_info']['name'],
      'university': staffData['faculty_info']['university'],
    };
  }

  /// ENHANCED: Check if query is UTHM faculty-related (FSKTM, FKAAB, etc.)
  static bool isFSKTMQuery(String query) {
    return isUTHMFacultyQuery(query);
  }

  /// Check if query is related to any UTHM faculty (FSKTM, FKAAB)
  static bool isUTHMFacultyQuery(String query) {
    final lowerQuery = query.toLowerCase();

    final uthmKeywords = [
      // ===========================================
      // Generic Staff & People - COMPREHENSIVE
      // ===========================================
      'staff', 'lecturer', 'professor', 'dr.', 'dr ', 'prof.', 'prof ',
      'pensyarah', 'dekan', 'dean', 'ketua jabatan', 'head of department',
      'siapa', 'sapa', 'sape', 'who is', 'who', 'whos',
      'cikgu', 'encik', 'puan', 'tuan', 'ts.', 'ts ', 'en.', 'pn.',
      'kakitangan', 'staf', 'pekerja', 'orang', 'lecturers', 'lec',
      'doc', 'doktor', 'pengarah', 'director',

      // ===========================================
      // FSKTM specific
      // ===========================================
      'fsktm', 'fskpm', 'fakulti sains komputer', 'faculty of computer science',
      'multimedia', 'kejuruteraan perisian', 'software engineering',
      'keselamatan maklumat', 'information security', 'sains komputer',
      'computer science', 'teknologi web', 'web technology', 'it faculty',

      // ===========================================
      // FKAAB specific
      // ===========================================
      'fkaab', 'kejuruteraan awam', 'civil engineering', 'alam bina',
      'built environment', 'senibina', 'architecture', 'struktur',
      'geoteknik', 'hidrologi', 'pembinaan', 'construction', 'civil',

      // ===========================================
      // FKEE specific
      // ===========================================
      'fkee', 'kejuruteraan elektrik', 'electrical engineering',
      'kejuruteraan elektronik', 'electronic engineering',
      'elektrik', 'elektronik', 'elektrikal', 'power system',
      'sistem kuasa', 'robotik', 'robotics', 'automation', 'automasi',

      // ===========================================
      // General Faculty & Organization
      // ===========================================
      'jabatan', 'jab', 'department', 'dept', 'uthm', 'universiti tun hussein',
      'fakulti', 'fak', 'faculty', 'fac', 'bahagian', 'unit',

      // ===========================================
      // Academic Programs
      // ===========================================
      'program', 'course', 'kursus', 'degree', 'bachelor', 'master', 'phd',
      'ijazah', 'sarjana muda', 'sarjana', 'kedoktoran', 'diploma',
      'subjek', 'class', 'kelas', 'postgrad', 'undergraduate',

      // ===========================================
      // Contact & Information
      // ===========================================
      'email', 'emel', 'mail', 'contact', 'phone', 'telefon', 'tel', 'fon',
      'alamat', 'address', 'lokasi', 'location', 'tempat', 'kat mana',
      'kt mane',
      'website', 'web', 'portal', 'vision', 'mission', 'visi', 'misi',
      'office', 'pejabat', 'bilik', 'room', 'hp', 'nombor', 'number',

      // ===========================================
      // Query Patterns - CASUAL BM SLANG
      // ===========================================
      'siapa lecturer', 'sapa lec', 'sape cikgu',
      'berapa ramai', 'brapa', 'bape', 'brp', 'how many',
      'senarai', 'list', 'cari', 'carik', 'cr', 'find', 'search',
      'what is', 'apa itu', 'ape tu', 'apetu',
      'mana', 'dmn', 'dimana', 'di mana', 'where',
      'kenapa', 'knp', 'nape', 'why',
      'macam mana', 'mcm mane', 'camne', 'cmne', 'how to',
      'tolong', 'tlg', 'pls', 'help', 'bantu',
      'boleh', 'bole', 'blh', 'can',
      'nak', 'nk', 'want', 'mahu',
      'ada', 'ade', 'have', 'got',

      // ===========================================
      // Research
      // ===========================================
      'research', 'penyelidikan', 'kajian', 'center', 'pusat',
      'kepakaran', 'expertise', 'pakar', 'expert', 'r&d', 'rnd',

      // ===========================================
      // Common Names/Titles Patterns
      // ===========================================
      'nama', 'name', 'info', 'maklumat', 'tentang', 'about',
    ];

    return uthmKeywords.any((keyword) => lowerQuery.contains(keyword));
  }

  /// LEGACY: Maintain backward compatibility
  static Future<Map<String, dynamic>> loadFSKTMData() async {
    return await loadStaffData();
  }

  /// Default staff data fallback
  static Map<String, dynamic> _getDefaultStaffData() {
    return {
      'faculty_info': {
        'name': 'Fakulti Sains Komputer dan Teknologi Maklumat',
        'acronym': 'FSKTM',
        'university': 'Universiti Tun Hussein Onn Malaysia (UTHM)',
        'total_staff': 0,
      },
      'departments': [],
      'staff': [],
    };
  }

  /// Default knowledge base fallback
  static Map<String, dynamic> _getDefaultKnowledgeBase() {
    return {
      'knowledge_base_info': {'title': 'FSKTM Knowledge Base'},
      'quick_answers': {
        'phone': '+607 453 3606',
        'email': 'fsktm@uthm.edu.my',
        'what_is_fsktm':
            'Faculty of Computer Science and Information Technology, UTHM'
      },
      'faculty_identity': {},
      'academic_programs': {},
      'research_expertise': {},
      'contact_information': {},
    };
  }
}

/// Document chunk model for RAG chunking strategy
class DocumentChunk {
  final String id;
  final String category;
  final List<String> keywords;
  final String content;

  DocumentChunk({
    required this.id,
    required this.category,
    required this.keywords,
    required this.content,
  });

  @override
  String toString() =>
      'Chunk[$category]: ${content.substring(0, content.length.clamp(0, 50))}...';
}
