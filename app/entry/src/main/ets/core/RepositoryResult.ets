export enum RepositoryResultKind {
  SUCCESS = 'success',
  UNAUTHORIZED = 'unauthorized',
  FAILURE = 'failure'
}

export enum RepositoryFailureCode {
  UNAUTHORIZED = 'unauthorized',
  INVALID_INPUT = 'invalid-input',
  NETWORK = 'network',
  SERVER = 'server',
  INVALID_RESPONSE = 'invalid-response',
  STORAGE = 'storage',
  SECURITY = 'security',
  CANCELLED = 'cancelled',
  UNAVAILABLE = 'unavailable',
  UNKNOWN = 'unknown'
}

export class RepositoryResult<T> {
  public readonly kind: RepositoryResultKind;
  public readonly data: T | null;
  public readonly failureCode: RepositoryFailureCode | null;
  public readonly message: string;

  private constructor(
    kind: RepositoryResultKind,
    data: T | null,
    failureCode: RepositoryFailureCode | null,
    message: string
  ) {
    this.kind = kind;
    this.data = data;
    this.failureCode = failureCode;
    this.message = message;
  }

  public static success<T>(data: T): RepositoryResult<T> {
    return new RepositoryResult<T>(RepositoryResultKind.SUCCESS, data, null, '');
  }

  public static invalidInput<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.INVALID_INPUT, message);
  }

  public static network<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.NETWORK, message);
  }

  public static server<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.SERVER, message);
  }

  public static invalidResponse<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.INVALID_RESPONSE, message);
  }

  public static storage<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.STORAGE, message);
  }

  public static security<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.SECURITY, message);
  }

  public static cancelled<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.CANCELLED, message);
  }

  public static unavailable<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.UNAVAILABLE, message);
  }

  public static unknown<T>(message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(RepositoryFailureCode.UNKNOWN, message);
  }

  public static withFailure<T>(code: RepositoryFailureCode, message: string): RepositoryResult<T> {
    return RepositoryResult.failed<T>(code, message);
  }

  public static unauthorized<T>(): RepositoryResult<T> {
    return new RepositoryResult<T>(
      RepositoryResultKind.UNAUTHORIZED,
      null,
      RepositoryFailureCode.UNAUTHORIZED,
      '登录已失效'
    );
  }

  public isSuccess(): boolean {
    return this.kind === RepositoryResultKind.SUCCESS && this.data !== null;
  }

  public isUnauthorized(): boolean {
    return this.kind === RepositoryResultKind.UNAUTHORIZED;
  }

  public asFailure<U>(): RepositoryResult<U> {
    if (this.isUnauthorized()) {
      return RepositoryResult.unauthorized<U>();
    }
    return RepositoryResult.withFailure<U>(
      this.failureCode ?? RepositoryFailureCode.UNKNOWN,
      this.message
    );
  }

  private static failed<T>(code: RepositoryFailureCode, message: string): RepositoryResult<T> {
    return new RepositoryResult<T>(RepositoryResultKind.FAILURE, null, code, message);
  }
}
