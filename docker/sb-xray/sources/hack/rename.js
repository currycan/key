/**
 * Sub-Store Node Renaming Script
 * Sub-Store 节点重命名脚本
 *
 * 功能 (Features):
 * 1. 深度格式化: 清理无效字符、标准化分隔符、统一括号格式。 (本次更新: 分隔符两侧强制加入空格，保障 OpenClash Smart 模式基于正则的权重计分不串词) (本次更新: 分隔符两侧强制加入空格，保障 OpenClash Smart 模式基于正则的权重计分不串词)
 * 2. 智能重命名: 自动识别国家/地区，提升地区关键词权重。
 * 3. 稳健去重: 智能识别并移除重复的标签（如 "美国" 出现多次）。
 * 4. 自动标旗: 能够根据名称或代码自动填充对应的国旗 Emoji。
 * 5. 排序优化: 按照预设的地理优先级（香港>台湾>日本...）进行排序。
 * 6. 序号生成: 对同类节点进行标准化编号 (如 "香港[1]", "香港[2]").
 */

// ============================================================================
// 1. 基础配置与数据 (Configuration & Data)
// ============================================================================

const Constants = {
    SEPARATOR: ' ✈ ', // 通用分隔符 (保留 Emoji，两侧加空格防御污染)
    // 地区排序优先级 (Predefined Priority)
    PRIORITY_REGIONS: ["香港", "台湾", "日本", "新加坡", "韩国", "美国"],
    // 无效节点过滤正则
    INVALID_REGEX: /(❗|套餐|到期|有效|剩余|版本|已用|过期|失联|测试|官方|网址|群(?!岛)|TEST|客服|获取|订阅|流量|机场|下次|官址|联系|邮箱|工单|学术|USE|USED|TOTAL|EXPIRE|EMAIL|更快|更新|如果|客户|教程|距离|国内|Traffic|Reset|Days|Left|\d+\s*GB)/i
};

// 1.1 清理规则 (Cleaning Rules)
// 按顺序执行正则替换。合并了旧版的 regexArray 和 valueArray，避免索引错位。
const CleaningRules = [
    { desc: "移除残留序号 [N]", regex: /\[\d+\]/g, value: "" },
    { desc: "提取倍率 (x2 -> 2x)", regex: /\|\s*x(\d+(?:\.\d+)?)(?:倍)?/gi, value: " $1×" },
    { desc: "提取倍率 (2x -> 2x)", regex: /(\d+(?:\.\d+)?)x/ig, value: "$1×" },
    { desc: "提取倍率 (2倍 -> 2x)", regex: /(\d+(?:\.\d+)?)倍/gi, value: "$1×" },
    { desc: "修正地名 (美国多伦多 -> 多伦多)", regex: /美国(?=多伦多)/gi, value: "" },
    { desc: "移除干扰字符 (VS/协议)", regex: /(VS|[(\uff08]协议[一二三四五六七八九十\d]+[)\uff09])/gi, value: "" },
    { desc: "移除孤立的 '无' 字符", regex: /(^|[-_\s丨✈\/])无(?=($|[-_\s丨✈\/]))/g, value: "$1" },
    { desc: "移除 IPv6- 前缀", regex: /IPv6-/gi, value: "" },

    // [Critical] 括号清理逻辑
    { desc: "移除空括号", regex: /\[\s*\]/g, value: "" },
    { desc: "移除空全角括号", regex: /【\s*】/g, value: "" },
    { desc: "剩余括号转空格 (处理 [IPV6])", regex: /[\[\]【】]/g, value: " " }, // Global bracket fix

    { desc: "标准化 IPv6 标识", regex: /(ipv6|v6)/gi, value: "IPv6" }, // Restore IPv6
    { desc: "移除 NEW专线 后缀", regex: /-?NEW专线/gi, value: "-专线" },
    { desc: "移除深港IEPL后缀", regex: /(.+?)[-_\s]+(香港|深港|沪港|呼港|京港|广港|杭港)\s?IEPL/gi, value: "$1" },
    { desc: "移除IEPL主体后缀", regex: /-?(香港|深港|沪港|呼港|京港|广港|杭港)\s?IEPL/gi, value: "$1" },
    { desc: "移除 '水牛'", regex: /-?大?水牛/gi, value: "" },
    { desc: "移除 'HY2'", regex: /-?HY2/gi, value: "" },
    { desc: "移除 'VPN' 关键字", regex: /\bVPN\b/gi, value: "" },
    { desc: "移除 'IP' 关键字 (排除 原生IP/IPv6/IPLC)", regex: /\b(?<!原生)IP\b/g, value: "" },
    { desc: "移除 'GG/read/大学/加州/负载均衡'", regex: /(GG|read|大学|加州|负载均衡)/gi, value: "" },
    { desc: "替换 AI 关键词", regex: /[-_]?\d*(SV|chatgpt|gemini)/gi, value: "AI" }, // AI Replacement
    { desc: "移除流量标识 (TB)", regex: /-?\d+-?\d*TB/gi, value: "" },
    { desc: "保留 '原生IP'", regex: /原生\s?IP/gi, value: "原生IP" },

    // [Critical] 分隔符标准化 (支持 / 和 ✈)
    { desc: "统一分隔符 (转为 -，后续会被 split 拆分)", regex: /[-_|\s丨✈\/]+/g, value: "-" },

    { desc: "移除上标字符", regex: /ˣ²|ˣ³|ˣ⁴|ˣ⁵|ˣ⁶|ˣ⁷|ˣ⁸|ˣ⁹|ˣ¹⁰|ˣ²⁰|ˣ³⁰|ˣ⁴⁰|ˣ⁵⁰/, value: "" },
    { desc: "移除 UDP/GPT 标签", regex: /\budp\b/i, value: "UDP" },
    { desc: "移除 GPT 标签", regex: /\bgpt\b/i, value: "GPT" },
    { desc: "移除 UDPN 标签", regex: /udpn\b/, value: "UDPN" }
];

