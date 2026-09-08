// ============================================================
// 天气模型（和风天气 QWeather v7）
// WeatherNow  实时天气  ← /v7/weather/now
// WeatherDaily 每日预报 ← /v7/weather/10d
// WeatherHourly 逐小时 ← /v7/weather/24h
// ============================================================

/// 实时天气
class WeatherNow {
  WeatherNow({
    required this.temp,
    required this.text,
    this.icon = '0',
    this.feelsLike = '',
    this.humidity = '',
    this.windDir = '',
    this.windScale = '',
    this.pressure = '',
    this.vis = '',
    this.obsTime = '',
    this.isMock = false,
  });

  final String temp; // 温度（℃）
  final String text; // 天气现象文字，如「多云」
  final String icon; // 天气现象代码（和风天气 v7 三位数，如 100 晴 / 101 多云；本地 Mock 为单数字）
  final String feelsLike; // 体感温度
  final String humidity; // 湿度 %
  final String windDir; // 风向
  final String windScale; // 风力等级
  final String pressure; // 气压 hPa
  final String vis; // 能见度 km
  final String obsTime; // 观测时间
  final bool isMock; // 是否为降级模拟数据

  factory WeatherNow.fromMap(Map<String, dynamic> map, {bool isMock = false}) =>
      WeatherNow(
        temp: map['temp']?.toString() ?? '--',
        text: map['text']?.toString() ?? '未知',
        icon: map['icon']?.toString() ?? '0',
        feelsLike: map['feelsLike']?.toString() ?? '',
        humidity: map['humidity']?.toString() ?? '',
        windDir: map['windDir']?.toString() ?? '',
        windScale: map['windScale']?.toString() ?? '',
        pressure: map['pressure']?.toString() ?? '',
        vis: map['vis']?.toString() ?? '',
        obsTime: map['obsTime']?.toString() ?? '',
        isMock: isMock,
      );
}

/// 每日预报条目
class WeatherDaily {
  WeatherDaily({
    required this.fxDate,
    required this.tempMax,
    required this.tempMin,
    required this.textDay,
    this.textNight = '',
    this.iconDay = '0',
    this.uvIndex = '',
    this.sunrise = '',
    this.sunset = '',
  });

  final String fxDate; // 预报日期 yyyy-MM-dd
  final String tempMax;
  final String tempMin;
  final String textDay; // 白天天气文字
  final String textNight;
  final String iconDay; // 白天天气代码
  final String uvIndex; // 紫外线指数
  final String sunrise;
  final String sunset;

  factory WeatherDaily.fromMap(Map<String, dynamic> map) => WeatherDaily(
        fxDate: map['fxDate']?.toString() ?? '',
        tempMax: map['tempMax']?.toString() ?? '--',
        tempMin: map['tempMin']?.toString() ?? '--',
        textDay: map['textDay']?.toString() ?? '',
        textNight: map['textNight']?.toString() ?? '',
        iconDay: map['iconDay']?.toString() ?? '0',
        uvIndex: map['uvIndex']?.toString() ?? '',
        sunrise: map['sunrise']?.toString() ?? '',
        sunset: map['sunset']?.toString() ?? '',
      );
}

/// 逐小时预报条目
class WeatherHourly {
  WeatherHourly({
    required this.fxTime,
    required this.temp,
    required this.text,
    this.icon = '0', // 天气现象代码（和风 v7 三位数）
    this.pop = '', // 降水概率
  });

  final String fxTime;
  final String temp;
  final String text;
  final String icon; // 天气现象代码，用于 WeatherUtils.iconOf 映射图标
  final String pop;

  factory WeatherHourly.fromMap(Map<String, dynamic> map) => WeatherHourly(
        fxTime: map['fxTime']?.toString() ?? '',
        temp: map['temp']?.toString() ?? '--',
        text: map['text']?.toString() ?? '',
        icon: map['icon']?.toString() ?? '0',
        pop: map['pop']?.toString() ?? '',
      );
}

/// 出行建议条目（迁移自小程序 getWeatherAdvice）
class WeatherAdvice {
  const WeatherAdvice({required this.icon, required this.text});
  final String icon; // emoji
  final String text;
}

/// ============================================================
/// 天气工具函数（迁移自小程序 utils/weather.js 的图标映射）
/// ============================================================
class WeatherUtils {
  WeatherUtils._();

