import { ProfileBadge, UserProfileSummary } from '../models/ProfileModels';

export class ProfileSummaryMetric {
  public readonly label: string;
  public readonly value: number;

  public constructor(label: string, value: number) {
    this.label = label;
    this.value = value;
  }
}

export class ProfileSummaryPresentation {
  public readonly available: boolean;
  public readonly metrics: Array<ProfileSummaryMetric>;
  public readonly badges: Array<ProfileBadge>;

  public constructor(
    available: boolean,
    metrics: Array<ProfileSummaryMetric>,
    badges: Array<ProfileBadge>
  ) {
    this.available = available;
    this.metrics = metrics;
    this.badges = badges;
  }
}

export function profileSummaryPresentationFor(summary: UserProfileSummary): ProfileSummaryPresentation {
  if (!summary.available) {
    return new ProfileSummaryPresentation(false, [], []);
  }
  return new ProfileSummaryPresentation(
    true,
    [
      new ProfileSummaryMetric('Topic', summary.topicCount),
      new ProfileSummaryMetric('Post', summary.postCount),
      new ProfileSummaryMetric('获赞', summary.likesReceived),
      new ProfileSummaryMetric('点赞', summary.likesGiven),
      new ProfileSummaryMetric('访问', summary.daysVisited),
      new ProfileSummaryMetric('解决', summary.solvedCount)
    ],
    summary.badges.slice()
  );
}
