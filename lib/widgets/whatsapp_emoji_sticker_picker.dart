import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class WhatsAppStickerItem {
  final String emoji;
  final String title;
  final String pack;
  final Color? accentColor;

  const WhatsAppStickerItem({
    required this.emoji,
    required this.title,
    required this.pack,
    this.accentColor,
  });
}

class WhatsAppStickerPack {
  final String name;
  final String icon;
  final List<WhatsAppStickerItem> stickers;

  const WhatsAppStickerPack({
    required this.name,
    required this.icon,
    required this.stickers,
  });
}

class WhatsAppEmojiStickerPicker extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<WhatsAppStickerItem> onStickerSelected;
  final VoidCallback onBackspace;
  final double height;

  const WhatsAppEmojiStickerPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onStickerSelected,
    required this.onBackspace,
    this.height = 310,
  });

  @override
  State<WhatsAppEmojiStickerPicker> createState() => _WhatsAppEmojiStickerPickerState();
}

class _WhatsAppEmojiStickerPickerState extends State<WhatsAppEmojiStickerPicker> {
  // 0 = Emoji, 1 = Stickers
  int _activeTab = 0;
  int _activeEmojiCategory = 0;
  int _activeStickerPack = 0;

  static const List<Map<String, dynamic>> _emojiCategories = [
    {
      'name': 'Smileys',
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'emojis': [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥲', '🥹',
        '☺️', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘',
        '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐',
        '🤓', '😎', '🥸', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟',
        '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭',
        '😮‍💨', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱',
        '😨', '😰', '😥', '😓', '🫣', '🫡', '🫠', '🤔', '🫣', '🤭',
      ],
    },
    {
      'name': 'Gestures',
      'icon': Icons.pan_tool_alt_rounded,
      'emojis': [
        '👍', '👎', '👊', '✊', '🤛', '🤜', '👏', '🙌', '👐', '🤲',
        '🤝', '🙏', '✍️', '💅', '🤳', '💪', '🦾', '🦿', '🦵', '🦶',
        '👂', '🦻', '👃', '🧠', '🫀', '🫁', '🦷', '🦴', '👀', '👁️',
        '👅', '👄', '🫦', '👶', '🧒', '👦', '👧', '🧑', '👱', '👨',
        '🧔', '🧔‍♂️', '🧔‍♀️', '👨‍🦰', '👨‍🦱', '👨‍🦳', '👨‍🦲', '👩', '👩‍🦰', '🧑‍🦰',
        '👩‍🦱', '🧑‍🦱', '👩‍🦳', '🧑‍🦳', '👩‍🦲', '🧑‍🦲', '👱‍♀️', '👱‍♂️', '🧓', '👴',
      ],
    },
    {
      'name': 'Animals',
      'icon': Icons.pets_rounded,
      'emojis': [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨',
        '🐯', '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊',
        '🐒', '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉',
        '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🪱', '🐛', '🦋', '🐌',
        '🐞', '🐜', '🪰', '🪲', '🪳', '🦟', '🦗', '🕷️', '🕸️', '🦂',
        '🐢', '🐍', '🦎', '🦖', '🦕', '🐙', '🦑', '🦐', '🦞', '🦀',
        '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🦭', '🐊', '🐅',
      ],
    },
    {
      'name': 'Food',
      'icon': Icons.fastfood_rounded,
      'emojis': [
        '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
        '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
        '🥦', '🥬', '🥒', '🌶️', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅',
        '🥔', '🍠', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳',
        '🧈', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🦴', '🌭', '🍔',
        '🍟', '🍕', '🫓', '🥪', '🥙', '🧆', '🌮', '🌯', '🫔', '🥗',
        '🥘', '🫕', '🥫', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟',
      ],
    },
    {
      'name': 'Activities',
      'icon': Icons.sports_soccer_rounded,
      'emojis': [
        '⚽️', '🏀', '🏈', '⚾️', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
        '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳️',
        '🪁', '🏹', '🎣', '🤿', '🥊', '🥋', '🛹', '🛼', '🛷', '⛸️',
        '🥌', '🎿', '🏂', '🪂', '🏋️', '🏋️‍♀️', '🤼', '🤸', '⛹️', '🤺',
        '🤾', '🏌️', '🏇', '🧘', '🏄', '🏊', '🤽', '🚣', '🧗', '🚴',
        '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️', '🏵️', '🎗️', '🎫', '🎟️',
        '🎪', '🎭', '🎨', '🎬', '🎤', '🎧', '🎼', '🎹', '🥁', '🎸',
      ],
    },
    {
      'name': 'Travel',
      'icon': Icons.flight_takeoff_rounded,
      'emojis': [
        '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
        '🛻', '🚚', '🚛', '🚜', '🛴', '🚲', '🛵', '🏍️', '🛺', '🚨',
        '🚔', '🚍', '🚘', '🚖', '🚡', '🚠', '🚟', '🚃', '🚋', '🚞',
        '🝲', '🚄', '🚅', '🚈', '🚂', '🚆', '🚇', '🚊', '🚉', '✈️',
        '🛫', '🛬', '🛩️', '🚀', '🛸', '🚁', '🛶', '⛵️', '🚤', '🛳️',
        '⚓️', '⛽️', '🚧', '🚦', '🚥', '🗺️', '🗿', '🗽', '🗼', '🏰',
      ],
    },
    {
      'name': 'Objects',
      'icon': Icons.lightbulb_outline_rounded,
      'emojis': [
        '⌚️', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '🕹️',
        '🗜️', '💽', '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥',
        '📽️', '🎞️', '📞', '☎️', '📟', '📠', '📺', '📻', '🎙️', '🎚️',
        '🎛️', '🧭', '⏱️', '⏲️', '⏰', '🕰️', '⌛️', '⏳', '📡', '🔋',
        '🪫', '🔌', '💡', '🔦', '🕯️', '🪔', '🧯', '🛢️', '💸', '💵',
        '💴', '💶', '💷', '🪙', '💰', '💳', '💎', '⚖️', '🪜', '🧰',
      ],
    },
    {
      'name': 'Hearts',
      'icon': Icons.favorite_rounded,
      'emojis': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
        '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️',
        '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐',
        '⛎', '♈️', '♉️', '♊️', '♋️', '♌️', '♍️', '♎️', '♏️', '♐️',
        '♑️', '♒️', '♓️', '🆔', '⚛️', '🉑', '☢️', '☣️', '📴', '📳',
        '🈶', '🈚️', '🈸', '🈺', '🈷️', '✴️', '🆚', '💮', '🉐', '㊙️',
        '💯', '💢', '♨️', '🚷', '🚯', '🚳', '🚱', '🔞', '📵', '🚭',
      ],
    },
  ];

  static const List<WhatsAppStickerPack> _stickerPacks = [
    WhatsAppStickerPack(
      name: 'Chibi & Fun',
      icon: '🌟',
      stickers: [
        WhatsAppStickerItem(emoji: '👋', title: 'Hello!', pack: 'Chibi & Fun', accentColor: Color(0xFF3B82F6)),
        WhatsAppStickerItem(emoji: '🔥', title: 'Super Lit!', pack: 'Chibi & Fun', accentColor: Color(0xFFEF4444)),
        WhatsAppStickerItem(emoji: '❤️', title: 'Love It!', pack: 'Chibi & Fun', accentColor: Color(0xFFEC4899)),
        WhatsAppStickerItem(emoji: '😎', title: 'Cool Vibes', pack: 'Chibi & Fun', accentColor: Color(0xFFF59E0B)),
        WhatsAppStickerItem(emoji: '🥳', title: 'Party Time!', pack: 'Chibi & Fun', accentColor: Color(0xFF10B981)),
        WhatsAppStickerItem(emoji: '🏃', title: 'On My Way', pack: 'Chibi & Fun', accentColor: Color(0xFF6366F1)),
        WhatsAppStickerItem(emoji: '🥺', title: 'Please?', pack: 'Chibi & Fun', accentColor: Color(0xFF8B5CF6)),
        WhatsAppStickerItem(emoji: '✅', title: 'Approved!', pack: 'Chibi & Fun', accentColor: Color(0xFF059669)),
        WhatsAppStickerItem(emoji: '😂', title: 'LMAO', pack: 'Chibi & Fun', accentColor: Color(0xFFD97706)),
        WhatsAppStickerItem(emoji: '🌙', title: 'Good Night', pack: 'Chibi & Fun', accentColor: Color(0xFF4338CA)),
        WhatsAppStickerItem(emoji: '🚀', title: 'Let\'s Go!', pack: 'Chibi & Fun', accentColor: Color(0xFF2563EB)),
        WhatsAppStickerItem(emoji: '🌟', title: 'You Rock!', pack: 'Chibi & Fun', accentColor: Color(0xFFCA8A04)),
      ],
    ),
    WhatsAppStickerPack(
      name: 'Love & Romance',
      icon: '💖',
      stickers: [
        WhatsAppStickerItem(emoji: '❤️', title: 'Love You', pack: 'Love & Romance', accentColor: Color(0xFFE11D48)),
        WhatsAppStickerItem(emoji: '💕', title: 'Miss You', pack: 'Love & Romance', accentColor: Color(0xFFDB2777)),
        WhatsAppStickerItem(emoji: '💋', title: 'Sending Kisses', pack: 'Love & Romance', accentColor: Color(0xFFF43F5E)),
        WhatsAppStickerItem(emoji: '🫶', title: 'Forever', pack: 'Love & Romance', accentColor: Color(0xFFBE185D)),
        WhatsAppStickerItem(emoji: '🥰', title: 'So In Love', pack: 'Love & Romance', accentColor: Color(0xFFFB7185)),
        WhatsAppStickerItem(emoji: '🤗', title: 'Warm Hug', pack: 'Love & Romance', accentColor: Color(0xFFEA580C)),
        WhatsAppStickerItem(emoji: '💌', title: 'For You', pack: 'Love & Romance', accentColor: Color(0xFFE11D48)),
        WhatsAppStickerItem(emoji: '🌹', title: 'A Rose', pack: 'Love & Romance', accentColor: Color(0xFFDC2626)),
        WhatsAppStickerItem(emoji: '💖', title: 'Sparkles', pack: 'Love & Romance', accentColor: Color(0xFFEC4899)),
        WhatsAppStickerItem(emoji: '🧸', title: 'Cuddles', pack: 'Love & Romance', accentColor: Color(0xFF9333EA)),
        WhatsAppStickerItem(emoji: '💍', title: 'My One', pack: 'Love & Romance', accentColor: Color(0xFF0284C7)),
        WhatsAppStickerItem(emoji: '🍫', title: 'Sweetheart', pack: 'Love & Romance', accentColor: Color(0xFF78350F)),
      ],
    ),
    WhatsAppStickerPack(
      name: 'Daily Greetings',
      icon: '☀️',
      stickers: [
        WhatsAppStickerItem(emoji: '☀️', title: 'Good Morning', pack: 'Daily Greetings', accentColor: Color(0xFFF59E0B)),
        WhatsAppStickerItem(emoji: '🌙', title: 'Sweet Dreams', pack: 'Daily Greetings', accentColor: Color(0xFF475569)),
        WhatsAppStickerItem(emoji: '☕', title: 'Coffee Time', pack: 'Daily Greetings', accentColor: Color(0xFF92400E)),
        WhatsAppStickerItem(emoji: '🎂', title: 'Happy Birthday', pack: 'Daily Greetings', accentColor: Color(0xFFEC4899)),
        WhatsAppStickerItem(emoji: '🥂', title: 'Cheers!', pack: 'Daily Greetings', accentColor: Color(0xFFD97706)),
        WhatsAppStickerItem(emoji: '🙏', title: 'Thank You!', pack: 'Daily Greetings', accentColor: Color(0xFF059669)),
        WhatsAppStickerItem(emoji: '✨', title: 'Blessed Day', pack: 'Daily Greetings', accentColor: Color(0xFFEAB308)),
        WhatsAppStickerItem(emoji: '🌈', title: 'Stay Positive', pack: 'Daily Greetings', accentColor: Color(0xFF06B6D4)),
        WhatsAppStickerItem(emoji: '🎈', title: 'Celebration', pack: 'Daily Greetings', accentColor: Color(0xFFEF4444)),
        WhatsAppStickerItem(emoji: '🏖️', title: 'Weekend Vibes', pack: 'Daily Greetings', accentColor: Color(0xFF0D9488)),
        WhatsAppStickerItem(emoji: '🌧️', title: 'Rainy Chill', pack: 'Daily Greetings', accentColor: Color(0xFF3B82F6)),
        WhatsAppStickerItem(emoji: '🎊', title: 'Congrats!', pack: 'Daily Greetings', accentColor: Color(0xFF8B5CF6)),
      ],
    ),
    WhatsAppStickerPack(
      name: 'Work & Hustle',
      icon: '💼',
      stickers: [
        WhatsAppStickerItem(emoji: '💻', title: 'Working...', pack: 'Work & Hustle', accentColor: Color(0xFF3B82F6)),
        WhatsAppStickerItem(emoji: '⚡', title: 'High Priority', pack: 'Work & Hustle', accentColor: Color(0xFFEAB308)),
        WhatsAppStickerItem(emoji: '🎯', title: 'Target Met', pack: 'Work & Hustle', accentColor: Color(0xFFEF4444)),
        WhatsAppStickerItem(emoji: '📈', title: 'Growing', pack: 'Work & Hustle', accentColor: Color(0xFF10B981)),
        WhatsAppStickerItem(emoji: '🏆', title: 'Champion!', pack: 'Work & Hustle', accentColor: Color(0xFFCA8A04)),
        WhatsAppStickerItem(emoji: '⏰', title: 'Deadline!', pack: 'Work & Hustle', accentColor: Color(0xFFDC2626)),
        WhatsAppStickerItem(emoji: '💡', title: 'Great Idea', pack: 'Work & Hustle', accentColor: Color(0xFFF59E0B)),
        WhatsAppStickerItem(emoji: '📊', title: 'Data Review', pack: 'Work & Hustle', accentColor: Color(0xFF6366F1)),
        WhatsAppStickerItem(emoji: '📚', title: 'Study Hard', pack: 'Work & Hustle', accentColor: Color(0xFF8B5CF6)),
        WhatsAppStickerItem(emoji: '🛠️', title: 'Fixing It', pack: 'Work & Hustle', accentColor: Color(0xFF64748B)),
        WhatsAppStickerItem(emoji: '🤝', title: 'Deal Done', pack: 'Work & Hustle', accentColor: Color(0xFF059669)),
        WhatsAppStickerItem(emoji: '🕒', title: 'In Meeting', pack: 'Work & Hustle', accentColor: Color(0xFF0284C7)),
      ],
    ),
    WhatsAppStickerPack(
      name: 'Memes & Reactions',
      icon: '🤯',
      stickers: [
        WhatsAppStickerItem(emoji: '🤯', title: 'Mind Blown', pack: 'Memes & Reactions', accentColor: Color(0xFFF43F5E)),
        WhatsAppStickerItem(emoji: '🤦', title: 'Facepalm', pack: 'Memes & Reactions', accentColor: Color(0xFF64748B)),
        WhatsAppStickerItem(emoji: '😱', title: 'No Way!', pack: 'Memes & Reactions', accentColor: Color(0xFF3B82F6)),
        WhatsAppStickerItem(emoji: '🤫', title: 'Keep Secret', pack: 'Memes & Reactions', accentColor: Color(0xFF8B5CF6)),
        WhatsAppStickerItem(emoji: '🧠', title: 'Big Brain', pack: 'Memes & Reactions', accentColor: Color(0xFFEC4899)),
        WhatsAppStickerItem(emoji: '🤨', title: 'Wait What?', pack: 'Memes & Reactions', accentColor: Color(0xFFD97706)),
        WhatsAppStickerItem(emoji: '🍿', title: 'Drama Time', pack: 'Memes & Reactions', accentColor: Color(0xFFEAB308)),
        WhatsAppStickerItem(emoji: '💀', title: 'I\'m Dead', pack: 'Memes & Reactions', accentColor: Color(0xFF1E293B)),
        WhatsAppStickerItem(emoji: '💤', title: 'So Sleepy', pack: 'Memes & Reactions', accentColor: Color(0xFF6366F1)),
        WhatsAppStickerItem(emoji: '🤐', title: 'Sealed Lips', pack: 'Memes & Reactions', accentColor: Color(0xFFF59E0B)),
        WhatsAppStickerItem(emoji: '🎮', title: 'GG WP', pack: 'Memes & Reactions', accentColor: Color(0xFF10B981)),
        WhatsAppStickerItem(emoji: '🗿', title: 'Sigma Chad', pack: 'Memes & Reactions', accentColor: Color(0xFF475569)),
      ],
    ),
    WhatsAppStickerPack(
      name: 'Cute Pets',
      icon: '🐱',
      stickers: [
        WhatsAppStickerItem(emoji: '🐱', title: 'Cute Kitty', pack: 'Cute Pets', accentColor: Color(0xFFF59E0B)),
        WhatsAppStickerItem(emoji: '🐶', title: 'Good Doggo', pack: 'Cute Pets', accentColor: Color(0xFF3B82F6)),
        WhatsAppStickerItem(emoji: '🐼', title: 'Panda Nap', pack: 'Cute Pets', accentColor: Color(0xFF1E293B)),
        WhatsAppStickerItem(emoji: '🦊', title: 'Clever Fox', pack: 'Cute Pets', accentColor: Color(0xFFEA580C)),
        WhatsAppStickerItem(emoji: '🐨', title: 'Koala Hug', pack: 'Cute Pets', accentColor: Color(0xFF64748B)),
        WhatsAppStickerItem(emoji: '🦁', title: 'Brave Lion', pack: 'Cute Pets', accentColor: Color(0xFFCA8A04)),
        WhatsAppStickerItem(emoji: '🐯', title: 'Fierce Tiger', pack: 'Cute Pets', accentColor: Color(0xFFD97706)),
        WhatsAppStickerItem(emoji: '🐰', title: 'Bunny Hop', pack: 'Cute Pets', accentColor: Color(0xFFEC4899)),
        WhatsAppStickerItem(emoji: '🦥', title: 'Lazy Sloth', pack: 'Cute Pets', accentColor: Color(0xFF059669)),
        WhatsAppStickerItem(emoji: '🦉', title: 'Night Owl', pack: 'Cute Pets', accentColor: Color(0xFF4338CA)),
        WhatsAppStickerItem(emoji: '🐸', title: 'Chill Frog', pack: 'Cute Pets', accentColor: Color(0xFF16A34A)),
        WhatsAppStickerItem(emoji: '🐧', title: 'Happy Penguin', pack: 'Cute Pets', accentColor: Color(0xFF0284C7)),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final activeColor = AppTheme.brandBlue;
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Top Navigation Bar: Emoji vs Stickers Switch & Backspace
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Mode Toggle: Emoji Tab
                _buildModePill(
                  index: 0,
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  label: 'Emoji',
                  isSelected: _activeTab == 0,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
                const SizedBox(width: 8),

                // Mode Toggle: Stickers Tab
                _buildModePill(
                  index: 1,
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Stickers',
                  isSelected: _activeTab == 1,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),

                const Spacer(),

                // Backspace button (for emoji typing)
                if (_activeTab == 0)
                  IconButton(
                    icon: Icon(Icons.backspace_outlined, color: inactiveColor, size: 20),
                    tooltip: 'Delete',
                    splashRadius: 18,
                    onPressed: widget.onBackspace,
                  ),
              ],
            ),
          ),

          // Sub-bar: Category Selector
          if (_activeTab == 0)
            _buildEmojiCategoriesBar(borderColor, activeColor, inactiveColor)
          else
            _buildStickerPacksBar(borderColor, activeColor, inactiveColor),

          // Main Content View (Grid)
          Expanded(
            child: _activeTab == 0
                ? _buildEmojiGrid(isDark)
                : _buildStickersGrid(isDark, cardColor, borderColor),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiCategoriesBar(Color borderColor, Color activeColor, Color inactiveColor) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _emojiCategories.length,
        itemBuilder: (context, i) {
          final cat = _emojiCategories[i];
          final isSelected = _activeEmojiCategory == i;
          return GestureDetector(
            onTap: () => setState(() => _activeEmojiCategory = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? activeColor : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Icon(
                cat['icon'] as IconData,
                size: 20,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStickerPacksBar(Color borderColor, Color activeColor, Color inactiveColor) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _stickerPacks.length,
        itemBuilder: (context, i) {
          final pack = _stickerPacks[i];
          final isSelected = _activeStickerPack == i;
          return GestureDetector(
            onTap: () => setState(() => _activeStickerPack = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? activeColor : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(pack.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    pack.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmojiGrid(bool isDark) {
    final emojis = (_emojiCategories[_activeEmojiCategory]['emojis'] as List<String>);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, i) {
        final emoji = emojis[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onEmojiSelected(emoji),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 26),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickersGrid(bool isDark, Color cardColor, Color borderColor) {
    final pack = _stickerPacks[_activeStickerPack];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: pack.stickers.length,
      itemBuilder: (context, i) {
        final sticker = pack.stickers[i];
        final tint = sticker.accentColor ?? AppTheme.brandBlue;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => widget.onStickerSelected(sticker),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: isDark ? 0.12 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sticker.emoji,
                      style: const TextStyle(fontSize: 30, height: 1.1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      sticker.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
