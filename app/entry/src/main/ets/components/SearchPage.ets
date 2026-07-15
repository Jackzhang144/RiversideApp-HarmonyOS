import {
  SearchState,
  SearchStateKind,
  SearchSuggestionState,
  SearchSuggestionStateKind
} from '../app/AppShellModel';
import { SearchGroup, SearchPost, SearchTag, SearchUser } from '../models/DiscoveryModels';
import { Category, Topic } from '../models/ForumModels';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';

@Component
export struct SearchPage {
  @Prop state: SearchState = SearchState.initial();
  @Prop suggestionState: SearchSuggestionState = SearchSuggestionState.initial();
  @Prop knownCategories: Array<Category> = [];
  @State queryInput: string = '';
  onSearch: (query: string) => void = (_query: string): void => {};
  onLoadSuggestions: (term: string) => void = (_term: string): void => {};
  onRetry: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (_topic: Topic): void => {};
  onOpenPost: (post: SearchPost) => void = (_post: SearchPost): void => {};
  onOpenUser: (user: SearchUser) => void = (_user: SearchUser): void => {};
  onOpenCategory: (category: Category) => void = (_category: Category): void => {};
  private suggestionTimer: number = -1;

  aboutToDisappear(): void {
    if (this.suggestionTimer >= 0) {
      clearTimeout(this.suggestionTimer);
      this.suggestionTimer = -1;
    }
  }

  private scheduleSuggestions(value: string): void {
    if (this.suggestionTimer >= 0) {
      clearTimeout(this.suggestionTimer);
    }
    this.onLoadSuggestions('');
    const normalizedValue: string = value.trim();
    if (normalizedValue.length === 0) {
      this.suggestionTimer = -1;
      return;
    }
    this.suggestionTimer = setTimeout((): void => {
      this.suggestionTimer = -1;
      this.onLoadSuggestions(normalizedValue);
    }, 300);
  }

  private submit(): void {
    const query: string = this.queryInput.trim();
    if (query.length > 0) {
      this.onLoadSuggestions('');
      this.onSearch(query);
    }
  }

  private selectSuggestion(suggestion: string): void {
    this.queryInput = suggestion;
    this.onLoadSuggestions('');
    this.onSearch(suggestion);
  }