// 1.2 地区关键词映射 (Region Mapping)
// 用于标准化地名 (如 'HK' -> '香港')
const RegionMap = {
    // 亚洲
    "香港": /((?:\bHK\b)|Hong[\s-]?Kong|HONG[\s-]?KONG|Hongkong|香港|深港|沪港|呼港|京港|广港|杭港|HKT)+/gi,
    "台湾": /((?:\bTW\b)|Taiwan|Taipei|Kaohsiung|Hsinchu|Taichung|台湾|台北|高雄|新竹|台中|新北|彰化|台|新台)+/gi,
    "日本": /(Japan|Tokyo|Osaka|Saitama|Nagoya|Fukuoka|Hokkaido|Okinawa|Kyoto|Yokohama|日本|东京|大阪|名古屋|埼玉|福冈|北海道|冲绳|京都|横滨|深日|沪日|呼日|京日|广日|杭日)+/gi,
    "新加坡": /((?:\bSG\b)|Singapore|Changi|新加坡|狮城|深新|沪新|呼新|京新|广新|杭新)+/gi,
    "韩国": /((?:\bKR\b)|South[\s-]?Korea|Korea|Seoul|Incheon|Busan|Chuncheon|韩国|首尔|仁川|釜山|春川)+/gi,
    "印尼": /((?:\bID\b)|Indonesia|Jakarta|Bali|Surabaya|印尼|印度尼西亚|雅加达|巴厘岛|泗水)+/gi,
    "印度": /((?:\bIN\b)|India|Mumbai|New[\s-]?Delhi|Bangalore|Chennai|Kolkata|Hyderabad|印度|孟买|新德里|班加罗尔|钦奈|加尔各答|海得拉巴)+/gi,
    "越南": /((?:\bVN\b)|Vietnam|Hanoi|Ho[\s-]?Chi[\s-]?Minh|Da[\s-]?Nang|越南|河内|胡志明市|岘港)+/gi,
    "泰国": /((?:\bTH\b)|Thailand|Bangkok|Phuket|Chiang[\s-]?Mai|泰国|曼谷|普吉|清迈)+/gi,
    "菲律宾": /((?:\bPH\b)|Philippines|Manila|Cebu|Davao|菲律宾|马尼拉|宿务|达沃)+/gi,
    "马来西亚": /((?:\bMY\b)|Malaysia|Kuala[\s-]?Lumpur|Johor[\s-]?Bahru|Penang|马来西亚|吉隆坡|新山|槟城)+/gi,

    // 美洲
    "美国": /((?:\bUSA?\b)|United[\s-_]+States|Los[\s-_]+Angeles|San[\s-_]+Jose|Silicon[\s-_]+Valley|San[\s-_]+Francisco|Santa[\s-_]+Clara|Seattle|Chicago|New[\s-_]+York|Miami|Dallas|Phoenix|Fremont|Atlanta|Boston|Las[\s-_]+Vegas|Houston|Ashburn|Buffalo|Washington|D\.C\.|Oregon|Portland|Virginia|Ohio|Texas|Florida|Illinois|Arizona|Orem|Kansas|美国|洛杉矶|圣何塞|硅谷|旧金山|圣克拉拉|西雅图|芝加哥|纽约|迈阿密|达拉斯|凤凰城|弗里蒙特|亚特兰大|波士顿|拉斯维加斯|休斯顿|阿什本|水牛城|华盛顿|俄勒冈|波特兰|弗吉尼亚|俄亥俄|德克萨斯|德州|佛罗里达|伊利诺伊|亚利桑那|奥勒姆|堪萨斯|休斯敦|深美|沪美|呼美|京美|广美|杭美)+/gi,
    "加拿大": /((?:\bCA\b)|Canada|Toronto|Vancouver|Montreal|Quebec|Ottawa|Calgary|Edmonton|Ontario|加拿大|多伦多|温哥华|蒙特利尔|魁北克|渥太华|卡尔加里|埃德蒙顿|安大略)+/gi,
    "巴西": /((?:\bBR\b)|Brazil|Sao[\s-_]+Paulo|Rio[\s-_]+de[\s-_]+Janeiro|Brasilia|巴西|圣保罗|里约热内卢|巴西利亚)+/gi,
    "阿根廷": /((?:\bAR\b)|Argentina|Buenos[\s-_]+Aires|阿根廷|布宜诺斯艾利斯)+/gi,
    "墨西哥": /((?:\bMX\b)|Mexico|Mexico[\s-_]+City|Cancun|Guadalajara|墨西哥|墨西哥城|坎昆|瓜达拉哈拉)+/gi,
    "智利": /((?:\bCL\b)|Chile|Santiago|智利|圣地亚哥)+/gi,

    // 欧洲
    "英国": /((?:\bUK\b)|Great[\s-_]+Britain|United[\s-_]+Kingdom|London|Manchester|Cardiff|England|Scotland|Wales|Northern[\s-_]+Ireland|英国|伦敦|曼彻斯特|加的夫|英格兰|苏格兰|威尔士|北爱尔兰|深英|沪英|呼英|京英|广英|杭英)+/gi,
    "德国": /((?:\bDE\b)|Germany|Deutschland|Frankfurt|Berlin|Dusseldorf|Munich|Hamburg|Cologne|德国|法兰克福|柏林|杜塞尔多夫|慕尼黑|汉堡|科隆|深德|沪德|呼德|京德|广德|杭德)+/gi,
    "法国": /((?:\bFR\b)|France|Paris|Marseille|Lyon|Nice|Toulouse|法国|巴黎|马赛|里昂|尼斯|图卢兹)+/gi,
    "俄罗斯": /((?:\bRU\b)|Russia|Moscow|St\.?[\s-]?Petersburg|Novosibirsk|Siberia|Khabarovsk|俄罗斯|莫斯科|圣彼得堡|新西伯利亚|西伯利亚|伯力)+/gi,
    "荷兰": /((?:\bNL\b)|Netherlands|Amsterdam|Rotterdam|The[\s-]?Hague|荷兰|阿姆斯特丹|鹿特丹|海牙)+/gi,
    // [Critical] 比利时支持 (Belgium Support)
    "比利时": /((?:\bBE\b)|Belgium|Brussels|Antwerp|Ghent|比利时|布鲁塞尔|安特卫普|根特)+/gi,
    "意大利": /((?:\bIT\b)|Italy|Milan|Rome|Venice|Florence|Naples|意大利|米兰|罗马|威尼斯|佛罗伦萨|那不勒斯)+/gi,
    "土耳其": /((?:\bTR\b)|Turkey|Istanbul|Ankara|土耳其|伊斯坦布尔|安卡拉)+/gi,
    "西班牙": /((?:\bES\b)|Spain|Madrid|Barcelona|Valencia|Seville|西班牙|马德里|巴塞罗那|瓦伦西亚|塞维利亚)+/gi,
    "瑞士": /((?:\bCH\b)|Switzerland|Zurich|Geneva|Bern|Basel|瑞士|苏黎世|日内瓦|伯尔尼|巴塞尔)+/gi,
    "瑞典": /((?:\bSE\b)|Sweden|Stockholm|Gothenburg|瑞典|斯德哥尔摩|哥德堡)+/gi,
    "爱尔兰": /((?:\bIE\b)|Ireland|Dublin|Cork|爱尔兰|都柏林|科克)+/gi,
    "乌克兰": /((?:\bUA\b)|Ukraine|Kyiv|Kiev|Lviv|Odessa|乌克兰|基辅|利沃夫|敖德萨)+/gi,
    "波兰": /((?:\bPL\b)|Poland|Warsaw|Krakow|波兰|华沙|克拉科夫)+/gi,
    "波黑": /((?:\bBA\b)|Bosnia.*Herzegovina|Sarajevo|波斯尼亚和黑塞哥维那|波斯尼亚|黑塞哥维那|波黑|萨拉热窝)+/gi,
    "芬兰": /((?:\bFI\b)|Finland|Helsinki|Espoo|芬兰|赫尔辛基|埃斯波)+/gi,
    "挪威": /((?:\bNO\b)|Norway|Oslo|Bergen|挪威|奥斯陆|卑尔根)+/gi,

    // 大洋洲
    "澳大利亚": /((?:\bAU\b)|Australia|Sydney|Melbourne|Brisbane|Perth|Adelaide|Canberra|澳大利亚|澳洲|悉尼|墨尔本|布里斯班|珀斯|阿德莱德|堪培拉|深澳|沪澳|呼澳|京澳|广澳|杭澳)+/gi,
    "新西兰": /((?:\bNZ\b)|New[\s-]?Zealand|Auckland|Wellington|Christchurch|新西兰|奥克兰|惠灵顿|克赖斯特彻奇)+/gi,

    // 中东/非洲
    "以色列": /((?:\bIL\b)|Israel|Tel[\s-]?Aviv|Jerusalem|Haifa|以色列|特拉维夫|耶路撒冷|海法)+/gi,
    "阿联酋": /((?:\bAE\b)|United[\s-]?Arab[\s-]?Emirates|Dubai|Abu[\s-]?Dhabi|阿联酋|迪拜|阿布扎比|阿拉伯联合酋长国)+/gi,
    "南非": /((?:\bZA\b)|South[\s-]?Africa|Johannesburg|Cape[\s-]?Town|南非|约翰内斯堡|开普敦)+/gi
};