  /// 根据和风天气代码映射 emoji 图标
  ///
  /// 兼容两类 code：
  /// 1. 和风天气 v7 标准三位数 code（100 晴 / 101 多云 / 104 阴 / 305 小雨…），
  ///    真实接口返回的是这一种；旧版映射只处理单数字导致全部落到默认 🌤️（图标与天气不对应）。
  /// 2. 本地 Mock 数据使用的单数字 code（0 晴 / 1 多云 / 4 阴 / 9 雨）。
  static String iconOf(String code) {
    final v = int.tryParse(code);
    if (v == null) return '🌤️';

    // ---- 夜间代码：月亮系列 ----
    if (v == 150) return '🌙'; // 晴（夜间）
    if (v == 151 || v == 152 || v == 153) return '☁️'; // 多云/少云（夜间）
    if (v == 350 || v == 351) return '🌧️'; // 阵雨（夜间）
    if (v == 456) return '🌧️'; // 阵雨夹雪（夜间）
    if (v == 457) return '❄️'; // 阵雪（夜间）

    // ---- 兼容旧单数字（Mock 数据） ----
    if (v >= 0 && v <= 9) {
      switch (v) {
        case 0:
          return '☀️';
        case 1:
        case 2:
        case 3:
          return '⛅';
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
          return '☁️';
        default:
          return '🌧️'; // 9 及以后视为雨
      }
    }

    // ---- 和风天气 v7 标准三位数 code ----
    switch (v) {
      case 100:
        return '☀️'; // 晴
      case 101:
        return '⛅'; // 多云
      case 102:
        return '🌤️'; // 少云
      case 103:
        return '⛅'; // 晴间多云
      case 104:
        return '☁️'; // 阴
      case 300:
      case 301:
      case 399:
        return '🌦️'; // 阵雨 / 强阵雨 / 雨
      case 302:
      case 303:
        return '⛈️'; // 雷阵雨 / 雷阵雨伴冰雹
      case 304:
        return '🌨️'; // 雨夹雪
      case 305:
      case 306:
      case 312:
      case 313:
      case 329:
      case 330:
      case 336:
      case 337:
        return '🌧️'; // 小雨~中雨
      case 307:
      case 308:
      case 309:
      case 310:
      case 314:
      case 315:
      case 316:
      case 331:
      case 332:
      case 333:
      case 334:
      case 338:
        return '🌧️'; // 大雨~特大暴雨
      case 311:
      case 335:
        return '🌨️'; // 冻雨
      case 317:
      case 318:
      case 319:
      case 320:
      case 321:
      case 322:
      case 323:
      case 324:
      case 325:
      case 326:
      case 327:
      case 328:
      case 400:
      case 401:
      case 402:
      case 403:
      case 407:
      case 408:
      case 409:
      case 410:
      case 499:
        return '❄️'; // 各种雪
      case 404:
      case 405:
      case 406:
        return '🌨️'; // 雨夹雪 / 雨雪天气
      case 500:
      case 501:
      case 509:
      case 510:
      case 514:
      case 515:
        return '🌫️'; // 薄雾 / 雾 / 浓雾
      case 502:
      case 511:
      case 512:
      case 513:
        return '😷'; // 霾
      case 503:
      case 504:
      case 507:
      case 508:
        return '🌪️'; // 扬沙 / 浮尘 / 沙尘暴
      case 900:
        return '🥵'; // 热
      case 901:
        return '🥶'; // 冷
      default:
        return '🌤️';
    }
  }

  /// 根据天气给出出行建议（温度 + 天气现象）
  static List<WeatherAdvice> adviceOf(WeatherNow w) {
    final advice = <WeatherAdvice>[];
    final temp = int.tryParse(w.temp) ?? 20;
    final text = w.text;

    if (temp <= 0) {
      advice.add(const WeatherAdvice(icon: '🧥', text: '严寒天气，注意防寒保暖，穿厚棉衣'));
    } else if (temp <= 10) {
      advice.add(const WeatherAdvice(icon: '🧥', text: '天气较冷，建议穿棉衣或羽绒服'));
    } else if (temp <= 20) {
      advice.add(const WeatherAdvice(icon: '👔', text: '天气凉爽，适当添加外套'));
    } else if (temp <= 30) {
      advice.add(const WeatherAdvice(icon: '👕', text: '天气舒适，穿轻薄衣物即可'));
    } else {
      advice.add(const WeatherAdvice(icon: '🧊', text: '天气炎热，注意防暑降温，多喝水'));
    }

    if (text.contains('雨')) {
      advice.add(const WeatherAdvice(icon: '☔', text: '有雨，记得携带雨具'));
    }
    if (text.contains('雪')) {
      advice.add(const WeatherAdvice(icon: '👢', text: '有雪，路滑注意安全'));
    }
    if (text.contains('雾') || text.contains('霾')) {
      advice.add(const WeatherAdvice(icon: '😷', text: '能见度低，佩戴口罩'));
    }
    if (text.contains('雷')) {
      advice.add(const WeatherAdvice(icon: '⚡', text: '雷暴天气，避免户外活动'));
    }
    return advice;
  }
}