  @Builder
  private Suggestions(): void {
    if (this.suggestionState.kind === SearchSuggestionStateKind.LOADING) {
      Row({ space: 8 }) {
        LoadingProgress().width(18).height(18)
        Text('正在加载搜索建议').fontSize(12).fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 8, bottom: 10 })
    } else if (this.suggestionState.kind === SearchSuggestionStateKind.CONTENT) {
      Column() {
        ForEach(this.suggestionState.items, (suggestion: string) => {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(16)
              .fontColor([$r('sys.color.font_tertiary')])
            Text(suggestion)
              .fontSize(14)
              .fontColor('#24262B')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(42)
          .padding({ left: 14, right: 14 })
          .onClick((): void => this.selectSuggestion(suggestion))
          .accessibilityText(`搜索建议 ${suggestion}`)
        }, (suggestion: string): string => suggestion)
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#E8EBF0' })
      .borderRadius(10)
      .margin({ left: 12, right: 12, bottom: 10 })
    } else if (this.suggestionState.kind === SearchSuggestionStateKind.EMPTY) {
      Text('暂无搜索建议，仍可直接搜索当前关键词')
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .padding({ left: 14, right: 14, top: 8, bottom: 10 })
    } else if (this.suggestionState.kind === SearchSuggestionStateKind.ERROR) {
      Row({ space: 8 }) {
        Text(this.suggestionState.message)
          .fontSize(12)
          .fontColor('#C62828')
          .layoutWeight(1)
        Button('重试')
          .height(30)
          .fontSize(12)
          .onClick((): void => this.onLoadSuggestions(this.queryInput))
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 6, bottom: 10 })
    }
  }

  @Builder
  private SearchInput(): void {
    Column() {
      Row({ space: 8 }) {
        TextInput({ text: this.queryInput, placeholder: '搜索 Topic、Post、用户、Category、标签或群组' })
          .height(44)
          .layoutWeight(1)
          .backgroundColor('#F5F6F8')
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string): void => {
            this.queryInput = value;
            this.scheduleSuggestions(value);
          })
          .onSubmit((): void => this.submit())
          .accessibilityText('论坛搜索关键词')
        Button('搜索')
          .height(44)
          .enabled(this.queryInput.trim().length > 0 && this.state.kind !== SearchStateKind.LOADING)
          .onClick((): void => this.submit())
          .accessibilityText('搜索论坛')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 10 })
      this.Suggestions()
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private MessageState(title: string, message: string, retryable: boolean): void {
    Column({ space: 14 }) {
      Text(title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(message)
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      if (retryable) {
        Button('重试')
          .onClick(this.onRetry)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SectionHeader(title: string, count: number): void {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text(count.toString())
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 12, bottom: 2 })
  }

  @Builder
  private SearchPostRow(post: SearchPost): void {
    Column({ space: 7 }) {
      Row() {
        Text(post.username.length > 0 ? `${post.username} 回复了` : 'Post 命中')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
        Text(`#${post.postNumber}`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      Text(post.topic.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (post.displayText.length > 0) {
        Text(post.displayText)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .onClick((): void => this.onOpenPost(post))
    .accessibilityText(`${post.topic.title}，第 ${post.postNumber} 条 Post`)
  }

  @Builder
  private UserRow(user: SearchUser): void {
    Row({ space: 12 }) {
      Text(user.displayName.slice(0, 1).toUpperCase())
        .width(38)
        .height(38)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#317AF7')
        .textAlign(TextAlign.Center)
        .backgroundColor('#EAF2FF')
        .borderRadius(19)
      Column({ space: 2 }) {
        Text(user.displayName)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
        Text(`@${user.username}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .onClick((): void => this.onOpenUser(user))
    .accessibilityText(`用户 ${user.displayName}，${user.username}`)
  }

  @Builder
  private CategoryRow(category: Category): void {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.folder'))
        .fontSize(21)
        .fontColor(['#317AF7'])
      Text(category.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .onClick((): void => this.onOpenCategory(category))
    .accessibilityText(`Category ${category.name}`)
  }

  @Builder
  private TagRow(tag: SearchTag): void {
    Row({ space: 10 }) {
      Text('#')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#317AF7')
      Text(tag.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text(`${tag.topicCount} 个 Topic`)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .accessibilityText(`标签 ${tag.name}`)
  }

  @Builder
  private GroupRow(group: SearchGroup): void {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.person_2'))
        .fontSize(21)
        .fontColor(['#317AF7'])
      Column({ space: 2 }) {
        Text(group.fullName.length > 0 ? group.fullName : group.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
        Text(`${group.name} · ${group.userCount} 位成员`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .accessibilityText(`群组 ${group.fullName.length > 0 ? group.fullName : group.name}`)
  }

  @Builder
  private PaginationFooter(): void {
    Column({ space: 8 }) {
      if (this.state.isLoadingMore) {
        LoadingProgress()
          .width(28)
          .height(28)
        Text('正在加载更多搜索结果')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.paginationMessage.length > 0) {
        Text(this.state.paginationMessage)
          .fontSize(12)
          .fontColor('#C62828')
        Button('重试加载更多')
          .height(34)
          .onClick(this.onLoadMore)
      } else if (!this.state.hasMore) {
        Text('已经显示全部结果')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .height(82)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private Results(): void {
    List({ space: 9 }) {
      if (this.state.result.users.length > 0) {
        ListItem() { this.SectionHeader('用户', this.state.result.users.length) }
        ForEach(this.state.result.users, (user: SearchUser) => {
          ListItem() { this.UserRow(user) }
        }, (user: SearchUser): string => `user-${user.id}`)
      }
      if (this.state.result.categories.length > 0) {
        ListItem() { this.SectionHeader('Category', this.state.result.categories.length) }
        ForEach(this.state.result.categories, (category: Category) => {
          ListItem() { this.CategoryRow(category) }
        }, (category: Category): string => `category-${category.id}`)
      }
      if (this.state.result.tags.length > 0) {
        ListItem() { this.SectionHeader('标签', this.state.result.tags.length) }
        ForEach(this.state.result.tags, (tag: SearchTag) => {
          ListItem() { this.TagRow(tag) }
        }, (tag: SearchTag): string => `tag-${tag.id}`)
      }
      if (this.state.result.groups.length > 0) {
        ListItem() { this.SectionHeader('群组', this.state.result.groups.length) }
        ForEach(this.state.result.groups, (group: SearchGroup) => {
          ListItem() { this.GroupRow(group) }
        }, (group: SearchGroup): string => `group-${group.id}`)
      }
      if (this.state.result.topics.length > 0) {
        ListItem() { this.SectionHeader('Topic', this.state.result.topics.length) }
        ForEach(this.state.result.topics, (topic: Topic) => {
          ListItem() {
            ForumContentCard({
              presentation: ForumCardPresentation.topicPreview(topic, this.knownCategories),
              onOpenTopic: (): void => this.onOpenTopic(topic)
            })
          }
        }, (topic: Topic): string => `topic-${topic.id}`)
      }
      if (this.state.result.posts.length > 0) {
        ListItem() { this.SectionHeader('Post', this.state.result.posts.length) }
        ForEach(this.state.result.posts, (post: SearchPost) => {
          ListItem() { this.SearchPostRow(post) }
        }, (post: SearchPost): string => `post-${post.id}`)
      }
      ListItem() { this.PaginationFooter() }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 12, right: 12, bottom: 18 })
    .backgroundColor('#F5F6F8')
    .edgeEffect(EdgeEffect.Spring)
    .onReachEnd(this.onLoadMore)
  }

  build() {
    Column() {
      this.SearchInput()
      if (this.state.kind === SearchStateKind.INITIAL) {
        this.MessageState('搜索 RiverSide', '输入关键词查找 Topic、Post、用户、Category、标签和群组。', false)
      } else if (this.state.kind === SearchStateKind.LOADING) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(38)
            .height(38)
          Text(`正在搜索“${this.state.query}”`)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.state.kind === SearchStateKind.ERROR) {
        this.MessageState('搜索失败', this.state.message, true)
      } else if (this.state.kind === SearchStateKind.EMPTY) {
        this.MessageState('没有找到相关内容', `没有与“${this.state.query}”匹配的结果。`, false)
      } else {
        this.Results()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
