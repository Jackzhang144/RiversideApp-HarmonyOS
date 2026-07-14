import { ServerDraft } from '../models/AuthoringModels';
import { Topic } from '../models/ForumModels';
import { UserBookmarkItem, UserReplyItem } from '../models/ProfileModels';
import { ProfileContentKind } from '../app/ProfileContentModel';

@Component
export struct ProfileContentPage {
  @Prop kind: ProfileContentKind = ProfileContentKind.TOPICS;
  @Prop loading: boolean = false;
  @Prop loadingMore: boolean = false;
  @Prop hasMore: boolean = false;
  @Prop message: string = '';
  @Prop topics: Array<Topic> = [];
  @Prop replies: Array<UserReplyItem> = [];
  @Prop drafts: Array<ServerDraft> = [];
  @Prop bookmarks: Array<UserBookmarkItem> = [];
  onRetry: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (): void => {};
  onOpenReply: (reply: UserReplyItem) => void = (): void => {};
  onOpenDraft: (draft: ServerDraft) => void = (): void => {};
  onOpenBookmark: (bookmark: UserBookmarkItem) => void = (): void => {};
  onLoadMore: () => void = (): void => {};

  private empty(): boolean {
    if (this.kind === ProfileContentKind.TOPICS) {
      return this.topics.length === 0;
    }
    if (this.kind === ProfileContentKind.REPLIES) {
      return this.replies.length === 0;
    }
    if (this.kind === ProfileContentKind.DRAFTS) {
      return this.drafts.length === 0;
    }
    return this.bookmarks.length === 0;
  }

  @Builder
  private RowCard(title: string, detail: string, onClick: () => void): void {
    Column({ space: 6 }) {
      Text(title.length > 0 ? title : '未命名内容')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      if (detail.length > 0) {
        Text(detail).fontSize(13).fontColor('#52606D').maxLines(3).width('100%')
      }
    }
    .width('100%')
    .padding(15)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(onClick)
  }

  @Builder
  private PaginationFooter(): void {
    Column({ space: 8 }) {
      if (this.loadingMore) {
        LoadingProgress().width(28).height(28)
        Text('正在加载更多').fontSize(12).fontColor('#52606D')
      } else if (this.message.length > 0) {
        Text(this.message).fontSize(12).fontColor('#C62828').textAlign(TextAlign.Center)
        Button('重试加载更多').height(34).onClick(this.onLoadMore)
      } else if (!this.hasMore && this.kind !== ProfileContentKind.DRAFTS) {
        Text('已经显示全部内容').fontSize(12).fontColor('#7B8794')
      }
    }
    .width('100%')
    .height(82)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    if (this.loading) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text('正在加载').fontSize(14).fontColor('#52606D')
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.message.length > 0 && this.empty()) {
      Column({ space: 12 }) {
        Text(this.message).fontSize(14).fontColor('#C62828').textAlign(TextAlign.Center)
        Button('重试').onClick(this.onRetry)
      }
      .width('100%').height('100%').padding(28).justifyContent(FlexAlign.Center)
    } else if (this.empty()) {
      Column() { Text('暂无内容').fontSize(15).fontColor('#52606D') }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        if (this.kind === ProfileContentKind.TOPICS) {
          ForEach(this.topics, (topic: Topic): void => {
            ListItem() { this.RowCard(topic.title, topic.excerpt, (): void => this.onOpenTopic(topic)) }
          }, (topic: Topic): string => topic.id.toString())
        } else if (this.kind === ProfileContentKind.REPLIES) {
          ForEach(this.replies, (reply: UserReplyItem): void => {
            ListItem() { this.RowCard(reply.topicTitle, reply.excerpt, (): void => this.onOpenReply(reply)) }
          }, (reply: UserReplyItem): string => reply.actionId.toString())
        } else if (this.kind === ProfileContentKind.DRAFTS) {
          ForEach(this.drafts, (draft: ServerDraft): void => {
            ListItem() { this.RowCard(draft.title, draft.raw, (): void => this.onOpenDraft(draft)) }
          }, (draft: ServerDraft): string => `${draft.draftKey}-${draft.sequence}`)
        } else {
          ForEach(this.bookmarks, (bookmark: UserBookmarkItem): void => {
            ListItem() { this.RowCard(bookmark.title, bookmark.excerpt,
              (): void => this.onOpenBookmark(bookmark)) }
          }, (bookmark: UserBookmarkItem): string => bookmark.bookmarkId.toString())
        }
        ListItem() { this.PaginationFooter() }
      }
      .width('100%').height('100%').padding(12).backgroundColor('#F5F6F8')
      .onReachEnd(this.onLoadMore)
    }
  }
}
