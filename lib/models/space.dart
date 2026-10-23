/// Chủ đề nhỏ: đây là thứ được lưu vào bài đăng (spaceId).
class Space {
  final String id; // lưu vào Firestore, KHÔNG đổi sau khi đã có bài đăng
  final String name; // tên tiếng Việt
  final String emoji;
  final String? nameEn; // tên tiếng Anh (tùy chọn)

  const Space(this.id, this.name, this.emoji, {this.nameEn});

  String label(bool isEnglish) =>
      (isEnglish && nameEn != null) ? nameEn! : name;
}

/// Chủ đề lớn: chỉ dùng để gom nhóm trên giao diện, KHÔNG lưu vào bài đăng.
class SpaceGroup {
  final String id;
  final String name;
  final String emoji;
  final String? nameEn;
  final List<Space> children;

  const SpaceGroup(
    this.id,
    this.name,
    this.emoji,
    this.children, {
    this.nameEn,
  });

  String label(bool isEnglish) =>
      (isEnglish && nameEn != null) ? nameEn! : name;

  /// Danh sách id chủ đề nhỏ, dùng để lọc bài cả nhóm
  /// (Firestore: where('spaceId', whereIn: group.childIds), tối đa 30 id).
  List<String> get childIds => [for (final s in children) s.id];
}

