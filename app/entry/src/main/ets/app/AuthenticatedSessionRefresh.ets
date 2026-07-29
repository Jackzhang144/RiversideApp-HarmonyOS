export class AuthenticatedSessionRefreshTasks {
  private readonly accountRefresher: () => Promise<void>;
  private readonly homeRefresher: () => Promise<void>;
  private readonly categoryRefresher: () => Promise<void>;
  private readonly notificationRefresher: () => Promise<void>;
  private readonly chatRefresher: () => Promise<void>;

  public constructor(
    accountRefresher: () => Promise<void>,
    homeRefresher: () => Promise<void>,
    categoryRefresher: () => Promise<void>,
    notificationRefresher: () => Promise<void>,
    chatRefresher: () => Promise<void>
  ) {
    this.accountRefresher = accountRefresher;
    this.homeRefresher = homeRefresher;
    this.categoryRefresher = categoryRefresher;
    this.notificationRefresher = notificationRefresher;
    this.chatRefresher = chatRefresher;
  }

  public refreshAccount(): Promise<void> {
    return this.accountRefresher();
  }

  public refreshHome(): Promise<void> {
    return this.homeRefresher();
  }

  public refreshCategories(): Promise<void> {
    return this.categoryRefresher();
  }

  public refreshNotifications(): Promise<void> {
    return this.notificationRefresher();
  }

  public refreshChat(): Promise<void> {
    return this.chatRefresher();
  }
}

export async function runAuthenticatedSessionRefresh(
  tasks: AuthenticatedSessionRefreshTasks
): Promise<void> {
  await tasks.refreshAccount();
  const homeTask: Promise<void> = tasks.refreshHome();
  const categoryTask: Promise<void> = tasks.refreshCategories();
  const notificationTask: Promise<void> = tasks.refreshNotifications();
  const chatTask: Promise<void> = tasks.refreshChat();
  await Promise.all([homeTask, categoryTask, notificationTask, chatTask]);
}
