/// ============================================================
/// 登录用户模型（Phase 4）
/// 对应小程序 userInfo 的本地存储结构，扩展了登录态字段。
/// 不可变类，序列化/反序列化与 AppStorage 配合使用。
/// ============================================================
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    this.avatar = '🧳',
    this.phone = '',
    this.loginType = 'local', // 'local' 本地演示 | 'server' 真实后端
    this.createdAt,
  });

  /// 用户唯一标识（本地注册为 generateId；后端登录为后端返回的 id）
  final String id;

  /// 昵称
  final String nickname;

  /// 头像（emoji 字符，避免引入图片资源；后续可扩展 URL 头像）
  final String avatar;

  /// 手机号（本地账号登录时用于识别；后端登录透传）
  final String phone;

  /// 登录来源：local=本地演示账号 / server=配置了后端服务地址
  final String loginType;

  /// 注册时间（ISO8601）
  final String? createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'nickname': nickname,
        'avatar': avatar,
        'phone': phone,
        'loginType': loginType,
        'createdAt': createdAt,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id']?.toString() ?? '',
        nickname: map['nickname']?.toString() ?? '微旅途用户',
        avatar: map['avatar']?.toString() ?? '🧳',
        phone: map['phone']?.toString() ?? '',
        loginType: map['loginType']?.toString() ?? 'local',
        createdAt: map['createdAt']?.toString(),
      );
}