// 1.3 国家/地区数据库 (Country DB)
// 包含: 旗帜 (flag), 二位代码 (code), 中文简称 (name), 英文全称 (full)
const CountryDB = [
   { flag: '🇦🇨', code: 'AC', name: '阿森松岛', full: 'Ascension Island' },
   { flag: '🇦🇩', code: 'AD', name: '安道尔', full: 'Andorra' },
   { flag: '🇦🇪', code: 'AE', name: '阿联酋', full: 'United Arab Emirates' },
   { flag: '🇦🇫', code: 'AF', name: '阿富汗', full: 'Afghanistan' },
   { flag: '🇦🇬', code: 'AG', name: '安提瓜', full: 'Antigua & Barbuda' },
   { flag: '🇦🇮', code: 'AI', name: '安圭拉', full: 'Anguilla' },
   { flag: '🇦🇱', code: 'AL', name: '阿尔巴尼亚', full: 'Albania' },
   { flag: '🇦🇲', code: 'AM', name: '亚美尼亚', full: 'Armenia' },
   { flag: '🇦🇴', code: 'AO', name: '安哥拉', full: 'Angola' },
   { flag: '🇦🇶', code: 'AQ', name: '南极', full: 'Antarctica' },
   { flag: '🇦🇷', code: 'AR', name: '阿根廷', full: 'Argentina' },
   { flag: '🇦🇸', code: 'AS', name: '美属萨摩亚', full: 'American Samoa' },
   { flag: '🇦🇹', code: 'AT', name: '奥地利', full: 'Austria' },
   { flag: '🇦🇺', code: 'AU', name: '澳大利亚', full: 'Australia' },
   { flag: '🇦🇼', code: 'AW', name: '阿鲁巴', full: 'Aruba' },
   { flag: '🇦🇽', code: 'AX', name: '奥兰群岛', full: 'Åland Islands' },
   { flag: '🇦🇿', code: 'AZ', name: '阿塞拜疆', full: 'Azerbaijan' },
   { flag: '🇧🇦', code: 'BA', name: '波黑', full: 'Bosnia & Herzegovina', alias: '波斯尼亚和黑塞哥维那' },
   { flag: '🇧🇧', code: 'BB', name: '巴巴多斯', full: 'Barbados' },
   { flag: '🇧🇩', code: 'BD', name: '孟加拉国', full: 'Bangladesh' },
   { flag: '🇧🇪', code: 'BE', name: '比利时', full: 'Belgium' },
   { flag: '🇧🇫', code: 'BF', name: '布基纳法索', full: 'Burkina Faso' },
   { flag: '🇧🇬', code: 'BG', name: '保加利亚', full: 'Bulgaria' },
   { flag: '🇧🇭', code: 'BH', name: '巴林', full: 'Bahrain' },
   { flag: '🇧🇮', code: 'BI', name: '布隆迪', full: 'Burundi' },
   { flag: '🇧🇯', code: 'BJ', name: '贝宁', full: 'Benin' },
   { flag: '🇧🇱', code: 'BL', name: '圣巴泰勒米', full: 'St. Barthélemy' },
   { flag: '🇧🇲', code: 'BM', name: '百慕大', full: 'Bermuda' },
   { flag: '🇧🇳', code: 'BN', name: '文莱', full: 'Brunei' },
   { flag: '🇧🇴', code: 'BO', name: '玻利维亚', full: 'Bolivia' },
   { flag: '🇧🇶', code: 'BQ', name: '荷属加勒比', full: 'Caribbean Netherlands' },
   { flag: '🇧🇷', code: 'BR', name: '巴西', full: 'Brazil' },
   { flag: '🇧🇸', code: 'BS', name: '巴哈马', full: 'Bahamas' },
   { flag: '🇧🇹', code: 'BT', name: '不丹', full: 'Bhutan' },
   { flag: '🇧🇻', code: 'BV', name: '布韦岛', full: 'Bouvet Island' },
   { flag: '🇧🇼', code: 'BW', name: '博茨瓦纳', full: 'Botswana' },
   { flag: '🇧🇾', code: 'BY', name: '白俄罗斯', full: 'Belarus' },
   { flag: '🇧🇿', code: 'BZ', name: '伯利兹', full: 'Belize' },
   { flag: '🇨🇦', code: 'CA', name: '加拿大', full: 'Canada' },
   { flag: '🇨🇨', code: 'CC', name: '科科斯群岛', full: 'Cocos (Keeling) Islands' },
   { flag: '🇨🇩', code: 'CD', name: '刚果(金)', full: 'Congo - Kinshasa' },
   { flag: '🇨🇫', code: 'CF', name: '中非共和国', full: 'Central African Republic' },
   { flag: '🇨🇬', code: 'CG', name: '刚果(布)', full: 'Congo - Brazzaville' },
   { flag: '🇨🇭', code: 'CH', name: '瑞士', full: 'Switzerland' },
   { flag: '🇨🇮', code: 'CI', name: '科特迪瓦', full: 'Côte d’Ivoire' },
   { flag: '🇨🇰', code: 'CK', name: '库克群岛', full: 'Cook Islands' },
   { flag: '🇨🇱', code: 'CL', name: '智利', full: 'Chile' },
   { flag: '🇨🇲', code: 'CM', name: '喀麦隆', full: 'Cameroon' },
   { flag: '🇨🇳', code: 'CN', name: '中国', full: 'China' },
   { flag: '🇨🇴', code: 'CO', name: '哥伦比亚', full: 'Colombia' },
   { flag: '🇨🇵', code: 'CP', name: '克利珀顿岛', full: 'Clipperton Island' },
   { flag: '🇨🇷', code: 'CR', name: '哥斯达黎加', full: 'Costa Rica' },
   { flag: '🇨🇺', code: 'CU', name: '古巴', full: 'Cuba' },
   { flag: '🇨🇻', code: 'CV', name: '佛得角', full: 'Cape Verde' },
   { flag: '🇨🇼', code: 'CW', name: '库拉索', full: 'Curaçao' },
   { flag: '🇨🇽', code: 'CX', name: '圣诞岛', full: 'Christmas Island' },
   { flag: '🇨🇾', code: 'CY', name: '塞浦路斯', full: 'Cyprus' },
   { flag: '🇨🇿', code: 'CZ', name: '捷克', full: 'Czechia' },
   { flag: '🇩🇪', code: 'DE', name: '德国', full: 'Germany' },
   { flag: '🇩🇬', code: 'DG', name: '迪戈加西亚', full: 'Diego Garcia' },
   { flag: '🇩🇯', code: 'DJ', name: '吉布提', full: 'Djibouti' },
   { flag: '🇩🇰', code: 'DK', name: '丹麦', full: 'Denmark' },
   { flag: '🇩🇲', code: 'DM', name: '多米尼克', full: 'Dominica' },
   { flag: '🇩🇴', code: 'DO', name: '多米尼加共和国', full: 'Dominican Republic' },
   { flag: '🇩🇿', code: 'DZ', name: '阿尔及利亚', full: 'Algeria' },
   { flag: '🇪🇦', code: 'EA', name: '休达及梅利利亚', full: 'Ceuta & Melilla' },
   { flag: '🇪🇨', code: 'EC', name: '厄瓜多尔', full: 'Ecuador' },
   { flag: '🇪🇪', code: 'EE', name: '爱沙尼亚', full: 'Estonia' },
   { flag: '🇪🇬', code: 'EG', name: '埃及', full: 'Egypt' },
   { flag: '🇪🇭', code: 'EH', name: '西撒哈拉', full: 'Western Sahara' },
   { flag: '🇪🇷', code: 'ER', name: '厄立特里亚', full: 'Eritrea' },
   { flag: '🇪🇸', code: 'ES', name: '西班牙', full: 'Spain' },
   { flag: '🇪🇹', code: 'ET', name: '埃塞俄比亚', full: 'Ethiopia' },
   { flag: '🇪🇺', code: 'EU', name: '欧盟', full: 'European Union' },
   { flag: '🇫🇮', code: 'FI', name: '芬兰', full: 'Finland' },
   { flag: '🇫🇯', code: 'FJ', name: '斐济', full: 'Fiji' },
   { flag: '🇫🇰', code: 'FK', name: '福克兰群岛', full: 'Falkland Islands' },
   { flag: '🇫🇲', code: 'FM', name: '密克罗尼西亚', full: 'Micronesia' },
   { flag: '🇫🇴', code: 'FO', name: '法罗群岛', full: 'Faroe Islands' },
   { flag: '🇫🇷', code: 'FR', name: '法国', full: 'France' },
   { flag: '🇬🇦', code: 'GA', name: '加蓬', full: 'Gabon' },
   { flag: '🇬🇧', code: 'GB', name: '英国', full: 'United Kingdom' },
   { flag: '🇬🇩', code: 'GD', name: '格林纳达', full: 'Grenada' },
   { flag: '🇬🇪', code: 'GE', name: '格鲁吉亚', full: 'Georgia' },
   { flag: '🇬🇫', code: 'GF', name: '法属圭亚那', full: 'French Guiana' },
   { flag: '🇬🇬', code: 'GG', name: '根西', full: 'Guernsey' },
   { flag: '🇬🇭', code: 'GH', name: '加纳', full: 'Ghana' },
   { flag: '🇬🇮', code: 'GI', name: '直布罗陀', full: 'Gibraltar' },
   { flag: '🇬🇱', code: 'GL', name: '格陵兰', full: 'Greenland' },
   { flag: '🇬🇲', code: 'GM', name: '冈比亚', full: 'Gambia' },
   { flag: '🇬🇳', code: 'GN', name: '几内亚', full: 'Guinea' },
   { flag: '🇬🇵', code: 'GP', name: '瓜德罗普', full: 'Guadeloupe' },
   { flag: '🇬🇶', code: 'GQ', name: '赤道几内亚', full: 'Equatorial Guinea' },
   { flag: '🇬🇷', code: 'GR', name: '希腊', full: 'Greece' },
   { flag: '🇬🇸', code: 'GS', name: '南乔治亚', full: 'South Georgia & South Sandwich Islands' },
   { flag: '🇬🇹', code: 'GT', name: '危地马拉', full: 'Guatemala' },
   { flag: '🇬🇺', code: 'GU', name: '关岛', full: 'Guam' },
   { flag: '🇬🇼', code: 'GW', name: '几内亚比绍', full: 'Guinea-Bissau' },
   { flag: '🇬🇾', code: 'GY', name: '圭亚那', full: 'Guyana' },
   { flag: '🇭🇰', code: 'HK', name: '香港', full: 'Hong Kong' },
   { flag: '🇭🇲', code: 'HM', name: '赫德岛', full: 'Heard & McDonald Islands' },
   { flag: '🇭🇳', code: 'HN', name: '洪都拉斯', full: 'Honduras' },
   { flag: '🇭🇷', code: 'HR', name: '克罗地亚', full: 'Croatia' },
   { flag: '🇭🇹', code: 'HT', name: '海地', full: 'Haiti' },
   { flag: '🇭🇺', code: 'HU', name: '匈牙利', full: 'Hungary' },
   { flag: '🇮🇨', code: 'IC', name: '加那利群岛', full: 'Canary Islands' },
   { flag: '🇮🇩', code: 'ID', name: '印尼', full: 'Indonesia' },
   { flag: '🇮🇪', code: 'IE', name: '爱尔兰', full: 'Ireland' },
   { flag: '🇮🇱', code: 'IL', name: '以色列', full: 'Israel' },
   { flag: '🇮🇲', code: 'IM', name: '马恩岛', full: 'Isle of Man' },
   { flag: '🇮🇳', code: 'IN', name: '印度', full: 'India' },
   { flag: '🇮🇴', code: 'IO', name: '英属印度洋领地', full: 'British Indian Ocean Territory' },
   { flag: '🇮🇶', code: 'IQ', name: '伊拉克', full: 'Iraq' },
   { flag: '🇮🇷', code: 'IR', name: '伊朗', full: 'Iran' },
   { flag: '🇮🇸', code: 'IS', name: '冰岛', full: 'Iceland' },
   { flag: '🇮🇹', code: 'IT', name: '意大利', full: 'Italy' },
   { flag: '🇯🇪', code: 'JE', name: '泽西岛', full: 'Jersey' },
   { flag: '🇯🇲', code: 'JM', name: '牙买加', full: 'Jamaica' },
   { flag: '🇯🇴', code: 'JO', name: '约旦', full: 'Jordan' },
   { flag: '🇯🇵', code: 'JP', name: '日本', full: 'Japan' },
   { flag: '🇰🇪', code: 'KE', name: '肯尼亚', full: 'Kenya' },
   { flag: '🇰🇬', code: 'KG', name: '吉尔吉斯斯坦', full: 'Kyrgyzstan' },
   { flag: '🇰🇭', code: 'KH', name: '柬埔寨', full: 'Cambodia' },
   { flag: '🇰🇮', code: 'KI', name: '基里巴斯', full: 'Kiribati' },
   { flag: '🇰🇲', code: 'KM', name: '科摩罗', full: 'Comoros' },
   { flag: '🇰🇳', code: 'KN', name: '圣基茨', full: 'St. Kitts & Nevis' },
   { flag: '🇰🇵', code: 'KP', name: '朝鲜', full: 'North Korea' },
   { flag: '🇰🇷', code: 'KR', name: '韩国', full: 'South Korea' },
   { flag: '🇰🇼', code: 'KW', name: '科威特', full: 'Kuwait' },
   { flag: '🇰🇾', code: 'KY', name: '开曼群岛', full: 'Cayman Islands' },
   { flag: '🇰🇿', code: 'KZ', name: '哈萨克斯坦', full: 'Kazakhstan' },
   { flag: '🇱🇦', code: 'LA', name: '老挝', full: 'Laos' },
   { flag: '🇱🇧', code: 'LB', name: '黎巴嫩', full: 'Lebanon' },
   { flag: '🇱🇨', code: 'LC', name: '圣卢西亚', full: 'St. Lucia' },
   { flag: '🇱🇮', code: 'LI', name: '列支敦士登', full: 'Liechtenstein' },
   { flag: '🇱🇰', code: 'LK', name: '斯里兰卡', full: 'Sri Lanka' },
   { flag: '🇱🇷', code: 'LR', name: '利比里亚', full: 'Liberia' },
   { flag: '🇱🇸', code: 'LS', name: '莱索托', full: 'Lesotho' },
   { flag: '🇱🇹', code: 'LT', name: '立陶宛', full: 'Lithuania' },
   { flag: '🇱🇺', code: 'LU', name: '卢森堡', full: 'Luxembourg' },
   { flag: '🇱🇻', code: 'LV', name: '拉脱维亚', full: 'Latvia' },
   { flag: '🇱🇾', code: 'LY', name: '利比亚', full: 'Libya' },
   { flag: '🇲🇦', code: 'MA', name: '摩洛哥', full: 'Morocco' },
   { flag: '🇲🇨', code: 'MC', name: '摩纳哥', full: 'Monaco' },
   { flag: '🇲🇩', code: 'MD', name: '摩尔多瓦', full: 'Moldova' },
   { flag: '🇲🇪', code: 'ME', name: '黑山', full: 'Montenegro' },
   { flag: '🇲🇫', code: 'MF', name: '圣马丁', full: 'St. Martin' },
   { flag: '🇲🇬', code: 'MG', name: '马达加斯加', full: 'Madagascar' },
   { flag: '🇲🇭', code: 'MH', name: '马绍尔群岛', full: 'Marshall Islands' },
   { flag: '🇲🇰', code: 'MK', name: '马其顿', full: 'North Macedonia' },
   { flag: '🇲🇱', code: 'ML', name: '马里', full: 'Mali' },
   { flag: '🇲🇲', code: 'MM', name: '缅甸', full: 'Myanmar (Burma)' },
   { flag: '🇲🇳', code: 'MN', name: '蒙古', full: 'Mongolia' },
   { flag: '🇲🇴', code: 'MO', name: '澳门', full: 'Macao' },
   { flag: '🇲🇵', code: 'MP', name: '北马里亚纳', full: 'Northern Mariana Islands' },
   { flag: '🇲🇶', code: 'MQ', name: '马提尼克', full: 'Martinique' },
   { flag: '🇲🇷', code: 'MR', name: '毛里塔尼亚', full: 'Mauritania' },
   { flag: '🇲🇸', code: 'MS', name: '蒙特塞拉特', full: 'Montserrat' },
   { flag: '🇲🇹', code: 'MT', name: '马耳他', full: 'Malta' },
   { flag: '🇲🇺', code: 'MU', name: '毛里求斯', full: 'Mauritius' },
   { flag: '🇲🇻', code: 'MV', name: '马尔代夫', full: 'Maldives' },
   { flag: '🇲🇼', code: 'MW', name: '马拉维', full: 'Malawi' },
   { flag: '🇲🇽', code: 'MX', name: '墨西哥', full: 'Mexico' },
   { flag: '🇲🇾', code: 'MY', name: '马来西亚', full: 'Malaysia' },
   { flag: '🇲🇿', code: 'MZ', name: '莫桑比克', full: 'Mozambique' },
   { flag: '🇳🇦', code: 'NA', name: '纳米比亚', full: 'Namibia' },
   { flag: '🇳🇨', code: 'NC', name: '新喀里多尼亚', full: 'New Caledonia' },
   { flag: '🇳🇪', code: 'NE', name: '尼日尔', full: 'Niger' },
   { flag: '🇳🇫', code: 'NF', name: '诺福克岛', full: 'Norfolk Island' },
   { flag: '🇳🇬', code: 'NG', name: '尼日利亚', full: 'Nigeria' },
   { flag: '🇳🇮', code: 'NI', name: '尼加拉瓜', full: 'Nicaragua' },
   { flag: '🇳🇱', code: 'NL', name: '荷兰', full: 'Netherlands' },
   { flag: '🇳🇴', code: 'NO', name: '挪威', full: 'Norway' },
   { flag: '🇳🇵', code: 'NP', name: '尼泊尔', full: 'Nepal' },
   { flag: '🇳🇷', code: 'NR', name: '瑙鲁', full: 'Nauru' },
   { flag: '🇳🇺', code: 'NU', name: '纽埃', full: 'Niue' },
   { flag: '🇳🇿', code: 'NZ', name: '新西兰', full: 'New Zealand' },
   { flag: '🇴🇲', code: 'OM', name: '阿曼', full: 'Oman' },
   { flag: '🇵🇦', code: 'PA', name: '巴拿马', full: 'Panama' },
   { flag: '🇵🇪', code: 'PE', name: '秘鲁', full: 'Peru' },
   { flag: '🇵🇫', code: 'PF', name: '法属波利尼西亚', full: 'French Polynesia' },
   { flag: '🇵🇬', code: 'PG', name: '巴布亚新几内亚', full: 'Papua New Guinea' },
   { flag: '🇵🇭', code: 'PH', name: '菲律宾', full: 'Philippines' },
   { flag: '🇵🇰', code: 'PK', name: '巴基斯坦', full: 'Pakistan' },
   { flag: '🇵🇱', code: 'PL', name: '波兰', full: 'Poland' },
   { flag: '🇵🇲', code: 'PM', name: '圣皮埃尔', full: 'St. Pierre & Miquelon' },
   { flag: '🇵🇳', code: 'PN', name: '皮特凯恩', full: 'Pitcairn Islands' },
   { flag: '🇵🇷', code: 'PR', name: '波多黎各', full: 'Puerto Rico' },
   { flag: '🇵🇸', code: 'PS', name: '巴勒斯坦', full: 'Palestinian Territories' },
   { flag: '🇵🇹', code: 'PT', name: '葡萄牙', full: 'Portugal' },
   { flag: '🇵🇼', code: 'PW', name: '帕劳', full: 'Palau' },
   { flag: '🇵🇾', code: 'PY', name: '巴拉圭', full: 'Paraguay' },
   { flag: '🇶🇦', code: 'QA', name: '卡塔尔', full: 'Qatar' },
   { flag: '🇷🇪', code: 'RE', name: '留尼汪', full: 'Réunion' },
   { flag: '🇷🇴', code: 'RO', name: '罗马尼亚', full: 'Romania' },
   { flag: '🇷🇸', code: 'RS', name: '塞尔维亚', full: 'Serbia' },
   { flag: '🇷🇺', code: 'RU', name: '俄罗斯', full: 'Russia' },
   { flag: '🇷🇼', code: 'RW', name: '卢旺达', full: 'Rwanda' },
   { flag: '🇸🇦', code: 'SA', name: '沙特阿拉伯', full: 'Saudi Arabia' },
   { flag: '🇸🇧', code: 'SB', name: '所罗门群岛', full: 'Solomon Islands' },
   { flag: '🇸🇨', code: 'SC', name: '塞舌尔', full: 'Seychelles' },
   { flag: '🇸🇩', code: 'SD', name: '苏丹', full: 'Sudan' },
   { flag: '🇸🇪', code: 'SE', name: '瑞典', full: 'Sweden' },
   { flag: '🇸🇬', code: 'SG', name: '新加坡', full: 'Singapore' },
   { flag: '🇸🇭', code: 'SH', name: '圣赫勒拿', full: 'St. Helena' },
   { flag: '🇸🇮', code: 'SI', name: '斯洛文尼亚', full: 'Slovenia' },
   { flag: '🇸🇯', code: 'SJ', name: '斯瓦尔巴', full: 'Svalbard & Jan Mayen' },
   { flag: '🇸🇰', code: 'SK', name: '斯洛伐克', full: 'Slovakia' },
   { flag: '🇸🇱', code: 'SL', name: '塞拉利昂', full: 'Sierra Leone' },
   { flag: '🇸🇲', code: 'SM', name: '圣马力诺', full: 'San Marino' },
   { flag: '🇸🇳', code: 'SN', name: '塞内加尔', full: 'Senegal' },
   { flag: '🇸🇴', code: 'SO', name: '索马里', full: 'Somalia' },
   { flag: '🇸🇷', code: 'SR', name: '苏里南', full: 'Suriname' },
   { flag: '🇸🇸', code: 'SS', name: '南苏丹', full: 'South Sudan' },
   { flag: '🇸🇹', code: 'ST', name: '圣多美', full: 'São Tomé & Príncipe' },
   { flag: '🇸🇻', code: 'SV', name: '萨尔瓦多', full: 'El Salvador' },
   { flag: '🇸🇽', code: 'SX', name: '荷属圣马丁', full: 'Sint Maarten' },
   { flag: '🇸🇾', code: 'SY', name: '叙利亚', full: 'Syria' },
   { flag: '🇸🇿', code: 'SZ', name: '斯威士兰', full: 'Eswatini' },
   { flag: '🇹🇦', code: 'TA', name: '特里斯坦', full: 'Tristan da Cunha' },
   { flag: '🇹🇨', code: 'TC', name: '特克斯', full: 'Turks & Caicos Islands' },
   { flag: '🇹🇩', code: 'TD', name: '乍得', full: 'Chad' },
   { flag: '🇹🇫', code: 'TF', name: '法属南部领地', full: 'French Southern Territories' },
   { flag: '🇹🇬', code: 'TG', name: '多哥', full: 'Togo' },
   { flag: '🇹🇭', code: 'TH', name: '泰国', full: 'Thailand' },
   { flag: '🇹🇯', code: 'TJ', name: '塔吉克斯坦', full: 'Tajikistan' },
   { flag: '🇹🇰', code: 'TK', name: '托克劳', full: 'Tokelau' },
   { flag: '🇹🇱', code: 'TL', name: '东帝汶', full: 'Timor-Leste' },
   { flag: '🇹🇲', code: 'TM', name: '土库曼斯坦', full: 'Turkmenistan' },
   { flag: '🇹🇳', code: 'TN', name: '突尼斯', full: 'Tunisia' },
   { flag: '🇹🇴', code: 'TO', name: '汤加', full: 'Tonga' },
   { flag: '🇹🇷', code: 'TR', name: '土耳其', full: 'Turkey' },
   { flag: '🇹🇹', code: 'TT', name: '特立尼达和多巴哥', full: 'Trinidad & Tobago' },
   { flag: '🇹🇻', code: 'TV', name: '图瓦卢', full: 'Tuvalu' },
   { flag: '🇹🇼', code: 'TW', name: '台湾', full: 'Taiwan' },
   { flag: '🇹🇿', code: 'TZ', name: '坦桑尼亚', full: 'Tanzania' },
   { flag: '🇺🇦', code: 'UA', name: '乌克兰', full: 'Ukraine' },
   { flag: '🇺🇬', code: 'UG', name: '乌干达', full: 'Uganda' },
   { flag: '🇺🇲', code: 'UM', name: '美属外岛', full: 'U.S. Outlying Islands' },
   { flag: '🇺🇳', code: 'UN', name: '联合国', full: 'United Nations' },
   { flag: '🇺🇸', code: 'US', name: '美国', full: 'United States' },
   { flag: '🇺🇾', code: 'UY', name: '乌拉圭', full: 'Uruguay' },
   { flag: '🇺🇿', code: 'UZ', name: '乌兹别克斯坦', full: 'Uzbekistan' },
   { flag: '🇻🇦', code: 'VA', name: '梵蒂冈', full: 'Vatican City' },
   { flag: '🇻🇨', code: 'VC', name: '圣文森特', full: 'St. Vincent & Grenadines' },
   { flag: '🇻🇪', code: 'VE', name: '委内瑞拉', full: 'Venezuela' },
   { flag: '🇻🇬', code: 'VG', name: '英属维京群岛', full: 'British Virgin Islands' },
   { flag: '🇻🇮', code: 'VI', name: '美属维尔京群岛', full: 'U.S. Virgin Islands' },
   { flag: '🇻🇳', code: 'VN', name: '越南', full: 'Vietnam' },
   { flag: '🇻🇺', code: 'VU', name: '瓦努阿图', full: 'Vanuatu' },
   { flag: '🇼🇫', code: 'WF', name: '瓦利斯', full: 'Wallis & Futuna' },
   { flag: '🇼🇸', code: 'WS', name: '萨摩亚', full: 'Samoa' },
   { flag: '🇽🇰', code: 'XK', name: '科索沃', full: 'Kosovo' },
   { flag: '🇾🇪', code: 'YE', name: '也门', full: 'Yemen' },
   { flag: '🇾🇹', code: 'YT', name: '马约特', full: 'Mayotte' },
   { flag: '🇿🇦', code: 'ZA', name: '南非', full: 'South Africa' },
   { flag: '🇿🇲', code: 'ZM', name: '赞比亚', full: 'Zambia' },
   { flag: '🇿🇼', code: 'ZW', name: '津巴布韦', full: 'Zimbabwe' },
   { flag: '🇬🇧', code: 'UK', name: '英国', full: 'United Kingdom' }, // 补充常见缩写
   { flag: '🇰🇷', code: 'KR', name: '韩国', full: 'South Korea' }, // 补充
];

