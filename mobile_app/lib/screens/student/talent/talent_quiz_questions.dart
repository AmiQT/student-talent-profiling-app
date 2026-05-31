/// Talent Quiz Questions Data
/// Contains all quiz questions organized by category

class QuizQuestion {
  final String id;
  final String question;
  final String category;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.options,
  });
}

class QuizOption {
  final String text;
  final int score;

  const QuizOption({required this.text, required this.score});
}

/// All quiz questions - 18 questions covering all talent categories
const List<QuizQuestion> talentQuizQuestions = [
  // ==================== SOFT SKILLS ====================

  // Communication
  QuizQuestion(
    id: 'ss_comm_1',
    question: 'Bagaimana anda berkomunikasi dalam kumpulan?',
    category: 'communication',
    options: [
      QuizOption(text: 'Saya suka bercakap dan kongsi idea', score: 5),
      QuizOption(text: 'Saya lebih suka mendengar dahulu', score: 3),
      QuizOption(text: 'Saya jarang bercakap dalam kumpulan', score: 1),
    ],
  ),

  // Leadership
  QuizQuestion(
    id: 'ss_lead_1',
    question: 'Bila ada projek kumpulan, apa peranan anda?',
    category: 'leadership',
    options: [
      QuizOption(text: 'Saya suka jadi ketua dan organize', score: 5),
      QuizOption(text: 'Saya bantu tapi tidak lead', score: 3),
      QuizOption(text: 'Saya ikut sahaja arahan', score: 1),
    ],
  ),

  // Teamwork
  QuizQuestion(
    id: 'ss_team_1',
    question: 'Bagaimana anda bekerjasama dengan orang lain?',
    category: 'teamwork',
    options: [
      QuizOption(text: 'Saya suka kerja berpasukan', score: 5),
      QuizOption(text: 'Boleh kerja solo atau berpasukan', score: 3),
      QuizOption(text: 'Lebih suka kerja sendiri', score: 1),
    ],
  ),

  // ==================== PERFORMING ARTS ====================

  QuizQuestion(
    id: 'pa_music_1',
    question: 'Adakah anda berminat dengan muzik?',
    category: 'performingArts',
    options: [
      QuizOption(text: 'Ya! Saya main alat muzik atau menyanyi', score: 5),
      QuizOption(text: 'Saya suka dengar muzik sahaja', score: 3),
      QuizOption(text: 'Tidak berminat dengan muzik', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'pa_dance_1',
    question: 'Bagaimana dengan aktiviti tarian?',
    category: 'performingArts',
    options: [
      QuizOption(text: 'Saya aktif menari (tradisional/moden)', score: 5),
      QuizOption(text: 'Saya berminat tapi tak aktif', score: 3),
      QuizOption(text: 'Tidak berminat dengan tarian', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'pa_drama_1',
    question: 'Pernahkah anda terlibat dalam drama atau teater?',
    category: 'performingArts',
    options: [
      QuizOption(text: 'Ya, saya suka berlakon!', score: 5),
      QuizOption(text: 'Pernah cuba sekali dua', score: 3),
      QuizOption(text: 'Tidak pernah dan tidak berminat', score: 1),
    ],
  ),

  // ==================== VISUAL ARTS ====================

  QuizQuestion(
    id: 'va_art_1',
    question: 'Adakah anda suka melukis atau design?',
    category: 'visualArts',
    options: [
      QuizOption(text: 'Ya! Saya suka seni lukis/digital art', score: 5),
      QuizOption(text: 'Kadang-kadang sahaja', score: 3),
      QuizOption(text: 'Tidak berminat dalam seni visual', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'va_photo_1',
    question: 'Bagaimana dengan fotografi atau videografi?',
    category: 'visualArts',
    options: [
      QuizOption(text: 'Saya aktif dalam fotografi/video', score: 5),
      QuizOption(text: 'Suka ambil gambar casual sahaja', score: 3),
      QuizOption(text: 'Tidak berminat', score: 1),
    ],
  ),

  // ==================== SPORTS ====================

  QuizQuestion(
    id: 'sp_team_1',
    question: 'Adakah anda aktif dalam sukan berpasukan?',
    category: 'sports',
    options: [
      QuizOption(text: 'Ya! Futsal/bola/basket/dll', score: 5),
      QuizOption(text: 'Kadang-kadang main santai', score: 3),
      QuizOption(text: 'Tidak aktif dalam sukan', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'sp_ind_1',
    question: 'Bagaimana dengan sukan individu?',
    category: 'sports',
    options: [
      QuizOption(text: 'Aktif (badminton/renang/gym/dll)', score: 5),
      QuizOption(text: 'Sesekali bersenam', score: 3),
      QuizOption(text: 'Jarang bersenam', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'sp_esports_1',
    question: 'Adakah anda bermain e-sports secara kompetitif?',
    category: 'sports',
    options: [
      QuizOption(text: 'Ya, saya join tournament!', score: 5),
      QuizOption(text: 'Main game tapi tidak kompetitif', score: 3),
      QuizOption(text: 'Tidak bermain game', score: 1),
    ],
  ),

  // ==================== LANGUAGE & LITERATURE ====================

  QuizQuestion(
    id: 'll_speak_1',
    question: 'Adakah anda suka public speaking atau debate?',
    category: 'languageLiterature',
    options: [
      QuizOption(text: 'Ya! Saya suka bercakap depan orang', score: 5),
      QuizOption(text: 'Boleh tapi tak suka sangat', score: 3),
      QuizOption(text: 'Takut bercakap di khalayak', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'll_write_1',
    question: 'Bagaimana dengan menulis (puisi/cerpen/blog)?',
    category: 'languageLiterature',
    options: [
      QuizOption(text: 'Saya suka menulis kreatif!', score: 5),
      QuizOption(text: 'Tulis bila perlu sahaja', score: 3),
      QuizOption(text: 'Tidak suka menulis', score: 1),
    ],
  ),

  // ==================== TECHNICAL HOBBIES ====================

  QuizQuestion(
    id: 'th_code_1',
    question: 'Adakah anda berminat dengan programming/coding?',
    category: 'technicalHobbies',
    options: [
      QuizOption(text: 'Ya! Saya suka coding', score: 5),
      QuizOption(text: 'Ada basic tapi tak sangat aktif', score: 3),
      QuizOption(text: 'Tidak berminat dalam coding', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'th_robot_1',
    question: 'Bagaimana dengan robotik atau electronics?',
    category: 'technicalHobbies',
    options: [
      QuizOption(text: 'Saya suka bina robot/gadget!', score: 5),
      QuizOption(text: 'Berminat tapi tak pernah cuba', score: 3),
      QuizOption(text: 'Tidak berminat', score: 1),
    ],
  ),

  // ==================== COMMUNITY & SOCIAL ====================

  QuizQuestion(
    id: 'cs_vol_1',
    question: 'Adakah anda aktif dalam aktiviti sukarelawan?',
    category: 'communitySocial',
    options: [
      QuizOption(text: 'Ya! Saya suka bantu komuniti', score: 5),
      QuizOption(text: 'Sesekali join program', score: 3),
      QuizOption(text: 'Tidak pernah terlibat', score: 1),
    ],
  ),

  QuizQuestion(
    id: 'cs_entre_1',
    question: 'Adakah anda berminat dalam keusahawanan?',
    category: 'communitySocial',
    options: [
      QuizOption(text: 'Ya! Saya ada/nak mulakan bisnes', score: 5),
      QuizOption(text: 'Berminat tapi belum cuba', score: 3),
      QuizOption(text: 'Tidak berminat dalam bisnes', score: 1),
    ],
  ),
];

/// Category display info
const Map<String, Map<String, String>> categoryInfo = {
  'communication': {
    'name': 'Komunikasi',
    'icon': '💬',
    'color': '#3B82F6',
  },
  'leadership': {
    'name': 'Kepimpinan',
    'icon': '👑',
    'color': '#F59E0B',
  },
  'teamwork': {
    'name': 'Kerja Berpasukan',
    'icon': '🤝',
    'color': '#10B981',
  },
  'performingArts': {
    'name': 'Seni Persembahan',
    'icon': '🎭',
    'color': '#EC4899',
  },
  'visualArts': {
    'name': 'Seni Visual',
    'icon': '🎨',
    'color': '#8B5CF6',
  },
  'sports': {
    'name': 'Sukan',
    'icon': '⚽',
    'color': '#EF4444',
  },
  'languageLiterature': {
    'name': 'Bahasa & Sastera',
    'icon': '📚',
    'color': '#06B6D4',
  },
  'technicalHobbies': {
    'name': 'Hobi Teknikal',
    'icon': '🔧',
    'color': '#6366F1',
  },
  'communitySocial': {
    'name': 'Komuniti & Sosial',
    'icon': '🌱',
    'color': '#22C55E',
  },
};
