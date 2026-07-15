export enum ForumPlainTextContext {
  PROFILE = 'profile',
  CHAT = 'chat',
  POST = 'post',
  DISCOVERY = 'discovery',
  NOTIFICATION = 'notification'
}

function withoutUnsafeBlocks(value: string): string {
  return value
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '');
}

function decodeForumEntities(value: string): string {
  return value
    .replace(/&nbsp;/gi, ' ')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&amp;/gi, '&');
}

function profileText(value: string): string {
  return decodeForumEntities(withoutUnsafeBlocks(value)
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ''))
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function chatText(value: string): string {
  return decodeForumEntities(withoutUnsafeBlocks(value)
    .replace(/<img[^>]*alt=["']([^"']*)["'][^>]*>/gi, ' $1 ')
    .replace(/<img[^>]*title=["']([^"']*)["'][^>]*>/gi, ' $1 ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|li)>/gi, '\n')
    .replace(/<[^>]+>/g, ''))
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function postText(value: string): string {
  return decodeForumEntities(withoutUnsafeBlocks(value)
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<li[^>]*>/gi, '• ')
    .replace(/<\/(p|div|h[1-6]|li|blockquote)>/gi, '\n')
    .replace(/<[^>]+>/g, ''))
    .replace(/\n[ \t]+/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function notificationText(value: string): string {
  return decodeForumEntities(withoutUnsafeBlocks(value)
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ' '))
    .replace(/[ \t]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export function forumPlainText(value: string, context: ForumPlainTextContext): string {
  if (context === ForumPlainTextContext.CHAT) {
    return chatText(value);
  }
  if (context === ForumPlainTextContext.POST) {
    return postText(value);
  }
  if (context === ForumPlainTextContext.DISCOVERY) {
    return profileText(value).replace(/\s+/g, ' ').trim();
  }
  if (context === ForumPlainTextContext.NOTIFICATION) {
    return notificationText(value);
  }
  return profileText(value);
}

export function forumPostPlainText(raw: string, cooked: string): string {
  const normalizedCooked: string = cooked.trim();
  return normalizedCooked.length === 0
    ? raw.trim()
    : forumPlainText(normalizedCooked, ForumPlainTextContext.POST);
}