// 1.4 动态国旗规则 (Auto-generated Rules)
// 初始化时自动填充
const FlagRules = [
    // 优先匹配的手动规则 (Manual Overrides)
    { regex: /((波斯尼亚和黑塞哥维那|波黑|萨拉热窝|Bosnia|Sarajevo))/i, emoji: '🇧🇦' },
    { regex: /(专属纯净住宅)/i, emoji: '🇺🇸' },
    { regex: /((美[国國]|华盛顿|波特兰|达拉斯|俄勒冈|凤凰城|菲尼克斯|费利蒙|弗里蒙特|硅谷|旧金山|拉斯维加斯|洛杉|圣何塞|圣荷西|圣塔?克拉拉|西雅图|芝加哥|哥伦布|纽约|阿什本|纽瓦克|丹佛|加利福尼亚|弗吉尼亚|马纳萨斯|俄亥俄|得克萨斯|[佐乔]治亚|亚特兰大|佛罗里达|迈阿密))/i, emoji: '🇺🇸' },
    { regex: /((日本|东京|大阪|名古屋|埼玉|福冈))/i, emoji: '🇯🇵' },
    { regex: /((新加坡|[狮獅]城))/i, emoji: '🇸🇬' },
    { regex: /(([台臺][湾灣北]|新[北竹]|彰化|高雄))/i, emoji: '🇹🇼' },
    { regex: /((俄[国國]|俄[罗羅]斯|莫斯科|圣彼得堡|西伯利亚|伯力|哈巴罗夫斯克))/i, emoji: '🇷🇺' },
    { regex: /((英[国國]|英格兰|伦敦|加的夫|曼彻斯特|伯克郡))/i, emoji: '🇬🇧' },
    { regex: /((加拿大|[枫楓][叶葉]|多伦多|蒙特利尔|温哥华))/i, emoji: '🇨🇦' },
    { regex: /((法[国國]|巴黎|马赛|斯特拉斯堡))/i, emoji: '🇫🇷' },
    { regex: /((朝[鲜鮮]))/i, emoji: '🇰🇵' },
    { regex: /(([韩韓][国國]|首尔|春川))/i, emoji: '🇰🇷' },
    { regex: /((爱尔兰|都柏林))/i, emoji: '🇮🇪' },
    { regex: /((德[国國]|法兰克福|柏林|杜塞尔多夫))/i, emoji: '🇩🇪' },
    { regex: /((印尼|印度尼西亚|雅加达))/i, emoji: '🇮🇩' },
    { regex: /((中[国國]|[广廣贵貴]州|深圳|北京|上海|[广廣山][东東西]|[河湖][北南]|天津|重[庆慶]|[辽遼][宁寧]|吉林|黑[龙龍]江|江[苏蘇西]|浙江|安徽|福建|[海云雲]南|四川|[陕陝]西|甘[肃肅]|青海|[内內]蒙古|西藏|[宁寧]夏|新疆))/i, emoji: '🇨🇳' }
];

