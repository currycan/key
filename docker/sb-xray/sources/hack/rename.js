/**
 * Sub-Store Custom Rename Script
 * Sub-Store 自定义重命名脚本
 *
 * 功能：
 * 1. 过滤无效节点 (如到期、测试、官网等)
 * 2. 标准化节点名称 (统一地名、替换关键字)
 * 3. 自动添加国旗 Emoji
 * 4. 格式化倍率显示
 * 5. 统一命名格式: [国旗] [名称] [倍率] | [协议]
 */

// 1. 基础国家/地区数组 (用于构建旗帜映射)
// 对应顺序：旗帜 -> 英文缩写 -> 中文名 -> 英文全名
// prettier-ignore
const FG = ['🇭🇰', '🇲🇴', '🇹🇼', '🇯🇵', '🇰🇷', '🇸🇬', '🇺🇸', '🇬🇧', '🇫🇷', '🇩🇪', '🇦🇺', '🇦🇪', '🇦🇫', '🇦🇱', '🇩🇿', '🇦🇴', '🇦🇷', '🇦🇲', '🇦🇹', '🇦🇿', '🇧🇭', '🇧🇩', '🇧🇾', '🇧🇪', '🇧🇿', '🇧🇯', '🇧🇹', '🇧🇴', '🇧🇦', '🇧🇼', '🇧🇷', '🇻🇬', '🇧🇳', '🇧🇬', '🇧🇫', '🇧🇮', '🇰🇭', '🇨🇲', '🇨🇦', '🇨🇻', '🇰🇾', '🇨🇫', '🇹🇩', '🇨🇱', '🇨🇴', '🇰🇲', '🇨🇬', '🇨🇩', '🇨🇷', '🇭🇷', '🇨🇾', '🇨🇿', '🇩🇰', '🇩🇯', '🇩🇴', '🇪🇨', '🇪🇬', '🇸🇻', '🇬🇶', '🇪🇷', '🇪🇪', '🇪🇹', '🇫🇯', '🇫🇮', '🇬🇦', '🇬🇲', '🇬🇪', '🇬🇭', '🇬🇷', '🇬🇱', '🇬🇹', '🇬🇳', '🇬🇾', '🇭🇹', '🇭🇳', '🇭🇺', '🇮🇸', '🇮🇳', '🇮🇩', '🇮🇷', '🇮🇶', '🇮🇪', '🇮🇲', '🇮🇱', '🇮🇹', '🇨🇮', '🇯🇲', '🇯🇴', '🇰🇿', '🇰🇪', '🇰🇼', '🇰🇬', '🇱🇦', '🇱🇻', '🇱🇧', '🇱🇸', '🇱🇷', '🇱🇾', '🇱🇹', '🇱🇺', '🇲🇰', '🇲🇬', '🇲🇼', '🇲🇾', '🇲🇻', '🇲🇱', '🇲🇹', '🇲🇺', '🇲🇽', '🇲🇩', '🇲🇨', '🇲🇳', '🇲🇪', '🇲🇦', '🇲🇿', '🇲🇲', '🇳🇦', '🇳🇵', '🇳🇱', '🇳🇿', '🇳🇮', '🇳🇪', '🇳🇬', '🇰🇵', '🇳🇴', '🇴🇲', '🇵🇰', '🇵🇦', '🇵🇾', '🇵🇪', '🇵🇭', '🇵🇹', '🇵🇷', '🇶🇦', '🇷🇴', '🇷🇺', '🇷🇼', '🇸🇲', '🇸🇦', '🇸🇳', '🇷🇸', '🇸🇱', '🇸🇰', '🇸🇮', '🇸🇴', '🇿🇦', '🇪🇸', '🇱🇰', '🇸🇩', '🇸🇷', '🇸🇿', '🇸🇪', '🇨🇭', '🇸🇾', '🇹🇯', '🇹🇿', '🇹🇭', '🇹🇬', '🇹🇴', '🇹🇹', '🇹🇳', '🇹🇷', '🇹🇲', '🇻🇮', '🇺🇬', '🇺🇦', '🇺🇾', '🇺🇿', '🇻🇪', '🇻🇳', '🇾🇪', '🇿🇲', '🇿🇼', '🇦🇩', '🇷🇪', '🇵🇱', '🇬🇺', '🇻🇦', '🇱🇮', '🇨🇼', '🇸🇨', '🇦🇶', '🇬🇮', '🇨🇺', '🇫🇴', '🇦🇽', '🇧🇲', '🇹🇱'];
// prettier-ignore
const EN = ['HK', 'MO', 'TW', 'JP', 'KR', 'SG', 'US', 'GB', 'FR', 'DE', 'AU', 'AE', 'AF', 'AL', 'DZ', 'AO', 'AR', 'AM', 'AT', 'AZ', 'BH', 'BD', 'BY', 'BE', 'BZ', 'BJ', 'BT', 'BO', 'BA', 'BW', 'BR', 'VG', 'BN', 'BG', 'BF', 'BI', 'KH', 'CM', 'CA', 'CV', 'KY', 'CF', 'TD', 'CL', 'CO', 'KM', 'CG', 'CD', 'CR', 'HR', 'CY', 'CZ', 'DK', 'DJ', 'DJ', 'DO', 'EC', 'EG', 'SV', 'GQ', 'ER', 'EE', 'ET', 'FJ', 'FI', 'GA', 'GM', 'GE', 'GH', 'GR', 'GL', 'GT', 'GN', 'GY', 'HT', 'HN', 'HU', 'IS', 'IN', 'ID', 'IR', 'IQ', 'IE', 'IM', 'IL', 'IT', 'CI', 'JM', 'JO', 'KZ', 'KE', 'KW', 'KG', 'LA', 'LV', 'LB', 'LS', 'LR', 'LY', 'LT', 'LU', 'MK', 'MG', 'MW', 'MY', 'MV', 'ML', 'MT', 'MR', 'MU', 'MX', 'MD', 'MC', 'MN', 'ME', 'MA', 'MZ', 'MM', 'NA', 'NP', 'NL', 'NZ', 'NI', 'NE', 'NG', 'KP', 'NO', 'OM', 'PK', 'PA', 'PY', 'PE', 'PH', 'PT', 'PR', 'QA', 'RO', 'RU', 'RW', 'SM', 'SA', 'SN', 'RS', 'SL', 'SK', 'SI', 'SO', 'ZA', 'ES', 'LK', 'SD', 'SR', 'SZ', 'SE', 'CH', 'SY', 'TJ', 'TZ', 'TH', 'TG', 'TO', 'TT', 'TN', 'TR', 'TM', 'VI', 'UG', 'UA', 'UY', 'UZ', 'VE', 'VN', 'YE', 'ZM', 'ZW', 'AD', 'RE', 'PL', 'GU', 'VA', 'LI', 'CW', 'SC', 'AQ', 'GI', 'CU', 'FO', 'AX', 'BM', 'TL'];
// prettier-ignore
const ZH = ['香港', '澳门', '台湾', '日本', '韩国', '新加坡', '美国', '英国', '法国', '德国', '澳大利亚', '阿联酋', '阿富汗', '阿尔巴尼亚', '阿尔及利亚', '安哥拉', '阿根廷', '亚美尼亚', '奥地利', '阿塞拜疆', '巴林', '孟加拉国', '白俄罗斯', '比利时', '伯利兹', '贝宁', '不丹', '玻利维亚', '波斯尼亚和黑塞哥维那', '博茨瓦纳', '巴西', '英属维京群岛', '文莱', '保加利亚', '布基纳法索', '布隆迪', '柬埔寨', '喀麦隆', '加拿大', '佛得角', '开曼群岛', '中非共和国', '乍得', '智利', '哥伦比亚', '科摩罗', '刚果(布)', '刚果(金)', '哥斯达黎加', '克罗地亚', '塞浦路斯', '捷克', '丹麦', '吉布提', '多米尼加共和国', '厄瓜多尔', '埃及', '萨尔瓦多', '赤道几内亚', '厄立特里亚', '爱沙尼亚', '埃塞俄比亚', '斐济', '芬兰', '加蓬', '冈比亚', '格鲁吉亚', '加纳', '希腊', '格陵兰', '危地马拉', '几内亚', '圭亚那', '海地', '洪都拉斯', '匈牙利', '冰岛', '印度', '印尼', '伊朗', '伊拉克', '爱尔兰', '马恩岛', '以色列', '意大利', '科特迪瓦', '牙买加', '约旦', '哈萨克斯坦', '肯尼亚', '科威特', '吉尔吉斯斯坦', '老挝', '拉脱维亚', '黎巴嫩', '莱索托', '利比里亚', '利比亚', '立陶宛', '卢森堡', '马其顿', '马达加斯加', '马拉维', '马来', '马尔代夫', '马里', '马耳他', '毛利塔尼亚', '毛里求斯', '墨西哥', '摩尔多瓦', '摩纳哥', '蒙古', '黑山共和国', '摩洛哥', '莫桑比克', '缅甸', '纳米比亚', '尼泊尔', '荷兰', '新西兰', '尼加拉瓜', '尼日尔', '尼日利亚', '朝鲜', '挪威', '阿曼', '巴基斯坦', '巴拿马', '巴拉圭', '秘鲁', '菲律宾', '葡萄牙', '波多黎各', '卡塔尔', '罗马尼亚', '俄罗斯', '卢旺达', '圣马力诺', '沙特阿拉伯', '塞内加尔', '塞尔维亚', '塞拉利昂', '斯洛伐克', '斯洛文尼亚', '索马里', '南非', '西班牙', '斯里兰卡', '苏丹', '苏里南', '斯威士兰', '瑞典', '瑞士', '叙利亚', '塔吉克斯坦', '坦桑尼亚', '泰国', '多哥', '汤加', '特立尼达和多巴哥', '突尼斯', '土耳其', '土库曼斯坦', '美属维尔京群岛', '乌干达', '乌克兰', '乌拉圭', '乌兹别克斯坦', '委内瑞拉', '越南', '也门', '赞比亚', '津巴布韦', '安道尔', '留尼汪', '波兰', '关岛', '梵蒂冈', '列支敦士登', '库拉索', '塞舌尔', '南极', '直布罗陀', '古巴', '法罗群岛', '奥兰群岛', '百慕达', '东帝汶'];
// prettier-ignore
const QC = ['Hong Kong', 'Macao', 'Taiwan', 'Japan', 'Korea', 'Singapore', 'United States', 'United Kingdom', 'France', 'Germany', 'Australia', 'Dubai', 'Afghanistan', 'Albania', 'Algeria', 'Angola', 'Argentina', 'Armenia', 'Austria', 'Azerbaijan', 'Bahrain', 'Bangladesh', 'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan', 'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'British Virgin Islands', 'Brunei', 'Bulgaria', 'Burkina-faso', 'Burundi', 'Cambodia', 'Cameroon', 'Canada', 'CapeVerde', 'CaymanIslands', 'Central African Republic', 'Chad', 'Chile', 'Colombia', 'Comoros', 'Congo-Brazzaville', 'Congo-Kinshasa', 'CostaRica', 'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Djibouti', 'Dominican Republic', 'Ecuador', 'Egypt', 'EISalvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Ethiopia', 'Fiji', 'Finland', 'Gabon', 'Gambia', 'Georgia', 'Ghana', 'Greece', 'Greenland', 'Guatemala', 'Guinea', 'Guyana', 'Haiti', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Isle of Man', 'Israel', 'Italy', 'Ivory Coast', 'Jamaica', 'Jordan', 'Kazakstan', 'Kenya', 'Kuwait', 'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Lithuania', 'Luxembourg', 'Macedonia', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Mauritania', 'Mauritius', 'Mexico', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar(Burma)', 'Namibia', 'Nepal', 'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'NorthKorea', 'Norway', 'Oman', 'Pakistan', 'Panama', 'Paraguay', 'Peru', 'Philippines', 'Portugal', 'PuertoRico', 'Qatar', 'Romania', 'Russia', 'Rwanda', 'SanMarino', 'SaudiArabia', 'Senegal', 'Serbia', 'SierraLeone', 'Slovakia', 'Slovenia', 'Somalia', 'SouthAfrica', 'Spain', 'SriLanka', 'Sudan', 'Suriname', 'Swaziland', 'Sweden', 'Switzerland', 'Syria', 'Tajikstan', 'Tanzania', 'Thailand', 'Togo', 'Tonga', 'TrinidadandTobago', 'Tunisia', 'Turkey', 'Turkmenistan', 'U.S.Virgin Islan'];

// 2. 正则定义 (集成)
// 过滤正则：匹配包含以下关键词的节点名称，这些节点将被移除
// 移除 "网站" 以防止误删提示节点
const nameclear =
  /(❗|套餐|到期|有效|剩余|版本|已用|过期|失联|测试|官方|网址|群|TEST|客服|获取|订阅|流量|机场|下次|官址|联系|邮箱|工单|学术|USE|USED|TOTAL|EXPIRE|EMAIL|更快|更新)/i;

// 替换正则数组：用于关键词替换 (regexArray -> valueArray)
// prettier-ignore
const regexArray = [/(\d+(?:\.\d+)?)x/ig, /ˣ²/, /ˣ³/, /ˣ⁴/, /ˣ⁵/, /ˣ⁶/, /ˣ⁷/, /ˣ⁸/, /ˣ⁹/, /ˣ¹⁰/, /ˣ²⁰/, /ˣ³⁰/, /ˣ⁴⁰/, /ˣ⁵⁰/, /\budp\b/i, /\bgpt\b/i, /udpn\b/];
// prettier-ignore
const valueArray = ["$1×", "2×", "3×", "4×", "5×", "6×", "7×", "8×", "9×", "10×", "20×", "30×", "40×", "50×", "UDP", "GPT", "UDPN"];

// 地名标准化映射 (rurekey): 将各种乱七八糟的地名统一为标准名称
const rurekey = {
  GB: /UK/g,
  "B-G-P": /BGP/g,
  "Russia Moscow": /Moscow/g,
  "Korea Chuncheon": /Chuncheon|Seoul/g,
  "Hong Kong": /Hongkong|HONG KONG/gi,
  "United Kingdom London": /London|Great Britain/g,
  "Dubai United Arab Emirates": /United Arab Emirates/g,
  "Taiwan TW 台湾 🇹🇼": /(台|Tai\s?wan|TW).*?🇨🇳|🇨🇳.*?(台|Tai\s?wan|TW)/g,
  "United States": /USA|Los Angeles|San Jose|Silicon Valley|Michigan/g,
  澳大利亚: /澳洲|墨尔本|悉尼|土澳|(深|沪|呼|京|广|杭)澳/g,
  德国: /(深|沪|呼|京|广|杭)德(?!.*(I|线))|法兰克福|滬德/g,
  香港: /(深|沪|呼|京|广|杭)港(?!.*(I|线))/g,
  日本: /(深|沪|呼|京|广|杭|中|辽)日(?!.*(I|线))|东京|大坂/g,
  新加坡: /狮城|(深|沪|呼|京|广|杭)新/g,
  美国: /(深|沪|呼|京|广|杭)美|波特兰|芝加哥|哥伦布|纽约|硅谷|俄勒冈|西雅图|芝加哥/g,
  波斯尼亚和黑塞哥维那: /波黑共和国/g,
  印尼: /印度尼西亚|雅加达/g,
  印度: /孟买/g,
  阿联酋: /迪拜|阿拉伯联合酋长国/g,
  孟加拉国: /孟加拉/g,
  捷克: /捷克共和国/g,
  台湾: /新台|新北|台(?!.*线)/g,
  Taiwan: /Taipei/g,
  韩国: /春川|韩|首尔/g,
  Japan: /Tokyo|Osaka/g,
  英国: /伦敦/g,
  India: /Mumbai/g,
  Germany: /Frankfurt/g,
  Switzerland: /Zurich/g,
  俄罗斯: /莫斯科/g,
  土耳其: /伊斯坦布尔/g,
  泰国: /泰國|曼谷/g,
  法国: /巴黎/g,
  G: /\d\s?GB/gi,
  Esnc: /esnc/gi,
};

// 3. 初始化旗帜映射表 (flagMap)
// 将 ZH (中文), EN (英文简写), QC (英文全称) 映射到 FG (旗帜)
const initialFlagMap = {};
for (let i = 0; i < FG.length; i++) {
  const flag = FG[i];
  if (ZH[i]) initialFlagMap[ZH[i]] = flag;
  if (EN[i]) initialFlagMap[EN[i]] = flag;
  if (QC[i]) initialFlagMap[QC[i]] = flag;
}

// 4. 补充本地城市/州名和自定义规则 (完全恢复)
// 这里的优先级高于 initialFlagMap，用于处理特定城市或自定义名称
const customFlagMap = {
  // 曼谷 (Bangkok) -> 泰国
  "曼谷": "🇹🇭", "Bangkok": "🇹🇭",

  // 拉斯维加斯 (Las Vegas) -> 美国
  "拉斯维加斯": "🇺🇸", "LasVegas": "🇺🇸",

  // 自定义规则
  "专属纯净住宅节点": "🇺🇸",

  // 美国 (US) - 额外的城市/州名
  "洛杉矶": "🇺🇸", "硅谷": "🇺🇸", "西雅图": "🇺🇸", "波特兰": "🇺🇸",
  "达拉斯": "🇺🇸", "休斯顿": "🇺🇸", "休斯敦": "🇺🇸", "圣何塞": "🇺🇸", "纽约": "🇺🇸", "芝加哥": "🇺🇸", "华盛顿": "🇺🇸",
  "迈阿密": "🇺🇸", "Miami": "🇺🇸", "堪萨斯": "🇺🇸", "Kansas": "🇺🇸",
  "凤凰城": "🇺🇸", "Phoenix": "🇺🇸", "德州": "🇺🇸", "德克萨斯": "🇺🇸", "TX": "🇺🇸", "Texas": "🇺🇸",
  "奥勒姆": "🇺🇸", "Orem": "🇺🇸",

  // 加拿大 (CA) - 额外的省份
  "安大略": "🇨🇦", "Ontario": "🇨🇦",

  // 欧洲/中东 - 额外的城市名
  "阿姆斯特丹": "🇳🇱", "Amsterdam": "🇳🇱",
  "伊斯坦布尔": "🇹🇷", "Istanbul": "🇹🇷",

  //  巴哈马
  "巴哈马": "🇧🇸", "Bahamas": "🇧🇸",
  // 毛里塔尼亚
  "毛里塔尼亚": "🇲🇷", "Mauritania": "🇲🇷",
  // 泽西岛
  "泽西岛": "🇯🇪", "Jersey": "🇯🇪",
  // 百慕大
  "百慕大": "🇧🇲", "Bermuda": "🇧🇲",
  // 黑山
  "黑山": "🇲🇪", "Montenegro": "🇲🇪",
};

// 合并映射表
const flagMap = { ...initialFlagMap, ...customFlagMap };


/**
 * 主处理函数
 * @param {Array} proxies - 原始节点列表
 * @returns {Array} - 处理后的节点列表
 */
function operator(proxies) {
  return proxies
    .filter((p) => !nameclear.test(p.name)) // 过滤无效节点
    .map((p) => {
      let name = p.name;
      const protocol = p.type ? p.type.toLowerCase() : "unknown";

    // --- 第一步：标准化处理 ---

    // 地名标准化 (Rurekey)
    // 使用正则将非标准地名替换为标准地名 (如 'Hongkong' -> 'Hong Kong')
    for (const key in rurekey) {
      name = name.replace(rurekey[key], key);
    }

    // --- 第二步：识别国旗 ---
    let flag = "🏳️"; // 默认旗帜
    // 按关键词长度降序排序，优先匹配长词 (防止 'US' 匹配到 'USA' 的前两个字母等情况)
    const sortedKeys = Object.keys(flagMap).sort((a, b) => b.length - a.length);
    for (const key of sortedKeys) {
      if (name.toUpperCase().includes(key.toUpperCase())) {
        flag = flagMap[key];
        break; // 匹配到即停止
      }
    }

    // --- 第三步：清理名称 (倍率保护核心逻辑) ---
    // 移除已有的 emoji 旗帜 (避免重复)
    name = name.replace(/[\uD83C][\uDDE6-\uDDFF][\uD83C][\uDDE6-\uDDFF]/g, "").trim();

    // 移除原始名称中的协议名 (可选，保持简洁)
    name = name.replace(new RegExp(protocol, "ig"), "").trim();

    // 执行关键词替换 (如 'IPLC' -> 'IPLC', 'game' -> 'Game' 等格式化)
    for (let i = 0; i < regexArray.length; i++) {
      name = name.replace(regexArray[i], valueArray[i]);
    }

    // 提取并保护倍率 (如 '2x', '3.5x')
    // 逻辑：先提取倍率，从名称中移除，最后再追加到末尾
    const multiplierMatch = name.match(/((?:\d+(?:\.\d+)?)\s?×)/);
    let multiplier = "";
    if (multiplierMatch) {
      multiplier = multiplierMatch[0]; // 保存倍率，如 "2×"
      name = name.replace(multiplierMatch[0], ""); // 从名称中暂时移除倍率
    }
    // 还原倍率 (Restore Multiplier)
    if (multiplier) {
      name = `${name} ${multiplier}`;
    }

    // --- 第四步：组合 ---
    // 最终格式: [旗帜] [名称] [倍率] | [协议]
    p.name = `${flag} ${name} | ${protocol}`;

    return p;
  });
}
