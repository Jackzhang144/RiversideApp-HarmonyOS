export interface AuthenticationLifecycle {
  handleUnauthorized(): Promise<void>;
}
