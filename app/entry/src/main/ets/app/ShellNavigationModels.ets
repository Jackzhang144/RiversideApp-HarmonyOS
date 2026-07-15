export enum RootDestination {
  HOME = 0,
  CATEGORY = 1,
  CHAT = 2,
  NOTIFICATIONS = 3,
  ACCOUNT = 4
}

export enum RootTabIndex {
  HOME = 0,
  CATEGORY = 1,
  CHAT = 2,
  NOTIFICATIONS = 3,
  ACCOUNT = 4
}

export enum HomeSortTabIndex {
  LATEST_REPLIES = 0,
  LATEST_CREATED = 1,
  UNREAD = 2,
  HOT = 3,
  FEATURED = 4
}

export enum SecondaryDestination {
  NONE = 'none',
  CATEGORY_TOPICS = 'category-topics',
  TOPIC = 'topic'
}

export function isHomeSortTabAvailable(index: number): boolean {
  return Number.isInteger(index) && index >= HomeSortTabIndex.LATEST_REPLIES &&
    index <= HomeSortTabIndex.FEATURED;
}

export function rootDestinationForTabIndex(index: number): RootDestination | null {
  if (index === RootTabIndex.HOME) return RootDestination.HOME;
  if (index === RootTabIndex.CATEGORY) return RootDestination.CATEGORY;
  if (index === RootTabIndex.CHAT) return RootDestination.CHAT;
  if (index === RootTabIndex.NOTIFICATIONS) return RootDestination.NOTIFICATIONS;
  if (index === RootTabIndex.ACCOUNT) return RootDestination.ACCOUNT;
  return null;
}
