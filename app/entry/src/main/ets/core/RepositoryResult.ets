export enum RepositoryResultKind {
  SUCCESS = 'success',
  UNAUTHORIZED = 'unauthorized',
  FAILURE = 'failure'
}

export class RepositoryResult<T> {
  public readonly kind: RepositoryResultKind;
  public readonly data: T | null;
  public readonly message: string;

  private constructor(kind: RepositoryResultKind, data: T | null, message: string) {
    this.kind = kind;
    this.data = data;
    this.message = message;
  }

  public static success<T>(data: T): RepositoryResult<T> {
    return new RepositoryResult<T>(RepositoryResultKind.SUCCESS, data, '');
  }

  public static failure<T>(message: string): RepositoryResult<T> {
    return new RepositoryResult<T>(RepositoryResultKind.FAILURE, null, message);
  }

  public static unauthorized<T>(): RepositoryResult<T> {
    return new RepositoryResult<T>(RepositoryResultKind.UNAUTHORIZED, null, '登录已失效');
  }

  public isSuccess(): boolean {
    return this.kind === RepositoryResultKind.SUCCESS && this.data !== null;
  }

  public isUnauthorized(): boolean {
    return this.kind === RepositoryResultKind.UNAUTHORIZED;
  }
}
