import { AuthenticationLifecycle } from '../app/AppShellModel';
import { ProfileSessionLifecycle } from '../app/ProfileManagementModel';
import { AuthRepository, AuthStateKind } from './AuthRepository';

export class RepositoryAuthenticationLifecycle implements AuthenticationLifecycle, ProfileSessionLifecycle {
  private readonly repository: AuthRepository;
  private readonly onChanged: () => void;
  private activeTask: Promise<void> | null = null;

  public constructor(repository: AuthRepository, onChanged: () => void) {
    this.repository = repository;
    this.onChanged = onChanged;
  }

  public handleUnauthorized(): Promise<void> {
    const task: Promise<void> | null = this.activeTask;
    if (task !== null) {
      return task;
    }
    if (this.repository.state.kind === AuthStateKind.IDLE) {
      return this.completedTask();
    }
    const unauthorizedTask: Promise<void> = this.performUnauthorized();
    this.activeTask = unauthorizedTask;
    return unauthorizedTask;
  }

  private async performUnauthorized(): Promise<void> {
    try {
      await this.repository.logout();
      this.onChanged();
    } finally {
      this.activeTask = null;
    }
  }

  private async completedTask(): Promise<void> {
  }
}