// 自动填充 FlagRules
(function initFlagRules() {
    const initialFlagMap = {};
    CountryDB.forEach(item => {
        if (item.name) initialFlagMap[item.name] = item.flag;
        if (item.full) initialFlagMap[item.full] = item.flag;

        const escapeRegExp = (str) => str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const pattern = `(${escapeRegExp(item.name)}|${escapeRegExp(item.full)})`;
        FlagRules.push({
            regex: new RegExp(pattern, 'i'),
            emoji: item.flag
        });
    });
    // 保存排序后的关键词用于兜底匹配
    Constants.SORTED_COUNTRY_KEYS = Object.keys(initialFlagMap).sort((a, b) => b.length - a.length);
    Constants.COUNTRY_MAP = initialFlagMap;
})();


// ============================================================================
// 2. 工具函数 (Helper Functions)
// ============================================================================

const Utils = {
    /**
     * 第一步：基础清理
     * 执行正则替换，移除噪声、标准化格式
     */
    cleanName: (name) => {
        let cleaned = name;
        for (const rule of CleaningRules) {
            cleaned = cleaned.replace(rule.regex, rule.value);
        }
        return cleaned;
    },

    /**
     * 第二步：地名标准化
     * 将 "Hong Kong" 统一为 "香港"
     */
    standardizeRegion: (name) => {
        let standardized = name;
        for (const [key, regex] of Object.entries(RegionMap)) {
            standardized = standardized.replace(regex, key);
        }
        return standardized;
    },

    /**
     * 第三步：拆分与去重 (核心逻辑)
     * 分割字符串，移除重复项，并将 "美国AI" 拆分为 "美国" 和 "AI"
     */
    splitAndDedup: (name) => {
        // 3.1 初始拆分 (Split by separators)
        // 使用 [-_| s丨✈/] 进行拆分，过滤空值和完全重复项
        let uniqueParts = name.split(/[-_|\s丨✈\/]+/).filter((item, index, self) => {
            if (!item || item.trim() === "" || item === "[]") return false;
            // 简单去重
            if (self.indexOf(item) !== index) return false;

            // 智能去重: 只有在对方*严格长于*自己的前提下，才认为自己被长字符包含了。
            // 这是为了防止如果存在两个 "日本" 时触发互相包含的 bug。
            const isRedundant = self.some((other, otherIndex) => {
                if (index === otherIndex) return false;
                // [修复Bug] 增加 other.length <= item.length 的阻断，只有比自己长的词才有资格说是我的母词
                if (other.length <= item.length || !other.includes(item)) return false;
                const isNonAscii = /[^\x00-\x7F]/.test(item);
                const isNumeric = /^\d+$/.test(item);
                const isLong = item.length > 3;
                return isNonAscii || isNumeric || isLong;
            });
            return !isRedundant;
        });

        // 3.2 深度拆分 (Split combined regions)
        // 处理 "美国流媒体" -> "美国", "流媒体"
        const allRegions = [...Constants.PRIORITY_REGIONS, ...Object.keys(RegionMap)];
        const expandedParts = [];

        for (const part of uniqueParts) {
            let splitHappened = false;
            for (const region of allRegions) {
                // 如果发现 "RegionSuffix" 形式
                if (part.startsWith(region) && part.length > region.length) {
                    const suffix = part.substring(region.length).trim();
                    // 忽略纯数字 (如 "香港01" 不拆分)
                    if (!/^\d+$/.test(suffix)) {
                        expandedParts.push(region);
                        expandedParts.push(suffix);
                        splitHappened = true;
                        break;
                    }
                }
            }
            if (!splitHappened) {
                expandedParts.push(part);
            }
        }

        // [Critical] 再次去重 (Post-Split Deduplication)
        // 解决拆分后产生的重复 (如 "美国AI" 拆出 "AI", 若原本也有 "AI", 则需去重)
        return [...new Set(expandedParts)];
    },

    /**
     * 地区提升 (Region Promotion)
     * 将地区关键词移动到数组首位
     */
    promoteRegion: (parts) => {
        const allRegions = [...Constants.PRIORITY_REGIONS, ...Object.keys(RegionMap)];
        let regionIndex = -1;

        for (let i = 0; i < parts.length; i++) {
            const part = parts[i];
            // 严格前缀匹配 (如 "香港5")
            if (allRegions.some(region => part.startsWith(region))) {
                regionIndex = i;
                break;
            }
        }

        if (regionIndex > 0) {
            const regionPart = parts.splice(regionIndex, 1)[0];
            parts.unshift(regionPart); // Move to front
        }
        return parts;
    },

    /**
     * 智能标志检测 (Flag Detection)
     */
    detectFlag: (name) => {
        // 正则匹配
        for (const rule of FlagRules) {
            if (rule.regex.test(name)) return rule.emoji;
        }
        // 关键词兜底
        for (const key of Constants.SORTED_COUNTRY_KEYS) {
            if (name.toUpperCase().includes(key.toUpperCase())) {
                return Constants.COUNTRY_MAP[key];
            }
        }
        return "🏳️"; // Default
    },

    /**
     * 获取排序优先级
     */
    getPriority: (name) => {
        // 优先列表 + 剩余 RegionMap 键
        const allKeys = [...Constants.PRIORITY_REGIONS, ...Object.keys(RegionMap).filter(k => !Constants.PRIORITY_REGIONS.includes(k))];
        const index = allKeys.findIndex(k => name.includes(k));
        return index === -1 ? 9999 : index;
    },

    /**
     * 提取名称中的数字 (用于排序)
     */
    getNum: (name) => {
        const match = name.match(/(\d+)(?=\D*$)/);
        return match ? parseInt(match[1], 10) : 0;
    }
};