const spaceGroups = <SpaceGroup>[
  SpaceGroup('g_study', 'Học tập & Kiến thức', '📚', nameEn: 'Learning', [
    Space('study', 'Học tập chung', '📚', nameEn: 'Study'),
    Space('languages', 'Ngoại ngữ', '🌐', nameEn: 'Languages'),
    Space('exams', 'Thi cử & Du học', '🎓', nameEn: 'Exams & Studying abroad'),
    Space('science', 'Khoa học', '🔬', nameEn: 'Science'),
    Space('math', 'Toán & Logic', '➗', nameEn: 'Math & Logic'),
    Space('skills', 'Kỹ năng mềm', '🗣️', nameEn: 'Soft skills'),
  ]),
  SpaceGroup('g_tech', 'Công nghệ & Công việc', '💻', nameEn: 'Tech & Work', [
    Space('tech', 'Công nghệ', '💻', nameEn: 'Technology'),
    Space('coding', 'Lập trình', '👨‍💻', nameEn: 'Coding'),
    Space('ai', 'Trí tuệ nhân tạo', '🤖', nameEn: 'AI'),
    Space('career', 'Việc làm & Sự nghiệp', '💼', nameEn: 'Career'),
    Space('business', 'Kinh doanh & Khởi nghiệp', '📈', nameEn: 'Business'),
    Space('finance', 'Tài chính & Đầu tư', '💰', nameEn: 'Finance & Investing'),
    Space(
      'marketing',
      'Marketing & Bán hàng',
      '📣',
      nameEn: 'Marketing & Sales',
    ),
  ]),
  SpaceGroup('g_entertain', 'Giải trí', '🎬', nameEn: 'Entertainment', [
    Space('music', 'Âm nhạc', '🎵', nameEn: 'Music'),
    Space('movies', 'Phim ảnh', '🎬', nameEn: 'Movies & TV'),
    Space('books', 'Sách & Văn học', '📖', nameEn: 'Books'),
    Space('gaming', 'Game', '🎮', nameEn: 'Gaming'),
    Space('anime', 'Anime & Truyện tranh', '🎌', nameEn: 'Anime & Comics'),
    Space('humor', 'Hài hước', '😂', nameEn: 'Humor'),
    Space('celeb', 'Showbiz & Người nổi tiếng', '🌟', nameEn: 'Celebrities'),
  ]),
  SpaceGroup('g_sports', 'Thể thao', '⚽', nameEn: 'Sports', [
    Space('football', 'Bóng đá', '⚽', nameEn: 'Football'),
    Space('basketball', 'Bóng rổ', '🏀', nameEn: 'Basketball'),
    Space('volleyball', 'Bóng chuyền', '🏐', nameEn: 'Volleyball'),
    Space('badminton', 'Cầu lông & Tennis', '🏸', nameEn: 'Badminton & Tennis'),
    Space('running', 'Chạy bộ & Đạp xe', '🏃', nameEn: 'Running & Cycling'),
    Space('swimming', 'Bơi lội', '🏊', nameEn: 'Swimming'),
    Space('gym', 'Gym & Thể hình', '💪', nameEn: 'Gym & Fitness'),
    Space('martial', 'Võ thuật', '🥋', nameEn: 'Martial arts'),
    Space('esports', 'Thể thao điện tử', '🕹️', nameEn: 'Esports'),
  ]),
  SpaceGroup('g_food', 'Ẩm thực', '🍜', nameEn: 'Food & Drink', [
    Space('cooking', 'Nấu ăn', '🍜', nameEn: 'Cooking'),
    Space('baking', 'Làm bánh', '🧁', nameEn: 'Baking'),
    Space('drinks', 'Cà phê & Đồ uống', '☕', nameEn: 'Coffee & Drinks'),
    Space('streetfood', 'Ẩm thực đường phố', '🍢', nameEn: 'Street food'),
    Space('restaurant', 'Review quán ăn', '🍽️', nameEn: 'Restaurant reviews'),
    Space(
      'healthyfood',
      'Ăn healthy & Eat clean',
      '🥗',
      nameEn: 'Healthy eating',
    ),
  ]),
  SpaceGroup('g_travel', 'Du lịch', '✈️', nameEn: 'Travel', [
    Space('travel', 'Du lịch chung', '✈️', nameEn: 'Travel'),
    Space('travel_vn', 'Du lịch trong nước', '🗺️', nameEn: 'Domestic travel'),
    Space(
      'travel_world',
      'Du lịch nước ngoài',
      '🌍',
      nameEn: 'International travel',
    ),
    Space('camping', 'Phượt & Cắm trại', '⛺', nameEn: 'Backpacking & Camping'),
    Space('hotels', 'Khách sạn & Homestay', '🏨', nameEn: 'Hotels & Stays'),
  ]),
  SpaceGroup('g_creative', 'Sáng tạo', '🎨', nameEn: 'Creative', [
    Space('photo', 'Nhiếp ảnh', '📷', nameEn: 'Photography'),
    Space('video', 'Video & Dựng phim', '🎥', nameEn: 'Video & Editing'),
    Space('art', 'Vẽ & Nghệ thuật', '🎨', nameEn: 'Art & Drawing'),
    Space('design', 'Thiết kế', '✏️', nameEn: 'Design'),
    Space('writing', 'Viết lách', '✍️', nameEn: 'Writing'),
    Space(
      'musicmaking',
      'Sáng tác & Chơi nhạc cụ',
      '🎸',
      nameEn: 'Making music',
    ),
  ]),
  SpaceGroup(
    'g_maker',
    'Chế tạo & Thủ công',
    '🛠️',
    nameEn: 'Making & Crafts',
    [
      Space('maker', 'Chế tạo', '🛠', nameEn: 'Making'),
      Space('diy', 'Đồ thủ công & DIY', '🧵', nameEn: 'Crafts & DIY'),
      Space('electronics', 'Điện tử & Arduino', '🔌', nameEn: 'Electronics'),
      Space('print3d', 'In 3D', '🧊', nameEn: '3D printing'),
      Space('woodwork', 'Mộc & Cơ khí', '🪚', nameEn: 'Woodwork & Mechanics'),
    ],
  ),
  SpaceGroup('g_life', 'Đời sống', '🏡', nameEn: 'Lifestyle', [
    Space('health', 'Sức khỏe', '🩺', nameEn: 'Health'),
    Space('mental', 'Tâm lý & Tinh thần', '🧘', nameEn: 'Mind & Wellbeing'),
    Space('beauty', 'Làm đẹp', '💄', nameEn: 'Beauty'),
    Space('fashion', 'Thời trang', '👗', nameEn: 'Fashion'),
    Space('family', 'Gia đình & Con cái', '👨‍👩‍👧', nameEn: 'Family & Kids'),
    Space('love', 'Tình yêu & Hẹn hò', '❤️', nameEn: 'Love & Dating'),
    Space('pets', 'Thú cưng', '🐾', nameEn: 'Pets'),
    Space('gardening', 'Làm vườn & Cây cảnh', '🌱', nameEn: 'Gardening'),
    Space('home', 'Nhà cửa & Nội thất', '🏠', nameEn: 'Home & Decor'),
  ]),
  SpaceGroup('g_vehicles', 'Xe cộ', '🚗', nameEn: 'Vehicles', [
    Space('cars', 'Ô tô', '🚗', nameEn: 'Cars'),
    Space(
      'motorbikes',
      'Xe máy & Xe phân khối lớn',
      '🏍️',
      nameEn: 'Motorbikes',
    ),
    Space('ev', 'Xe điện', '🔋', nameEn: 'Electric vehicles'),
  ]),
  SpaceGroup(
    'g_society',
    'Xã hội & Văn hóa',
    '🌍',
    nameEn: 'Society & Culture',
    [
      Space('news', 'Tin tức', '📰', nameEn: 'News'),
      Space('history', 'Lịch sử & Văn hóa', '🏛️', nameEn: 'History & Culture'),
      Space('nature', 'Thiên nhiên & Môi trường', '🌿', nameEn: 'Nature'),
      Space('spirit', 'Tâm linh & Phong thủy', '🔮', nameEn: 'Spirituality'),
      Space('community', 'Cộng đồng & Thiện nguyện', '🤝', nameEn: 'Community'),
    ],
  ),
];

/// Danh sách phẳng mọi chủ đề nhỏ. Code cũ đang dùng defaultSpaces vẫn chạy.
final List<Space> defaultSpaces = [for (final g in spaceGroups) ...g.children];

Space? findSpace(String id) {
  for (final s in defaultSpaces) {
    if (s.id == id) return s;
  }
  return null;
}

SpaceGroup? groupOfSpace(String spaceId) {
  for (final g in spaceGroups) {
    for (final s in g.children) {
      if (s.id == spaceId) return g;
    }
  }
  return null;
}
