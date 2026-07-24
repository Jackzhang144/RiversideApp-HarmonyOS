export class StartupRequestTasks {
  private readonly homeLoader: () => Promise<void>;
  private readonly categoryLoader: () => Promise<void>;
  private readonly presenceStarter: () => void;
  private readonly onlineUsersLoader: () => void;

  public constructor(
    homeLoader: () => Promise<void>,
    categoryLoader: () => Promise<void>,
    presenceStarter: () => void,
    onlineUsersLoader: () => void
  ) {
    this.homeLoader = homeLoader;
    this.categoryLoader = categoryLoader;
    this.presenceStarter = presenceStarter;
    this.onlineUsersLoader = onlineUsersLoader;
  }

  public loadHome(): Promise<void> {
    return this.homeLoader();
  }

  public loadCategories(): Promise<void> {
    return this.categoryLoader();
  }

  public startPresence(): void {
    this.presenceStarter();
  }

  public loadOnlineUsers(): void {
    this.onlineUsersLoader();
  }
}

export async function runStartupRequestSequence(tasks: StartupRequestTasks): Promise<void> {
  const homeTask: Promise<void> = tasks.loadHome();
  const categoryTask: Promise<void> = tasks.loadCategories();
  await Promise.all([homeTask, categoryTask]);
  tasks.startPresence();
  tasks.loadOnlineUsers();
}
