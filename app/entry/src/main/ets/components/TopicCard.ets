import { Category, Topic } from '../models/ForumModels';

const EMPTY_TOPIC: Topic = new Topic(0, '', 0, 0, 0, 0, '', '', false, '');

@Component
export struct TopicCard {
  @Prop topic: Topic = EMPTY_TOPIC;
  @Prop categories: Array<Category> = [];
  onOpen: (topic: Topic) => void = (_topic: Topic): void => {};

  private authorName(): string {
    return this.topic.username.length > 0 ? this.topic.username : '匿名';
  }

  private authorInitial(): string {
    const author: string = this.authorName();
    return author === '匿名' ? '匿' : author.slice(0, 1).toUpperCase();
  }

  private updatedAt(): string {
    const timestamp: string = this.topic.lastPostedAt.trim();
    if (timestamp.length >= 16 && timestamp.includes('T')) {
      return timestamp.slice(0, 16).replace('T', ' ');
    }
    return timestamp.length > 0 ? timestamp : '时间未知';
  }

  private categoryName(): string {
    for (const category of this.categories) {
      if (category.id === this.topic.categoryId) {
        return category.name;
      }
    }
    return this.topic.categoryId > 0 ? `Category #${this.topic.categoryId}` : 'Category';
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text(this.authorInitial())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#317AF7')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#EAF2FF')
          .borderRadius(18)
        Column({ space: 2 }) {
          Text(this.authorName())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
          Text(this.updatedAt())
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.topic.pinned) {
          Text('置顶')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#C62828')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#FDECEC')
            .borderRadius(10)
        }
      }
      Text(this.topic.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.topic.excerpt.length > 0) {
        Text(this.topic.excerpt)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      Row({ space: 5 }) {
        Text(this.categoryName())
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2068C9')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#EAF2FF')
          .borderRadius(10)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(14)
          .fontColor([$r('sys.color.font_tertiary')])
        Text(Math.max(this.topic.postCount - 1, 0).toString())
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
        SymbolGlyph($r('sys.symbol.eye'))
          .fontSize(14)
          .fontColor([$r('sys.color.font_tertiary')])
          .margin({ left: 6 })
        Text(this.topic.viewCount.toString())
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .onClick((): void => {
      this.onOpen(this.topic);
    })
    .accessibilityText(
      `${this.topic.title}，作者 ${this.authorName()}，${this.categoryName()}，` +
      `${Math.max(this.topic.postCount - 1, 0)} 条 Reply，${this.topic.viewCount} 浏览`
    )
  }
}
