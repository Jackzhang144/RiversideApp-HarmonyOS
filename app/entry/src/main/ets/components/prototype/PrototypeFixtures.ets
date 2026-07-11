export class PrototypeTopic {
  public readonly id: number;
  public readonly title: string;
  public readonly excerpt: string;
  public readonly author: string;
  public readonly category: string;
  public readonly replies: number;
  public readonly views: string;
  public readonly updatedAt: string;
  public readonly pinned: boolean;

  public constructor(
    id: number,
    title: string,
    excerpt: string,
    author: string,
    category: string,
    replies: number,
    views: string,
    updatedAt: string,
    pinned: boolean = false
  ) {
    this.id = id;
    this.title = title;
    this.excerpt = excerpt;
    this.author = author;
    this.category = category;
    this.replies = replies;
    this.views = views;
    this.updatedAt = updatedAt;
    this.pinned = pinned;
  }
}

export class PrototypeCategory {
  public readonly id: number;
  public readonly name: string;
  public readonly description: string;
  public readonly topicCount: string;
  public readonly accent: string;

  public constructor(
    id: number,
    name: string,
    description: string,
    topicCount: string,
    accent: string
  ) {
    this.id = id;
    this.name = name;
    this.description = description;
    this.topicCount = topicCount;
    this.accent = accent;
  }
}

export class PrototypeReply {
  public readonly id: number;
  public readonly author: string;
  public readonly level: string;
  public readonly publishedAt: string;
  public readonly content: string;
  public readonly likes: number;

  public constructor(
    id: number,
    author: string,
    level: string,
    publishedAt: string,
    content: string,
    likes: number
  ) {
    this.id = id;
    this.author = author;
    this.level = level;
    this.publishedAt = publishedAt;
    this.content = content;
    this.likes = likes;
  }
}

export const PROTOTYPE_TOPICS: Array<PrototypeTopic> = [
  new PrototypeTopic(
    1,
    '图书馆座位预约系统使用体验优化建议',
    '最近使用预约系统时遇到了一些不太方便的地方，整理了几点建议。',
    '李同学',
    '校内事务',
    23,
    '1.2k',
    '刚刚',
    true
  ),
  new PrototypeTopic(
    2,
    '求推荐性价比高的平板电脑',
    '主要用来做笔记和看网课，预算 2000–3000，有推荐的吗？',
    '数码爱好者',
    '问答',
    18,
    '856',
    '5 分钟前'
  ),
  new PrototypeTopic(
    3,
    '广州大学城环线骑行路线分享',
    '整理了一条适合周末骑行的路线，风景很棒，附上轨迹图。',
    '骑行小新',
    '生活',
    12,
    '623',
    '35 分钟前'
  ),
  new PrototypeTopic(
    4,
    '高数期末复习资料整理（持续更新）',
    '整理了近五年真题和重点题型，欢迎补充。',
    '菲利普',
    '学习',
    40,
    '2.3k',
    '2 小时前'
  )
];

export const PROTOTYPE_CATEGORIES: Array<PrototypeCategory> = [
  new PrototypeCategory(1, '教务通知', '教务处通知与公告', '586', '#317AF7'),
  new PrototypeCategory(2, '校园活动', '讲座、社团与校园活动', '812', '#5F6FFF'),
  new PrototypeCategory(3, '专业课程', '课程讨论与资料分享', '1.2k', '#20A77A'),
  new PrototypeCategory(4, '考研保研', '备考经验与升学信息', '923', '#00A6A6'),
  new PrototypeCategory(5, '美食天地', '食堂与周边美食', '682', '#F59C2B'),
  new PrototypeCategory(6, '住宿讨论', '宿舍生活与租房交流', '431', '#EE6B55')
];

export const PROTOTYPE_REPLIES: Array<PrototypeReply> = [
  new PrototypeReply(
    1,
    '图书馆小助手',
    'LV.3 · 管理员',
    '昨天 15:02',
    '感谢同学提出的宝贵建议！我们会认真评估，并持续优化系统体验。',
    12
  ),
  new PrototypeReply(
    2,
    '学部小明',
    'LV.5',
    '昨天 15:18',
    '我也遇到过同样的问题，特别是晚上八点左右很难抢到位置。',
    8
  )
];
