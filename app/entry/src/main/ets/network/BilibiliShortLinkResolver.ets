import { rcp } from '@kit.RemoteCommunicationKit';
import { AppMetadata } from '../core/AppMetadata';
import { RepositoryResult } from '../core/RepositoryResult';
import {
  bilibiliPlayerUrl,
  isBilibiliShortLink
} from '../models/RichContentParser';

const SHORT_LINK_CONNECT_TIMEOUT_MS: number = 8000;
const SHORT_LINK_TRANSFER_TIMEOUT_MS: number = 8000;

export interface BilibiliRedirectReader {
  readLocation(shortUrl: string): Promise<RepositoryResult<string>>;
}

export class RcpBilibiliRedirectReader implements BilibiliRedirectReader {
  public async readLocation(shortUrl: string): Promise<RepositoryResult<string>> {
    const request: rcp.Request = new rcp.Request(shortUrl, 'HEAD');
    request.headers = {
      'User-Agent': AppMetadata.current().userAgent(),
      'Accept': 'text/html'
    };
    request.configuration = {
      transfer: {
        autoRedirect: false,
        timeout: {
          connectMs: SHORT_LINK_CONNECT_TIMEOUT_MS,
          transferMs: SHORT_LINK_TRANSFER_TIMEOUT_MS
        }
      }
    };
    try {
      const response: rcp.Response = await rcp.getDefaultSession().fetch(request);
      if (response.statusCode < 300 || response.statusCode >= 400) {
        return RepositoryResult.invalidResponse<string>(
          `Bilibili 短链返回了 ${response.statusCode}`
        );
      }
      const location: string = response.headers.location ?? '';
      return location.length > 0
        ? RepositoryResult.success<string>(location)
        : RepositoryResult.invalidResponse<string>('Bilibili 短链缺少跳转地址');
    } catch (_) {
      return RepositoryResult.network<string>('Bilibili 短链解析失败');
    }
  }
}

export class BilibiliShortLinkResolver {
  private readonly redirectReader: BilibiliRedirectReader;

  public constructor(redirectReader: BilibiliRedirectReader) {
    this.redirectReader = redirectReader;
  }

  public async resolve(shortUrl: string): Promise<RepositoryResult<string>> {
    if (!isBilibiliShortLink(shortUrl)) {
      return RepositoryResult.invalidInput<string>('不是受支持的 Bilibili 短链');
    }
    const redirect: RepositoryResult<string> = await this.redirectReader.readLocation(shortUrl);
    if (!redirect.isSuccess() || redirect.data === null) {
      return redirect.asFailure<string>();
    }
    const playerUrl: string = bilibiliPlayerUrl(redirect.data);
    return playerUrl.length > 0
      ? RepositoryResult.success<string>(playerUrl)
      : RepositoryResult.security<string>('Bilibili 短链跳转目标不受信任');
  }
}