// ============================================================================
// 3. 主处理流程 (Main Pipeline)
// ============================================================================

/**
 * 核心处理函数 (脚本入口)
 */
function operator(proxies) {
    // Phase 1: Cleaning & Formatting (单个节点处理)
    const sortedProxies = proxies
        .filter(p => !Constants.INVALID_REGEX.test(p.name))
        .map(p => {
            let name = p.name;
            const protocol = p.type ? p.type.toLowerCase() : "unknown";

            // [新增能力] 初步判断：是否已完全满足我们的终极格式规范？
            // 校验格式并提取关键部位以供后期统一重新编号： Emoji + 空格 + 协议名(可选) + ✈(如果含协议) + Region(不含[数字]) + [数字] + ✈ + 内容
            const standardMatch = name.match(/^([\uD83C][\uDDE6-\uDDFF][\uD83C][\uDDE6-\uDDFF])\s+(?:([A-Za-z0-9]+)\s*✈\s*)?([^✈\[\]\|]+?)(?:\s*\[\d+\])(?:(?:\s*✈\s*|\s*\|\s*)(.*))?$/);

            if (standardMatch) {
                p.isPreFormatted = true;
                p.flag = standardMatch[1];
                p.protocol = standardMatch[2] || p.protocol;
                p.name = `${p.flag} ${p.protocol && p.protocol !== "unknown" ? p.protocol + ' ✈ ' : ''}${standardMatch[3]}${standardMatch[4] ? ' ✈ ' + standardMatch[4].trim() : ''}`;
                return p;
            }

            // [兼容旧逻辑] 若不满足终极规范，尝试匹配：Emoji + 空格 + Region(不含[数字]) + [数字] + ✈ + 内容
            const legacyMatch = name.match(/^([\uD83C][\uDDE6-\uDDFF][\uD83C][\uDDE6-\uDDFF])\s+([^✈\[\]\|]+?)(?:\[\d+\])?(?:(?:\s*✈\s*|\s*\|\s*)(.*))?$/);
            if (legacyMatch) {
                p.isPreFormatted = true;
                p.flag = legacyMatch[1];
                p.name = `${p.flag} ${p.protocol && p.protocol !== "unknown" ? p.protocol + ' ✈ ' : ''}${legacyMatch[2].trim()}${legacyMatch[3] ? ' ✈ ' + legacyMatch[3].trim() : ''}`;
                return p;
            }

            // Step 1: 基础清理
            name = Utils.cleanName(name);

            // Step 2: 地名标准化
            name = Utils.standardizeRegion(name);

            // Step 3: 拆分与去重
            let parts = Utils.splitAndDedup(name);

            // Step 4: 地区提升
            parts = Utils.promoteRegion(parts);

            // 临时重组用于后续处理
            let tempName = parts.join(Constants.SEPARATOR);

            // Step 5: 标志检测
            const flag = Utils.detectFlag(tempName);

            // Step 6: 后期处理 (Final Assembly)
            // 6.1 移除已有 Flag, IPv6 优化, 移除协议名
            tempName = tempName.replace(/[\uD83C][\uDDE6-\uDDFF][\uD83C][\uDDE6-\uDDFF]/g, "").trim();

            const serverAddress = p.server || p.address || "";
            if ((serverAddress.match(/:/g) || []).length >= 2) {
                tempName = tempName.replace(/ipv6/ig, "").trim();
                tempName = `IPv6 ${tempName}`;
            }

            tempName = tempName.replace(new RegExp(protocol, "ig"), "").trim();

            // 6.2 提取倍率 (x2)
            let multiplier = "";
            const multiplierMatch = tempName.match(/(?:[-_\s]+)?((?:\d+(?:\.\d+)?)\s?[x×])/i);
            if (multiplierMatch) {
                multiplier = multiplierMatch[1];
                tempName = tempName.replace(multiplierMatch[0], "");
            }

            // 6.3 最终清理
            tempName = tempName.trim().replace(/^[-_\s]+|[-_\s]+$/g, "");
            tempName = tempName.replace(/[-_\s]+(\d+)$/, "$1"); // 紧凑数字

            // 6.4 构造对象
            p.processedName = tempName; // 只有名称部分 (不含 flag/protocol)
            p.flag = flag;
            p.multiplier = multiplier;
            p.protocol = protocol;

            p.name = multiplier ? `${p.flag} ${protocol} ✈ ${tempName} ✈ ${multiplier.trim()}` : `${p.flag} ${protocol} ✈ ${tempName}`;

            return p;
        })
        .sort((a, b) => {
            // Phase 2: Sorting (排序)
            const prioA = Utils.getPriority(a.name);
            const prioB = Utils.getPriority(b.name);
            if (prioA !== prioB) return prioA - prioB;

            const numA = Utils.getNum(a.name);
            const numB = Utils.getNum(b.name);
            return numA - numB;
        });

    // Phase 3: Renumbering (重编号)
    const nameCounts = {};

    return sortedProxies.map(p => {
        if (p.isPreFormatted) {
            delete p.isPreFormatted;
            // 强制重组对象键值顺序
            const { name, type, ...restProps } = p;
            return { name, type, ...restProps };
        }

        // 解析已经处理好的 parts (为了准确提取 RegionKey)
        // 注意: 我们需要从 p.processedName (Clean Name) 中提取 Region
        // 格式: Region[N]✈Suffix

        let content = p.processedName || "";
        // 移除开头的 IPv6 标签干扰 (如果存在)
        const contentWithoutIPv6 = content.replace(/^IPv6\s+/, "");

        let keyPart = contentWithoutIPv6;
        let suffixPart = "";

        // Split by FIRST Plane
        const planeIndex = contentWithoutIPv6.indexOf(Constants.SEPARATOR);
        if (planeIndex !== -1) {
            keyPart = contentWithoutIPv6.substring(0, planeIndex).trim();
            suffixPart = contentWithoutIPv6.substring(planeIndex + 1).replace(/^[\s✈]+|[\s✈]+$/g, '').trim();
        }

        // Check for IPv6 in key or suffix
        let isIPv6 = content.startsWith("IPv6");
        if (/IPv6/i.test(keyPart)) {
            isIPv6 = true;
            keyPart = keyPart.replace(/IPv6/ig, "").trim();
        }
        if (/IPv6/i.test(suffixPart)) {
            isIPv6 = true;
            suffixPart = suffixPart.replace(/IPv6/ig, "").replace(/^[\s✈]+|[\s✈]+$/g, '').trim();
        }

        // 清理 Key (移除末尾数字或括号)
        const cleanKey = keyPart.replace(/(\[\s*\d*\s*\]|\d+)$/g, '').trim();

        // 提取基准国家维度用于统一计数
        let baseRegion = cleanKey;
        if (typeof RegionMap !== 'undefined') {
            for (const region of Object.keys(RegionMap)) {
                // 如果 cleanKey 包含该基准国家名，归类到同一组计数，例如 "香港01-深港IEPL" -> "香港"
                if (cleanKey.startsWith(region)) {
                    baseRegion = region;
                    break;
                }
            }
        }

        // 计数
        if (!nameCounts[baseRegion]) nameCounts[baseRegion] = 0;
        nameCounts[baseRegion]++;
        const index = nameCounts[baseRegion];

        // 重组
        const prefix = isIPv6 ? "IPv6 " : "";
        let newName = `${prefix}${cleanKey}`;

        // Check if suffixPart is numeric
        if (suffixPart && !/^\d+$/.test(suffixPart)) {
            // deduplicate checking if suffixPart is already contained in newName
            if (!newName.includes(suffixPart)) {
                // Remove adjacent or global duplicates in suffixPart
                const uniqueSuffixParts = [...new Set(suffixPart.split(/\s*✈\s*/))].join(Constants.SEPARATOR);
                newName = `${newName}${Constants.SEPARATOR}${uniqueSuffixParts}`;
            }
        }

        // Final output string
        const extras = [];
        if (p.multiplier) extras.push(p.multiplier.trim());

        // 智能协议冗余剔除机制 (Smart Protocol Deduplication)
        // 检查整个节点名中是否已经包含了高级协议特征(Reality, XTLS, V2ray, TLS, WS)
        const fullCurrentName = p.name + newName;
        const hasRealityOrXTLS = /(Reality|XTLS|Xhttp)/i.test(fullCurrentName);
        const hasV2rayOrTLS_WS = /(V2ray|TLS|WS)/i.test(fullCurrentName);

        if (p.protocol) {
            let shouldAddProtocol = true;

            // 互斥规则 1: 如果名字里已经有 Reality 或 XTLS，就舍弃底层协议 vless
            if (hasRealityOrXTLS && p.protocol.toLowerCase() === 'vless') {
                shouldAddProtocol = false;
            }

            // 互斥规则 2: 如果名字里已经有 V2ray, TLS, 或 WS，就舍弃底层协议 vmess
            if (hasV2rayOrTLS_WS && p.protocol.toLowerCase() === 'vmess') {
                shouldAddProtocol = false;
            }

            if (shouldAddProtocol) {
                newName = `${p.flag} ${p.protocol} ✈ ${newName}`;
            } else {
                newName = `${p.flag} ${newName}`;
            }
        } else {
            newName = `${p.flag} ${newName}`;
        }

        p.name = extras.length > 0 ? `${newName} ✈ ${extras.join(' ✈ ')}` : newName;
        // 清理由于前面置空字段(如某些标签被去重移除了)导致的连续分隔符 ' ✈  ✈ '。
        // 将两个或以上的 ' ✈ ' 以及它们之间的空格压缩为一个纯净的 ' ✈ '
        p.name = p.name.replace(/(?:\s*✈\s*){2,}/g, ' ✈ ');
        // 清理由于前面置空字段(如某些标签被去重移除了)导致的连续分隔符 ' ✈  ✈ '。
        // 将两个或以上的 ' ✈ ' 以及它们之间的空格压缩为一个纯净的 ' ✈ '
        p.name = p.name.replace(/(?:\s*✈\s*){2,}/g, ' ✈ ');

        // Remove temp props
        delete p.processedName;
        delete p.flag;
        delete p.multiplier;
        delete p.protocol;

        // 强制重组对象键值顺序：保证 `name` 始终作为第一属性输出用于 JSON 排版美观
        const { name, type, ...restProps } = p;
        return {
            name,
            type,
            ...restProps
        };
    });
}
