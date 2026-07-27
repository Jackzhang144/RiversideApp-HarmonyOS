import {
  SearchState,
  SearchStateKind,
  SearchSuggestionState,
  SearchSuggestionStateKind
} from '../app/BrowseModels';
import { RIVERSIDE_URL_RESOLVER } from '../core/RiversideEnvironment';
import { ChatEmoji } from '../models/ChatModels';
import { SearchGroup, SearchPost, SearchTag, SearchUser } from '../models/DiscoveryModels';
import { Category, Topic } from '../models/ForumModels';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';
import { UserAvatar } from './UserAvatar';

@Component
export struct SearchPage {
  scroller: Scroller = new Scroller();
  @Prop state: SearchState = SearchState.initial();
  @Prop suggestionState: SearchSuggestionState = SearchSuggestionState.initial();
  @Prop knownCategories: Array<Category> = [];
  @Prop emojis: Array<ChatEmoji> = [];
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
      this.getUIContext().getFocusController().clearFocus();
      this.onLoadSuggestions('');
      this.onSearch(query);
    }
  }

  private selectSuggestion(suggestion: string): void {
    this.queryInput = suggestion;
    this.getUIContext().getFocusController().clearFocus();
    this.onLoadSuggestions('');
    this.onSearch(suggestion);
  }

  private clearQuery(): void {
    this.queryInput = '';
    this.onLoadSuggestions('');
    if (this.suggestionTimer >= 0) {
      clearTimeout(this.suggestionTimer);
      this.suggestionTimer = -1;
    }
  }

  @Builder
  private Suggestions(): void {
    if (this.suggestionState.kind === SearchSuggestionStateKind.LOADING) {
      Row({ space: 8 }) {
        LoadingProgress().width(18).height(18)
        Text($r('app.string.search_suggestion_loading')).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(42)
      .padding({ left: 4, right: 4 })
    } else if (this.suggestionState.kind === SearchSuggestionStateKind.CONTENT) {
      Column() {
        Divider().color($r('sys.color.comp_divider'))
        ForEach(this.suggestionState.items, (suggestion: string) => {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(16)
              .fontColor([$r('app.color.brand_primary')])
            Text(suggestion)
              .fontSize(14)
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.arrow_right'))
              .fontSize(14)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width('100%')
          .height(44)
          .padding({ left: 4, right: 4 })
          .onClick((): void => this.selectSuggestion(suggestion))
          .accessibilityText(`搜索建议 ${suggestion}`)
        }, (suggestion: string): string => suggestion)
      }
      .width('100%')
    } else if (this.suggestionState.kind === SearchSuggestionStateKind.EMPTY) {
      Column() {
        Divider().color($r('sys.color.comp_divider'))
        Text($r('app.string.search_suggestion_empty'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .height(42)
          .padding({ left: 4, right: 4 })
      }
      .width('100%')
    } else if (this.suggestionState.kind === SearchSuggestionStateKind.ERROR) {
      Column() {
        Divider().color($r('sys.color.comp_divider'))
        Row({ space: 8 }) {
          Text(this.suggestionState.message)
            .fontSize(12)
            .fontColor($r('app.color.status_error'))
            .layoutWeight(1)
          Button($r('app.string.common_retry'))
            .height(30)
            .fontSize(12)
            .backgroundColor($r('app.color.brand_tint_surface'))
            .fontColor($r('app.color.brand_primary'))
            .onClick((): void => this.onLoadSuggestions(this.queryInput))
        }
        .width('100%')
        .height(44)
      }
      .width('100%')
    }
  }

  @Builder
  private SearchInput(): void {
    Column({ space: 0 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(20)
          .fontColor([$r('app.color.brand_primary')])
        TextInput({ text: this.queryInput, placeholder: $r('app.string.search_placeholder') })
          .height(46)
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string): void => {
            this.queryInput = value;
            this.scheduleSuggestions(value);
          })
          .onSubmit((): void => this.submit())
          .accessibilityText($r('app.string.search_keyword_accessibility'))
        if (this.queryInput.length > 0) {
          Button() {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(18)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width(34)
          .height(34)
          .backgroundColor(Color.Transparent)
          .onClick((): void => this.clearQuery())
          .accessibilityText('清除搜索内容')
        }
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor([Color.White])
        }
          .width(40)
          .height(40)
          .borderRadius(14)
          .backgroundColor($r('app.color.brand_primary'))
          .enabled(this.queryInput.trim().length > 0 && this.state.kind !== SearchStateKind.LOADING)
          .onClick((): void => this.submit())
          .accessibilityText($r('app.string.search_action_accessibility'))
      }
      .width('100%')
      .padding({ left: 12, right: 7 })
      this.Suggestions()
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(20)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .shadow({
      radius: 14,
      color: $r('sys.color.comp_divider'),
      offsetX: 0,
      offsetY: 5
    })
    .margin({ left: 12, right: 12, top: 12, bottom: 10 })
  }

  @Builder
  private MessageState(
    icon: Resource,
    title: ResourceStr,
    message: ResourceStr,
    retryable: boolean
  ): void {
    Column({ space: 12 }) {
      Stack() {
        SymbolGlyph(icon)
          .fontSize(34)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(68)
      .height(68)
      .borderRadius(22)
      .backgroundColor($r('app.color.brand_tint_surface'))
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(message)
        .fontSize(13)
        .lineHeight(19)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      if (retryable) {
        Button($r('app.string.common_retry'))
          .height(40)
          .borderRadius(14)
          .onClick(this.onRetry)
      }
    }
    .width('calc(100% - 24vp)')
    .padding({ left: 28, right: 28, top: 34, bottom: 34 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(22)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .margin({ left: 12, right: 12, top: 12 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SectionHeader(title: ResourceStr, count: number): void {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text(count.toString())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_primary'))
        .height(26)
        .padding({ left: 9, right: 9 })
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(13)
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 14, bottom: 4 })
  }

  @Builder
  private SearchPostRow(post: SearchPost): void {
    Row({ space: 11 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(20)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(42)
      .height(42)
      .borderRadius(13)
      .backgroundColor($r('app.color.brand_tint_surface'))
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
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .onClick((): void => this.onOpenPost(post))
    .accessibilityText(`${post.topic.title}，第 ${post.postNumber} 条 Post`)
  }

  @Builder
  private UserRow(user: SearchUser): void {
    Row({ space: 12 }) {
      UserAvatar({
        avatarUrl: RIVERSIDE_URL_RESOLVER.avatar(user.avatarTemplate, 96),
        displayName: user.displayName,
        avatarSize: 38,
        avatarAccessibilityText: `${user.displayName} 的头像`,
        flairUrl: user.flairUrl,
        flairName: user.flairName,
        flairBackgroundColor: user.flairBackgroundColor,
        flairColor: user.flairColor
      })
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
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .onClick((): void => this.onOpenUser(user))
    .accessibilityText(`用户 ${user.displayName}，${user.username}`)
  }

  @Builder
  private CategoryRow(category: Category): void {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.folder'))
        .fontSize(21)
        .fontColor([$r('app.color.brand_primary')])
      Text(category.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding($r('app.float.card_content_padding'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .onClick((): void => this.onOpenCategory(category))
    .accessibilityText(`Category ${category.name}`)
  }

  @Builder
  private TagRow(tag: SearchTag): void {
    Row({ space: 10 }) {
      Text('#')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
      Text(tag.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Text(`${tag.topicCount} 个 Topic`)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding($r('app.float.card_content_padding'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .accessibilityText(`标签 ${tag.name}`)
  }

  @Builder
  private GroupRow(group: SearchGroup): void {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.person_2'))
        .fontSize(21)
        .fontColor([$r('app.color.brand_primary')])
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
    .padding($r('app.float.card_content_padding'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .accessibilityText(`群组 ${group.fullName.length > 0 ? group.fullName : group.name}`)
  }

  @Builder
  private PaginationFooter(): void {
    Column({ space: 8 }) {
      if (this.state.isLoadingMore) {
        LoadingProgress()
          .width(28)
          .height(28)
        Text($r('app.string.search_loading_more'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.paginationMessage.length > 0) {
        Text(this.state.paginationMessage)
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
        Button($r('app.string.common_retry_load_more'))
          .height(34)
          .onClick(this.onLoadMore)
      } else if (!this.state.hasMore) {
        Text($r('app.string.search_all_results_shown'))
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
    List({ space: 9, scroller: this.scroller }) {
      if (this.state.result.users.length > 0) {
        ListItem() { this.SectionHeader($r('app.string.search_section_user'), this.state.result.users.length) }
        ForEach(this.state.result.users, (user: SearchUser) => {
          ListItem() { this.UserRow(user) }
        }, (user: SearchUser): string => `user-${user.id}`)
      }
      if (this.state.result.categories.length > 0) {
        ListItem() { this.SectionHeader($r('app.string.search_section_category'), this.state.result.categories.length) }
        ForEach(this.state.result.categories, (category: Category) => {
          ListItem() { this.CategoryRow(category) }
        }, (category: Category): string => `category-${category.id}`)
      }
      if (this.state.result.tags.length > 0) {
        ListItem() { this.SectionHeader($r('app.string.search_section_tag'), this.state.result.tags.length) }
        ForEach(this.state.result.tags, (tag: SearchTag) => {
          ListItem() { this.TagRow(tag) }
        }, (tag: SearchTag): string => `tag-${tag.id}`)
      }
      if (this.state.result.groups.length > 0) {
        ListItem() { this.SectionHeader($r('app.string.search_section_group'), this.state.result.groups.length) }
        ForEach(this.state.result.groups, (group: SearchGroup) => {
          ListItem() { this.GroupRow(group) }
        }, (group: SearchGroup): string => `group-${group.id}`)
      }
      if (this.state.result.topics.length > 0) {
        ListItem() { this.SectionHeader($r('app.string.search_section_topic'), this.state.result.topics.length) }
        ForEach(this.state.result.topics, (topic: Topic) => {
          ListItem() {
            ForumContentCard({
              presentation: ForumCardPresentation.topicPreview(topic, this.knownCategories, null, this.emojis),
              onOpenTopic: (): void => this.onOpenTopic(topic)
            })
          }
        }, (topic: Topic): string => `topic-${topic.id}-emoji-${this.emojis.length}`)
      }
      if (this.state.result.posts.length > 0) {
        ListItem() { this.SectionHeader($r('app.string.search_section_post'), this.state.result.posts.length) }
        ForEach(this.state.result.posts, (post: SearchPost) => {
          ListItem() { this.SearchPostRow(post) }
        }, (post: SearchPost): string => `post-${post.id}`)
      }
      ListItem() { this.PaginationFooter() }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 12, right: 12, bottom: 18 })
    .clip(false)
    .cachedCount(3, true)
    .backgroundColor($r('sys.color.background_secondary'))
    .edgeEffect(EdgeEffect.Spring)
    .onScrollStart((): void => {
      this.getUIContext().getFocusController().clearFocus();
    })
    .onReachEnd(this.onLoadMore)
  }

  build() {
    Column() {
      this.SearchInput()
      if (this.state.kind === SearchStateKind.INITIAL) {
        this.MessageState(
          $r('sys.symbol.magnifyingglass'),
          $r('app.string.search_initial_title'),
          $r('app.string.search_initial_message'),
          false
        )
      } else if (this.state.kind === SearchStateKind.LOADING) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(38)
            .height(38)
          Text(`正在搜索“${this.state.query}”`)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('calc(100% - 24vp)')
        .height(180)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(22)
        .border({ width: 1, color: $r('sys.color.comp_divider') })
        .margin({ left: 12, right: 12, top: 12 })
        .justifyContent(FlexAlign.Center)
      } else if (this.state.kind === SearchStateKind.ERROR) {
        this.MessageState(
          $r('sys.symbol.magnifyingglass'),
          $r('app.string.search_failed'),
          this.state.message,
          true
        )
      } else if (this.state.kind === SearchStateKind.EMPTY) {
        this.MessageState(
          $r('sys.symbol.magnifyingglass'),
          $r('app.string.search_empty_title'),
          `没有与“${this.state.query}”匹配的结果。`,
          false
        )
      } else {
        this.Results()
      }
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
